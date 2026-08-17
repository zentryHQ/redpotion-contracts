// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./interfaces/IFund.sol";
import "./interfaces/IFundShare.sol";
import "./interfaces/IFundManager.sol";
import "./interfaces/IDepositQueue.sol";
import "./interfaces/IRedeemQueue.sol";
import "./interfaces/IReportModule.sol";
import "./interfaces/IOracle.sol";
import "./interfaces/IFeeManager.sol";
import "./interfaces/IRiskManager.sol";
import "./libraries/AssetSet.sol";
import "./libraries/TransferHelper.sol";
import "./modules/FeeManagerModule.sol";
import "./modules/QueueModule.sol";
import "./modules/ExternalWalletModule.sol";
import "./modules/RiskManagerModule.sol";
import "./modules/OracleModule.sol";
import "./modules/StrategyModule.sol";

contract Fund is
    IFund,
    ContextUpgradeable,
    FeeManagerModule,
    QueueModule,
    ExternalWalletModule,
    RiskManagerModule,
    OracleModule,
    StrategyModule
{
    constructor() {
        _disableInitializers();
    }

    receive() external payable {}

    function initialize(
        address share_,
        address depositQueue_,
        address redeemQueue_,
        address oracle_,
        address feeManager_,
        address riskManager_,
        address fundManager_,
        address admin_,
        FundACLModule.RoleHolder[] memory roleHolders_
    ) external initializer {
        if (admin_ == address(0)) revert ZeroAddress();
        if (oracle_ == address(0)) revert ZeroAddress();
        if (feeManager_ == address(0)) revert ZeroAddress();
        if (riskManager_ == address(0)) revert ZeroAddress();
        if (fundManager_ == address(0)) revert ZeroAddress();

        __Context_init();
        __ReentrancyGuard_init();
        __FundACLModule_init(admin_, roleHolders_);
        __FeeManagerModule_init(feeManager_);
        __QueueModule_init(share_, depositQueue_, redeemQueue_);
        __ExternalWalletModule_init();
        __RiskManagerModule_init(riskManager_);
        __OracleModule_init(oracle_);
        __StrategyModule_init(fundManager_);
    }

    /// @inheritdoc IFund
    function protocolFeeRecipient() external view returns (address) {
        return IFundManager(fundManager()).protocolFeeRecipient();
    }

    /// @inheritdoc IFund
    function getRiskContext(
        address asset,
        uint256 batchId
    ) external view returns (IRiskManager.RiskContext memory ctx) {
        IOracle o = IOracle(oracle());
        IFeeManager fm = IFeeManager(feeManager());

        address baseAsset = fm.feeBaseAsset();
        ctx.basePrice = o.lastAcceptedPrice(baseAsset);
        ctx.assetPrice = o.lastAcceptedPrice(asset);
        ctx.highWaterMark = fm.highWaterMark();
        // Quote the fees a request submitted now would actually settle at —
        // the config effective for the batch currently open for requests.
        IFeeManager.FeeConfig memory quotedFeeConfig = fm.getFeeConfigForBatch(o.getCurrentBatchId());
        ctx.entryFeeBps = quotedFeeConfig.entryFeeBps;
        ctx.exitFeeBps = quotedFeeConfig.exitFeeBps;
        ctx.shareSupply = IFundShare(share()).totalSupply();

        address dq = depositQueue();
        address[] memory depositAssets = IDepositQueue(dq).getAllowedAssets();
        for (uint256 i = 0; i < depositAssets.length; i++) {
            uint256 assetTotal = IDepositQueue(dq).batchDepositTotals(depositAssets[i], batchId);
            if (assetTotal == 0) continue;
            uint256 assetPrice = o.lastAcceptedPrice(depositAssets[i]);
            if (assetPrice == 0) continue;
            // Single full-precision division — must round the same way as the
            // per-deposit value in RiskManager.checkDeposit.
            ctx.batchDepositTotalInBase += Math.mulDiv(assetTotal, ctx.basePrice, assetPrice);
        }

        address rq = redeemQueue();
        address[] memory redeemAssets = IRedeemQueue(rq).getAllowedAssets();
        for (uint256 i = 0; i < redeemAssets.length; i++) {
            uint256 shares_ = IRedeemQueue(rq).batchRedeemTotals(redeemAssets[i], batchId);
            if (shares_ == 0) continue;
            ctx.batchRedeemTotalInBase += (shares_ * ctx.basePrice) / 1e18;
        }
    }

    function acceptReport(
        uint48 nextCutoffTime_
    ) external onlyRole(ACCEPT_REPORT_ROLE) nonReentrant {
        address[] memory assets = _allowedAssetsUnion();
        (uint256 batchId, uint256[] memory prices) = _oracleAcceptReport(assets, nextCutoffTime_);
        _settleAll(assets, prices, batchId);
    }

    function acceptSuspiciousReport(
        uint48 nextCutoffTime_
    ) external onlyRole(ACCEPT_SUSPICIOUS_REPORT_ROLE) nonReentrant {
        address[] memory assets = _allowedAssetsUnion();
        (uint256 batchId, uint256[] memory prices) = _oracleAcceptSuspiciousReport(assets, nextCutoffTime_);
        _settleAll(assets, prices, batchId);
    }

    /// @inheritdoc IFund
    /// @dev Uses the asset-payout snapshot recorded by `settleRedeem` at
    /// acceptance time, so later admin changes to exit fee or price cannot
    /// desynchronize the queue's accounting from the actual payout.
    function fundRedeem(
        address asset,
        uint256 batchId
    ) external onlyRole(FUND_REDEEM_ROLE) nonReentrant {
        address rq = redeemQueue();
        uint256 assetAmount = IRedeemQueue(rq).batchAssetTotals(asset, batchId);

        TransferHelper.transfer(asset, rq, assetAmount);
        IRedeemQueue(rq).fundRedeem(asset, batchId);
    }

    /// @dev Returns the union of deposit + redeem allowed assets, plus the
    /// fee base asset if it's not already in either set. The fee base asset
    /// must always have a report so management + performance fees can accrue.
    function _allowedAssetsUnion() internal view returns (address[] memory) {
        address[] memory assets = AssetSet.union(
            IDepositQueue(depositQueue()).getAllowedAssets(),
            IRedeemQueue(redeemQueue()).getAllowedAssets()
        );
        return AssetSet.add(assets, _feeBaseAsset());
    }

    /// @dev Fees accrue before any settlement so the management/performance
    /// fee base is the supply that was invested over the elapsed period —
    /// independent of the base asset's position in `assets`. Settling first
    /// would let this batch's deposit mints and redeem burns leak into the
    /// fee base.
    function _settleAll(
        address[] memory assets,
        uint256[] memory prices,
        uint256 batchId
    ) internal {
        address shareToken = share();
        address baseAsset = _feeBaseAsset();
        // Must be read before `_accrueFees`: accrual promotes configs staged
        // for the next batch into the active config, after which the
        // FeeManager can no longer resolve this batch's rates.
        IFeeManager.FeeConfig memory feeConfig = _feeConfigForBatch(batchId);
        address feeRecipient_ = _feeRecipient();

        for (uint256 i = 0; i < assets.length; i++) {
            if (assets[i] != baseAsset) continue;
            uint256 totalSupply = IFundShare(shareToken).totalSupply();
            (address recipient, uint256 feeShares, address protocolRecipient, uint256 protocolFeeShares) = _accrueFees(totalSupply, prices[i], batchId);
            feeRecipient_ = recipient;
            if (feeShares > 0) {
                IFundShare(shareToken).mint(recipient, feeShares);
            }
            if (protocolFeeShares > 0) {
                IFundShare(shareToken).mint(protocolRecipient, protocolFeeShares);
            }
            break;
        }

        for (uint256 i = 0; i < assets.length; i++) {
            _settleDeposits(assets[i], batchId, prices[i], shareToken, feeRecipient_, feeConfig.entryFeeBps);
            _settleRedeems(assets[i], batchId, prices[i], shareToken, feeRecipient_, feeConfig.exitFeeBps);
        }
    }
}
