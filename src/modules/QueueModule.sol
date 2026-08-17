// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./ModuleBase.sol";
import "../interfaces/IQueueModule.sol";
import "../interfaces/IFundShare.sol";
import "../interfaces/IDepositQueue.sol";
import "../interfaces/IRedeemQueue.sol";

/// @dev Stores the share + queue addresses and provides settlement internals
/// Fund uses during `_settleAll`. Admin proxies (pause, setAllowedAssets,
/// pullAsset, adminCancel) were removed — admins call the queue spokes
/// directly, which auth via role callback to Fund's access control.
abstract contract QueueModule is IQueueModule, ModuleBase {
    /// @custom:storage-location erc7201:neobank.storage.QueueModule
    struct QueueStorage {
        address share;
        address depositQueue;
        address redeemQueue;
    }

    function _queueStorage() private pure returns (QueueStorage storage $) {
        bytes32 slot = _erc7201Slot("erc7201:neobank.storage.QueueModule");
        assembly {
            $.slot := slot
        }
    }

    function __QueueModule_init(
        address share_,
        address depositQueue_,
        address redeemQueue_
    ) internal onlyInitializing {
        _setShare(share_);
        _setDepositQueue(depositQueue_);
        _setRedeemQueue(redeemQueue_);
    }

    /// @inheritdoc IQueueModule
    function share() public view returns (address) {
        return _queueStorage().share;
    }

    /// @inheritdoc IQueueModule
    function depositQueue() public view returns (address) {
        return _queueStorage().depositQueue;
    }

    /// @inheritdoc IQueueModule
    function redeemQueue() public view returns (address) {
        return _queueStorage().redeemQueue;
    }

    /// @dev Mints user shares to the deposit queue, mints fee shares to
    /// `feeRecipient_`, and tells the queue to settle the batch. Caller is
    /// responsible for fee math (passes `entryFeeBps`) and the share token.
    function _settleDeposits(
        address asset,
        uint256 batchId,
        uint256 price,
        address shareToken,
        address feeRecipient_,
        uint256 entryFeeBps
    ) internal {
        address dq = _queueStorage().depositQueue;
        uint256 depositTotal = IDepositQueue(dq).batchDepositTotals(asset, batchId);
        if (depositTotal == 0) return;

        (uint256 userShares, uint256 feeShares) = _calcDepositShares(depositTotal, price, entryFeeBps);

        IFundShare(shareToken).mint(dq, userShares);
        if (feeShares > 0) {
            IFundShare(shareToken).mint(feeRecipient_, feeShares);
        }
        IDepositQueue(dq).settleDeposit(asset, batchId, userShares);

        emit DepositSettled(asset, batchId, userShares, feeShares);
    }

    /// @dev Tells the redeem queue to settle the batch (snapshotting the asset
    /// payout total at the accepted price + exit fee), burns the redeem total
    /// from this contract's share balance, and mints exit fee shares to
    /// `feeRecipient_`. Caller passes `price` and `exitFeeBps` and the share
    /// token.
    function _settleRedeems(
        address asset,
        uint256 batchId,
        uint256 price,
        address shareToken,
        address feeRecipient_,
        uint256 exitFeeBps
    ) internal {
        address rq = _queueStorage().redeemQueue;
        uint256 redeemTotal = IRedeemQueue(rq).batchRedeemTotals(asset, batchId);
        if (redeemTotal == 0) return;

        (, uint256 feeShares) = _calcRedeemShares(redeemTotal, exitFeeBps);
        uint256 assetAmount = _calcRedeemAssetAmount(redeemTotal, price, exitFeeBps);

        IRedeemQueue(rq).settleRedeem(asset, batchId, assetAmount);
        IFundShare(shareToken).burn(address(this), redeemTotal);

        if (feeShares > 0) {
            IFundShare(shareToken).mint(feeRecipient_, feeShares);
        }

        emit RedeemSettled(asset, batchId, redeemTotal, feeShares);
    }

    function _calcDepositShares(
        uint256 depositAmount,
        uint256 price,
        uint256 entryFeeBps
    ) internal pure returns (uint256 userShares, uint256 feeShares) {
        uint256 totalShares = (depositAmount * 1e18) / price;
        feeShares = (totalShares * entryFeeBps) / 10000;
        userShares = totalShares - feeShares;
    }

    function _calcRedeemShares(
        uint256 redeemShares,
        uint256 exitFeeBps
    ) internal pure returns (uint256 netShares, uint256 feeShares) {
        feeShares = (redeemShares * exitFeeBps) / 10000;
        netShares = redeemShares - feeShares;
    }

    function _calcRedeemAssetAmount(
        uint256 redeemShares,
        uint256 price,
        uint256 exitFeeBps
    ) internal pure returns (uint256 assetAmount) {
        (uint256 netShares, ) = _calcRedeemShares(redeemShares, exitFeeBps);
        assetAmount = (netShares * price) / 1e18;
    }

    function _setShare(address share_) internal {
        if (share_ == address(0)) revert ZeroAddress();
        _queueStorage().share = share_;
        emit ShareUpdated(share_);
    }

    function _setDepositQueue(address depositQueue_) internal {
        if (depositQueue_ == address(0)) revert ZeroAddress();
        _queueStorage().depositQueue = depositQueue_;
    }

    function _setRedeemQueue(address redeemQueue_) internal {
        if (redeemQueue_ == address(0)) revert ZeroAddress();
        _queueStorage().redeemQueue = redeemQueue_;
    }
}
