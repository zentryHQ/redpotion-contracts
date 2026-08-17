// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./libraries/TransferHelper.sol";
import "./interfaces/IRedeemQueue.sol";
import "./interfaces/IFund.sol";
import "./modules/FundSpokeACLModule.sol";

contract RedeemQueue is
    IRedeemQueue,
    ContextUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    FundSpokeACLModule
{
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /// @notice How long past its cutoff a batch may sit unsettled before
    /// requesters can force-cancel out of it. Matches the oracle's hard cap
    /// on the report-acceptance window, so a normally progressing settlement
    /// is never preempted.
    uint256 public constant FORCE_CANCEL_DELAY = 30 days;

    address public fund;

    function _fund() internal view override returns (address) {
        return fund;
    }

    address[] private _allowedAssets;

    /// @notice Aggregate redeem shares per asset per batch.
    mapping(address asset => mapping(uint256 batchId => uint256))
        public batchRedeemTotals;

    /// @notice Total asset payout per asset per batch (set when funded).
    mapping(address asset => mapping(uint256 batchId => uint256))
        public batchAssetTotals;

    /// @notice Whether a batch has been funded (assets received from Fund).
    mapping(address asset => mapping(uint256 batchId => bool))
        public isBatchFunded;

    /// @notice Per-asset per-batch per-user redeem request.
    mapping(address asset => mapping(uint256 batchId => mapping(address user => RedeemRequest)))
        private _redeemRequests;

    /// @notice Tracks (asset, batchId) pairs each user has redeemed into.
    /// Encoded as bytes32: address (20 bytes) | uint96 batchId (12 bytes).
    mapping(address user => EnumerableSet.Bytes32Set) private _userRedeems;

    /// @notice Tracks settled but unfunded (asset, batchId) pairs.
    EnumerableSet.Bytes32Set private _unfundedBatches;

    /// @notice Per-asset pause state.
    mapping(address asset => bool) public isAssetPaused;

    /// @notice How long before a batch's cutoff public cancellation is frozen.
    /// Prevents reserving batch cap then cancelling for a free refund in the
    /// final blocks. Zero disables the lock.
    uint256 public cancelLockWindow;

    modifier onlyFund() {
        if (_msgSender() != fund) revert OnlyFund();
        _;
    }

    constructor() {
        _disableInitializers();
    }

    receive() external payable {}

    function initialize(
        address fund_,
        address[] calldata allowedAssets_
    ) external initializer {
        __Context_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        _setFund(fund_);
        _setAllowedAssets(allowedAssets_);

        emit RedeemQueueCreated(fund_, allowedAssets_);
    }

    /// @inheritdoc IRedeemQueue
    function setAllowedAssets(
        address[] calldata assets_
    ) external onlyRole(SET_REDEEM_ALLOWED_ASSETS_ROLE) {
        uint256 currentBatchId = IFund(fund).getCurrentBatchId();
        for (uint256 i = 0; i < _allowedAssets.length; i++) {
            address oldAsset = _allowedAssets[i];
            bool stillAllowed = false;
            for (uint256 j = 0; j < assets_.length; j++) {
                if (oldAsset == assets_[j]) {
                    stillAllowed = true;
                    break;
                }
            }
            if (!stillAllowed && _hasUnsettledRedeems(oldAsset, currentBatchId)) {
                revert AssetHasPendingRequests();
            }
        }
        _setAllowedAssets(assets_);
    }

    /// @dev `currentBatchId` is virtual: after the cutoff it already points at
    /// the next batch while the closed batch may still await settlement.
    /// Check the previous batch too — removing an asset with redeems in a
    /// closed-but-unsettled batch would exclude it from settlement forever,
    /// stranding the escrowed shares. Settled batches keep nonzero totals
    /// (claim denominators), so they must not block removal.
    function _hasUnsettledRedeems(
        address asset,
        uint256 currentBatchId
    ) internal view returns (bool) {
        if (batchRedeemTotals[asset][currentBatchId] > 0) return true;
        return
            currentBatchId > 0 &&
            batchRedeemTotals[asset][currentBatchId - 1] > 0 &&
            !_isBatchSettled(asset, currentBatchId - 1);
    }

    function pause() external onlyRole(PAUSE_REDEEM_ROLE) {
        _pause();
        emit RedeemQueuePaused();
    }

    function unpause() external onlyRole(UNPAUSE_REDEEM_ROLE) {
        _unpause();
        emit RedeemQueueUnpaused();
    }

    function pauseAssets(address[] calldata assets) external onlyRole(PAUSE_REDEEM_ROLE) {
        for (uint256 i = 0; i < assets.length; i++) {
            isAssetPaused[assets[i]] = true;
            emit AssetPaused(assets[i]);
        }
    }

    function unpauseAssets(address[] calldata assets) external onlyRole(UNPAUSE_REDEEM_ROLE) {
        for (uint256 i = 0; i < assets.length; i++) {
            isAssetPaused[assets[i]] = false;
            emit AssetUnpaused(assets[i]);
        }
    }

    /// @inheritdoc IRedeemQueue
    function redeem(address asset, uint256 shares) external nonReentrant whenNotPaused {
        if (!_isAllowedAsset(asset)) revert UnsupportedAsset();
        if (isAssetPaused[asset]) revert AssetIsPaused();
        if (shares == 0) revert ZeroAmount();

        uint256 batchId = IFund(fund).getCurrentBatchId();

        address shareToken = IFund(fund).share();
        IERC20(shareToken).safeTransferFrom(
            _msgSender(),
            address(this),
            shares
        );

        IFund(fund).checkRedeem(batchId, shares);

        // Repeat submissions in the same batch accumulate into one request:
        // everything in a batch settles at the same price, so per-submission
        // records would add bookkeeping without changing anyone's outcome.
        RedeemRequest storage request = _redeemRequests[asset][batchId][_msgSender()];
        request.shares += shares;
        request.timestamp = uint48(block.timestamp);
        batchRedeemTotals[asset][batchId] += shares;
        _userRedeems[_msgSender()].add(_encodeAssetBatch(asset, batchId));

        emit RedeemSubmitted(_msgSender(), asset, batchId, shares, request.shares);
    }



    /// @inheritdoc IRedeemQueue
    function cancelRedeem(address asset) external nonReentrant whenNotPaused {
        uint256 batchId = IFund(fund).getCurrentBatchId();
        (uint256 settlingBatchId, uint48 cutoffTime) = IFund(fund).getSettlingBatch();
        // The lock only bites while the batch being cancelled is the open batch
        // this cutoff governs. Past the cutoff `getCurrentBatchId` advances
        // ahead of the settling batch, so the now-passed cutoff no longer
        // applies to it.
        if (
            batchId == settlingBatchId &&
            cutoffTime != 0 &&
            block.timestamp + cancelLockWindow >= uint256(cutoffTime)
        ) revert CancelLocked();
        _cancelRedeem(asset, batchId, _msgSender());
    }

    /// @inheritdoc IRedeemQueue
    function setCancelLockWindow(uint256 window) external onlyRole(SET_CANCEL_LOCK_WINDOW_ROLE) {
        cancelLockWindow = window;
        emit CancelLockWindowUpdated(window);
    }

    /// @inheritdoc IRedeemQueue
    /// @dev Deliberately not pause-gated: the hatch must work when the
    /// operator is absent or hostile. Racing a late settlement stays
    /// consistent — acceptance advances the settling batch (closing the
    /// window) and `_cancelRedeem` shrinks the totals settlement reads.
    function forceCancelRedeem(address asset) external nonReentrant {
        (uint256 batchId, uint48 cutoffTime) = IFund(fund).getSettlingBatch();
        if (cutoffTime == 0 || block.timestamp < uint256(cutoffTime) + FORCE_CANCEL_DELAY)
            revert ForceCancelNotOpen();
        if (_isBatchSettled(asset, batchId)) revert AlreadySettled();
        _cancelRedeem(asset, batchId, _msgSender());
    }

    /// @inheritdoc IRedeemQueue
    function adminCancelRedeem(address asset, uint256 batchId, address user)
        external
        onlyRole(CANCEL_REDEEM_REQUEST_ROLE)
        nonReentrant
    {
        if (_isBatchSettled(asset, batchId)) revert AlreadySettled();
        _cancelRedeem(asset, batchId, user);
    }

    function _cancelRedeem(address asset, uint256 batchId, address user) internal {
        RedeemRequest storage req = _redeemRequests[asset][batchId][user];
        if (req.shares == 0) revert NoRequest();

        uint256 refundShares = req.shares;
        delete _redeemRequests[asset][batchId][user];
        _userRedeems[user].remove(_encodeAssetBatch(asset, batchId));

        batchRedeemTotals[asset][batchId] -= refundShares;

        address shareToken = IFund(fund).share();
        IERC20(shareToken).safeTransfer(user, refundShares);

        emit RedeemCancelled(user, asset, batchId, refundShares);
    }

    /// @inheritdoc IRedeemQueue
    function claimRedeem(
        address asset,
        uint256 batchId
    ) external nonReentrant whenNotPaused {
        RedeemRequest storage req = _redeemRequests[asset][batchId][
            _msgSender()
        ];
        if (req.shares == 0) revert NothingToClaim();
        if (!isBatchFunded[asset][batchId]) revert BatchNotFunded();

        uint256 redeemShares = req.shares;
        uint256 totalRedeems = batchRedeemTotals[asset][batchId];
        uint256 totalAssets = batchAssetTotals[asset][batchId];
        delete _redeemRequests[asset][batchId][_msgSender()];
        _userRedeems[_msgSender()].remove(_encodeAssetBatch(asset, batchId));

        uint256 userAssets = (redeemShares * totalAssets) / totalRedeems;

        TransferHelper.transfer(asset, _msgSender(), userAssets);

        emit RedeemClaimed(_msgSender(), asset, batchId, userAssets);
    }

    /// @inheritdoc IRedeemQueue
    function settleRedeem(
        address asset,
        uint256 batchId,
        uint256 assetAmount
    ) external onlyFund {
        if (_isBatchSettled(asset, batchId)) revert AlreadySettled();

        uint256 totalShares = batchRedeemTotals[asset][batchId];

        // Transfer shares to Fund for burning and snapshot the asset payout
        // total at the accepted price. fundRedeem will use this snapshot,
        // decoupling payout sizing from any later admin fee/price changes.
        if (totalShares > 0) {
            address shareToken = IFund(fund).share();
            IERC20(shareToken).safeTransfer(fund, totalShares);
            batchAssetTotals[asset][batchId] = assetAmount;
            _unfundedBatches.add(_encodeAssetBatch(asset, batchId));
        }

        emit RedeemSettled(asset, batchId, totalShares, assetAmount);
    }

    /// @inheritdoc IRedeemQueue
    function fundRedeem(
        address asset,
        uint256 batchId
    ) external onlyFund {
        if (isBatchFunded[asset][batchId]) revert AlreadyFunded();
        bytes32 key = _encodeAssetBatch(asset, batchId);
        if (!_unfundedBatches.contains(key)) revert NotSettled();

        // Assets already transferred by Fund before this call
        isBatchFunded[asset][batchId] = true;
        _unfundedBatches.remove(key);

        emit RedeemFunded(asset, batchId, batchAssetTotals[asset][batchId]);
    }

    /// @inheritdoc IRedeemQueue
    function pullAsset(address asset, uint256 amount) external onlyRole(PULL_REDEEM_ASSET_ROLE) {
        TransferHelper.transfer(asset, fund, amount);
        emit AssetPulled(asset, amount);
    }


    function _isBatchSettled(address asset, uint256 batchId) internal view returns (bool) {
        return isBatchFunded[asset][batchId] ||
            _unfundedBatches.contains(_encodeAssetBatch(asset, batchId));
    }

    function _setFund(address fund_) internal {
        if (fund_ == address(0)) revert ZeroAddress();
        if (fund != address(0)) revert FundExist();
        fund = fund_;
        emit FundUpdated(fund_);
    }

    function _setAllowedAssets(address[] calldata assets_) internal {
        delete _allowedAssets;
        for (uint256 i = 0; i < assets_.length; i++) {
            if (assets_[i] == address(0)) revert ZeroAddress();
            for (uint256 j = 0; j < i; j++) {
                if (assets_[j] == assets_[i]) revert DuplicateAsset();
            }
            _allowedAssets.push(assets_[i]);
        }
        emit RedeemAllowedAssetsUpdated(assets_);
    }

    function _isAllowedAsset(address asset) internal view returns (bool) {
        for (uint256 i = 0; i < _allowedAssets.length; i++) {
            if (_allowedAssets[i] == asset) return true;
        }
        return false;
    }

    function _encodeAssetBatch(address asset, uint256 batchId) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(asset)) << 96 | uint96(batchId));
    }

    function _decodeAssetBatch(bytes32 encoded) internal pure returns (address asset, uint256 batchId) {
        asset = address(uint160(uint256(encoded) >> 96));
        batchId = uint256(uint96(uint256(encoded)));
    }

    /// @inheritdoc IRedeemQueue
    function getAllowedAssets() external view returns (address[] memory) {
        return _allowedAssets;
    }

    /// @inheritdoc IRedeemQueue
    function getAssetStatuses() external view returns (AssetStatus[] memory) {
        uint256 len = _allowedAssets.length;
        AssetStatus[] memory statuses = new AssetStatus[](len);
        for (uint256 i = 0; i < len; i++) {
            statuses[i] = AssetStatus({
                asset: _allowedAssets[i],
                paused: isAssetPaused[_allowedAssets[i]]
            });
        }
        return statuses;
    }

    /// @inheritdoc IRedeemQueue
    function getRedeemRequest(
        address asset,
        uint256 batchId,
        address investor
    ) external view returns (RedeemRequest memory) {
        return _redeemRequests[asset][batchId][investor];
    }

    /// @inheritdoc IRedeemQueue
    function getPendingRedeems(
        address investor
    ) external view returns (RedeemRequestInfo[] memory) {
        uint256 currentBatchId = IFund(fund).getCurrentBatchId();
        uint256 assetCount = _allowedAssets.length;

        uint256 count;
        for (uint256 i = 0; i < assetCount; i++) {
            if (_redeemRequests[_allowedAssets[i]][currentBatchId][investor].shares > 0) {
                count++;
            }
        }

        RedeemRequestInfo[] memory result = new RedeemRequestInfo[](count);
        uint256 idx;
        for (uint256 i = 0; i < assetCount; i++) {
            address asset = _allowedAssets[i];
            RedeemRequest storage req = _redeemRequests[asset][currentBatchId][investor];
            if (req.shares > 0) {
                result[idx++] = RedeemRequestInfo({
                    asset: asset,
                    batchId: currentBatchId,
                    shares: req.shares,
                    timestamp: req.timestamp
                });
            }
        }
        return result;
    }

    /// @inheritdoc IRedeemQueue
    function getClaimableRedeems(
        address investor
    ) external view returns (RedeemRequestInfo[] memory) {
        EnumerableSet.Bytes32Set storage redeems = _userRedeems[investor];
        uint256 len = redeems.length();
        uint256 currentBatchId = IFund(fund).getCurrentBatchId();

        uint256 count;
        for (uint256 i = 0; i < len; i++) {
            (address asset, uint256 batchId) = _decodeAssetBatch(redeems.at(i));
            if (batchId < currentBatchId && isBatchFunded[asset][batchId]) {
                count++;
            }
        }

        RedeemRequestInfo[] memory result = new RedeemRequestInfo[](count);
        uint256 idx;
        for (uint256 i = 0; i < len; i++) {
            (address asset, uint256 batchId) = _decodeAssetBatch(redeems.at(i));
            if (batchId < currentBatchId && isBatchFunded[asset][batchId]) {
                RedeemRequest storage req = _redeemRequests[asset][batchId][investor];
                result[idx++] = RedeemRequestInfo({
                    asset: asset,
                    batchId: batchId,
                    shares: req.shares,
                    timestamp: req.timestamp
                });
            }
        }
        return result;
    }

    /// @inheritdoc IRedeemQueue
    function getUnfundedBatches()
        external
        view
        returns (UnfundedBatch[] memory)
    {
        uint256 len = _unfundedBatches.length();
        UnfundedBatch[] memory result = new UnfundedBatch[](len);
        for (uint256 i = 0; i < len; i++) {
            (address asset, uint256 batchId) = _decodeAssetBatch(
                _unfundedBatches.at(i)
            );
            result[i] = UnfundedBatch({asset: asset, batchId: batchId});
        }
        return result;
    }
}
