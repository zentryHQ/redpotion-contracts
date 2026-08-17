// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./libraries/TransferHelper.sol";
import "./interfaces/IDepositQueue.sol";
import "./interfaces/IFund.sol";
import "./modules/FundSpokeACLModule.sol";

contract DepositQueue is
    IDepositQueue,
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

    /// @notice Aggregate deposit amount per asset per batch.
    mapping(address asset => mapping(uint256 batchId => uint256))
        public batchDepositTotals;

    /// @notice Total user shares per asset per batch (set at settle time).
    mapping(address asset => mapping(uint256 batchId => uint256))
        public batchShareTotals;

    /// @notice Per-asset per-batch per-user deposit request.
    mapping(address asset => mapping(uint256 batchId => mapping(address user => DepositRequest)))
        private _depositRequests;

    /// @notice Tracks (asset, batchId) pairs each user has deposited into.
    /// Encoded as bytes32: address (20 bytes) | uint96 batchId (12 bytes).
    mapping(address user => EnumerableSet.Bytes32Set) private _userDeposits;

    /// @notice Per-asset pause state.
    mapping(address asset => bool) public isAssetPaused;

    /// @notice Whether a batch has been settled for a given asset.
    mapping(address asset => mapping(uint256 batchId => bool)) private _batchSettled;

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

        emit DepositQueueCreated(fund_, allowedAssets_);
    }

    /// @inheritdoc IDepositQueue
    function setAllowedAssets(
        address[] calldata assets_
    ) external onlyRole(SET_DEPOSIT_ALLOWED_ASSETS_ROLE) {
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
            if (!stillAllowed && _hasUnsettledDeposits(oldAsset, currentBatchId)) {
                revert AssetHasPendingRequests();
            }
        }
        _setAllowedAssets(assets_);
    }

    /// @dev `currentBatchId` is virtual: after the cutoff it already points at
    /// the next batch while the closed batch may still await settlement.
    /// Check the previous batch too — removing an asset with deposits in a
    /// closed-but-unsettled batch would exclude it from settlement forever,
    /// stranding the depositors. Settled batches keep nonzero totals (claim
    /// denominators), so they must not block removal.
    function _hasUnsettledDeposits(
        address asset,
        uint256 currentBatchId
    ) internal view returns (bool) {
        if (batchDepositTotals[asset][currentBatchId] > 0) return true;
        return
            currentBatchId > 0 &&
            batchDepositTotals[asset][currentBatchId - 1] > 0 &&
            !_isBatchSettled(asset, currentBatchId - 1);
    }

    function pause() external onlyRole(PAUSE_DEPOSIT_ROLE) {
        _pause();
        emit DepositQueuePaused();
    }

    function unpause() external onlyRole(UNPAUSE_DEPOSIT_ROLE) {
        _unpause();
        emit DepositQueueUnpaused();
    }

    function pauseAssets(address[] calldata assets) external onlyRole(PAUSE_DEPOSIT_ROLE) {
        for (uint256 i = 0; i < assets.length; i++) {
            isAssetPaused[assets[i]] = true;
            emit AssetPaused(assets[i]);
        }
    }

    function unpauseAssets(address[] calldata assets) external onlyRole(UNPAUSE_DEPOSIT_ROLE) {
        for (uint256 i = 0; i < assets.length; i++) {
            isAssetPaused[assets[i]] = false;
            emit AssetUnpaused(assets[i]);
        }
    }

    /// @inheritdoc IDepositQueue
    function deposit(address asset, uint256 amount, bytes32[] calldata proof) external payable nonReentrant whenNotPaused {
        if (!_isAllowedAsset(asset)) revert UnsupportedAsset();
        if (isAssetPaused[asset]) revert AssetIsPaused();
        if (amount == 0) revert ZeroAmount();

        if (TransferHelper.isETH(asset)) {
            if (msg.value != amount) revert InvalidETHAmount();
        } else {
            if (msg.value != 0) revert InvalidETHAmount();
        }

        uint256 batchId = IFund(fund).getCurrentBatchId();

        IFund(fund).checkDeposit(_msgSender(), asset, batchId, amount, proof);
        TransferHelper.transferFrom(asset, _msgSender(), address(this), amount);

        // Repeat submissions in the same batch accumulate into one request:
        // everything in a batch settles at the same price, so per-submission
        // records would add bookkeeping without changing anyone's outcome.
        DepositRequest storage request = _depositRequests[asset][batchId][_msgSender()];
        request.amount += amount;
        request.timestamp = uint48(block.timestamp);
        batchDepositTotals[asset][batchId] += amount;
        _userDeposits[_msgSender()].add(_encodeAssetBatch(asset, batchId));

        emit DepositSubmitted(_msgSender(), asset, batchId, amount, request.amount);
    }



    /// @inheritdoc IDepositQueue
    function cancelDeposit(address asset) external nonReentrant whenNotPaused {
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
        _cancelDeposit(asset, batchId, _msgSender());
    }

    /// @inheritdoc IDepositQueue
    function setCancelLockWindow(uint256 window) external onlyRole(SET_CANCEL_LOCK_WINDOW_ROLE) {
        cancelLockWindow = window;
        emit CancelLockWindowUpdated(window);
    }

    /// @inheritdoc IDepositQueue
    /// @dev Deliberately not pause-gated: the hatch must work when the
    /// operator is absent or hostile. Racing a late settlement stays
    /// consistent — acceptance advances the settling batch (closing the
    /// window) and `_cancelDeposit` shrinks the totals settlement reads.
    function forceCancelDeposit(address asset) external nonReentrant {
        (uint256 batchId, uint48 cutoffTime) = IFund(fund).getSettlingBatch();
        if (cutoffTime == 0 || block.timestamp < uint256(cutoffTime) + FORCE_CANCEL_DELAY)
            revert ForceCancelNotOpen();
        if (_isBatchSettled(asset, batchId)) revert AlreadySettled();
        _cancelDeposit(asset, batchId, _msgSender());
    }

    /// @inheritdoc IDepositQueue
    function adminCancelDeposit(address asset, uint256 batchId, address user)
        external
        onlyRole(CANCEL_DEPOSIT_REQUEST_ROLE)
        nonReentrant
    {
        if (_isBatchSettled(asset, batchId)) revert AlreadySettled();
        _cancelDeposit(asset, batchId, user);
    }

    function _cancelDeposit(address asset, uint256 batchId, address user) internal {
        DepositRequest storage req = _depositRequests[asset][batchId][user];
        if (req.amount == 0) revert NoRequest();

        uint256 refund = req.amount;
        delete _depositRequests[asset][batchId][user];
        _userDeposits[user].remove(_encodeAssetBatch(asset, batchId));

        batchDepositTotals[asset][batchId] -= refund;

        TransferHelper.transfer(asset, user, refund);

        emit DepositCancelled(user, asset, batchId, refund);
    }

    /// @inheritdoc IDepositQueue
    function claimDeposit(
        address asset,
        uint256 batchId
    ) external nonReentrant whenNotPaused {
        DepositRequest storage req = _depositRequests[asset][batchId][
            _msgSender()
        ];
        if (req.amount == 0) revert NothingToClaim();
        if (!_isBatchSettled(asset, batchId)) revert BatchNotSettled();

        uint256 depositAmount = req.amount;
        uint256 totalDeposits = batchDepositTotals[asset][batchId];
        uint256 totalShares = batchShareTotals[asset][batchId];
        delete _depositRequests[asset][batchId][_msgSender()];
        _userDeposits[_msgSender()].remove(_encodeAssetBatch(asset, batchId));

        uint256 userShares = (depositAmount * totalShares) / totalDeposits;

        address shareToken = IFund(fund).share();
        IERC20(shareToken).safeTransfer(_msgSender(), userShares);

        emit DepositClaimed(_msgSender(), asset, batchId, userShares);
    }

    /// @inheritdoc IDepositQueue
    function settleDeposit(
        address asset,
        uint256 batchId,
        uint256 sharesToMint
    ) external onlyFund {
        if (_isBatchSettled(asset, batchId)) revert AlreadySettled();
        uint256 totalDeposits = batchDepositTotals[asset][batchId];

        if (totalDeposits > 0) {
            TransferHelper.transfer(asset, fund, totalDeposits);
        }

        batchShareTotals[asset][batchId] = sharesToMint;
        _batchSettled[asset][batchId] = true;

        emit DepositSettled(asset, batchId, totalDeposits, sharesToMint);
    }

    /// @inheritdoc IDepositQueue
    function pullAsset(address asset, uint256 amount) external onlyRole(PULL_DEPOSIT_ASSET_ROLE) {
        TransferHelper.transfer(asset, fund, amount);
        emit AssetPulled(asset, amount);
    }


    function _isBatchSettled(address asset, uint256 batchId) internal view returns (bool) {
        return _batchSettled[asset][batchId];
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
        emit DepositAllowedAssetsUpdated(assets_);
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

    /// @inheritdoc IDepositQueue
    function getAllowedAssets() external view returns (address[] memory) {
        return _allowedAssets;
    }

    /// @inheritdoc IDepositQueue
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

    /// @inheritdoc IDepositQueue
    function getDepositRequest(
        address asset,
        uint256 batchId,
        address investor
    ) external view returns (DepositRequest memory) {
        return _depositRequests[asset][batchId][investor];
    }

    /// @inheritdoc IDepositQueue
    function getPendingDeposits(
        address investor
    ) external view returns (DepositRequestInfo[] memory) {
        uint256 currentBatchId = IFund(fund).getCurrentBatchId();
        uint256 assetCount = _allowedAssets.length;

        uint256 count;
        for (uint256 i = 0; i < assetCount; i++) {
            if (_depositRequests[_allowedAssets[i]][currentBatchId][investor].amount > 0) {
                count++;
            }
        }

        DepositRequestInfo[] memory result = new DepositRequestInfo[](count);
        uint256 idx;
        for (uint256 i = 0; i < assetCount; i++) {
            address asset = _allowedAssets[i];
            DepositRequest storage req = _depositRequests[asset][currentBatchId][investor];
            if (req.amount > 0) {
                result[idx++] = DepositRequestInfo({
                    asset: asset,
                    batchId: currentBatchId,
                    amount: req.amount,
                    timestamp: req.timestamp
                });
            }
        }
        return result;
    }

    /// @inheritdoc IDepositQueue
    function getClaimableDeposits(
        address investor
    ) external view returns (DepositRequestInfo[] memory) {
        EnumerableSet.Bytes32Set storage deposits = _userDeposits[investor];
        uint256 len = deposits.length();
        uint256 currentBatchId = IFund(fund).getCurrentBatchId();

        uint256 count;
        for (uint256 i = 0; i < len; i++) {
            (address asset, uint256 batchId) = _decodeAssetBatch(deposits.at(i));
            if (batchId < currentBatchId && _isBatchSettled(asset, batchId)) {
                count++;
            }
        }

        DepositRequestInfo[] memory result = new DepositRequestInfo[](count);
        uint256 idx;
        for (uint256 i = 0; i < len; i++) {
            (address asset, uint256 batchId) = _decodeAssetBatch(deposits.at(i));
            if (batchId < currentBatchId && _isBatchSettled(asset, batchId)) {
                DepositRequest storage req = _depositRequests[asset][batchId][investor];
                result[idx++] = DepositRequestInfo({
                    asset: asset,
                    batchId: batchId,
                    amount: req.amount,
                    timestamp: req.timestamp
                });
            }
        }
        return result;
    }
}
