// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

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

    // ========================================
    // Aggregate-read view
    // ========================================

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
        ctx.entryFeeBps = fm.entryFeeBps();
        ctx.exitFeeBps = fm.exitFeeBps();
        ctx.shareSupply = IFundShare(share()).totalSupply();

        address dq = depositQueue();
        address[] memory depositAssets = IDepositQueue(dq).getAllowedAssets();
        for (uint256 i = 0; i < depositAssets.length; i++) {
            uint256 assetTotal = IDepositQueue(dq).batchDepositTotals(depositAssets[i], batchId);
            if (assetTotal == 0) continue;
            uint256 assetPrice = o.lastAcceptedPrice(depositAssets[i]);
            if (assetPrice == 0) continue;
            uint256 shares_ = (assetTotal * 1e18) / assetPrice;
            ctx.batchDepositTotalInBase += (shares_ * ctx.basePrice) / 1e18;
        }

        address rq = redeemQueue();
        address[] memory redeemAssets = IRedeemQueue(rq).getAllowedAssets();
        for (uint256 i = 0; i < redeemAssets.length; i++) {
            uint256 shares_ = IRedeemQueue(rq).batchRedeemTotals(redeemAssets[i], batchId);
            if (shares_ == 0) continue;
            ctx.batchRedeemTotalInBase += (shares_ * ctx.basePrice) / 1e18;
        }
    }

    // ========================================
    // Orchestrated entrypoints
    // ========================================

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

    // ========================================
    // Fund redeem
    // ========================================

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

    // ========================================
    // Internal orchestration
    // ========================================

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

    function _settleAll(
        address[] memory assets,
        uint256[] memory prices,
        uint256 batchId
    ) internal {
        address shareToken = share();
        address baseAsset = _feeBaseAsset();
        uint256 entryFeeBps = _entryFeeBps();
        uint256 exitFeeBps = _exitFeeBps();
        address feeRecipient_;

        for (uint256 i = 0; i < assets.length; i++) {
            address asset = assets[i];
            uint256 price = prices[i];

            if (asset == baseAsset) {
                uint256 totalSupply = IFundShare(shareToken).totalSupply();
                (address recipient, uint256 feeShares, address protocolRecipient, uint256 protocolFeeShares) = _accrueFees(totalSupply, price);
                feeRecipient_ = recipient;
                if (feeShares > 0) {
                    IFundShare(shareToken).mint(recipient, feeShares);
                }
                if (protocolFeeShares > 0) {
                    IFundShare(shareToken).mint(protocolRecipient, protocolFeeShares);
                }
            }

            if (feeRecipient_ == address(0)) {
                feeRecipient_ = _feeRecipient();
            }

            _settleDeposits(asset, batchId, price, shareToken, feeRecipient_, entryFeeBps);
            _settleRedeems(asset, batchId, price, shareToken, feeRecipient_, exitFeeBps);
        }
    }
}
