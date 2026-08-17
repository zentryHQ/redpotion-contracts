// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./interfaces/IRiskManager.sol";
import "./interfaces/IFund.sol";
import "./modules/FundSpokeACLModule.sol";

contract RiskManager is
    IRiskManager,
    ContextUpgradeable,
    ReentrancyGuardUpgradeable,
    FundSpokeACLModule
{
    address public fund;

    function _fund() internal view override returns (address) {
        return fund;
    }

    uint256 public tvlCap;
    uint256 public maxBatchDepositCap;
    uint256 public maxBatchRedeemCap;
    uint256 public minDepositAmount;
    uint256 public minRedeemAmount;
    uint256 public maxDrawdownBps;
    bool public isEmergencyPaused;
    bytes32 public merkleRoot;

    modifier onlyFund() {
        if (_msgSender() != fund) revert OnlyFund();
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address fund_,
        RiskConfig calldata config_
    ) external initializer {
        if (fund_ == address(0)) revert ZeroAddress();

        __Context_init();
        __ReentrancyGuard_init();

        fund = fund_;
        if (config_.tvlCap != 0) _setTvlCap(config_.tvlCap);
        if (config_.maxBatchDepositCap != 0) _setMaxBatchDepositCap(config_.maxBatchDepositCap);
        if (config_.maxBatchRedeemCap != 0) _setMaxBatchRedeemCap(config_.maxBatchRedeemCap);
        if (config_.minDepositAmount != 0) _setMinDepositAmount(config_.minDepositAmount);
        if (config_.minRedeemAmount != 0) _setMinRedeemAmount(config_.minRedeemAmount);
        if (config_.maxDrawdownBps != 0) _setMaxDrawdown(config_.maxDrawdownBps);
        if (config_.merkleRoot != bytes32(0)) _setMerkleRoot(config_.merkleRoot);

        emit RiskManagerCreated(fund_);
    }

    /// @inheritdoc IRiskManager
    function checkDeposit(
        address depositor,
        address asset,
        uint256 batchId,
        uint256 depositAmount,
        bytes32[] calldata proof
    ) external view {
        if (isEmergencyPaused) revert EmergencyPausedError();
        if (merkleRoot != bytes32(0)) {
            bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(depositor))));
            if (!MerkleProof.verify(proof, merkleRoot, leaf)) revert NotWhitelisted();
        }

        if (maxBatchDepositCap == 0 && minDepositAmount == 0 && tvlCap == 0 && maxDrawdownBps == 0) return;

        IRiskManager.RiskContext memory ctx = IFund(fund).getRiskContext(asset, batchId);

        if (ctx.basePrice == 0) revert BaseAssetPriceUnavailable();

        if (maxDrawdownBps != 0) {
            uint256 hwm = ctx.highWaterMark;
            if (hwm != 0 && ctx.basePrice < hwm) {
                uint256 drawdownBps = ((hwm - ctx.basePrice) * 10000) / hwm;
                if (drawdownBps > maxDrawdownBps) revert DrawdownBreached();
            }
        }

        if (ctx.assetPrice == 0) revert DepositAssetPriceUnavailable();

        // Single full-precision division: a share round-trip floors twice and
        // rejects deposits worth exactly minDepositAmount.
        uint256 depositValueInBase = Math.mulDiv(depositAmount, ctx.basePrice, ctx.assetPrice);

        if (minDepositAmount != 0 && depositValueInBase < minDepositAmount) {
            revert DepositBelowMinimum();
        }

        if (maxBatchDepositCap != 0) {
            if (ctx.batchDepositTotalInBase + depositValueInBase > maxBatchDepositCap) revert BatchDepositCapExceeded();
        }

        if (tvlCap != 0) {
            uint256 currentTvl = (ctx.shareSupply * ctx.basePrice) / 1e18;
            if (currentTvl + ctx.batchDepositTotalInBase + depositValueInBase > tvlCap) revert TvlCapExceeded();
        }
    }

    /// @inheritdoc IRiskManager
    function checkRedeem(
        uint256 batchId,
        uint256 redeemShares
    ) external view {
        if (isEmergencyPaused) revert EmergencyPausedError();

        if (maxBatchRedeemCap == 0 && minRedeemAmount == 0) return;

        IRiskManager.RiskContext memory ctx = IFund(fund).getRiskContext(address(0), batchId);

        if (ctx.basePrice == 0) revert BaseAssetPriceUnavailable();

        uint256 redeemValueInBase = (redeemShares * ctx.basePrice) / 1e18;

        if (minRedeemAmount != 0 && redeemValueInBase < minRedeemAmount) {
            revert RedeemBelowMinimum();
        }

        if (maxBatchRedeemCap != 0) {
            if (ctx.batchRedeemTotalInBase + redeemValueInBase > maxBatchRedeemCap) revert BatchRedeemCapExceeded();
        }
    }

    /// @inheritdoc IRiskManager
    function estimateDeposit(
        address asset,
        uint256 depositAmount
    ) external view returns (uint256 shares) {
        IRiskManager.RiskContext memory ctx = IFund(fund).getRiskContext(asset, 0);

        if (ctx.assetPrice == 0 || depositAmount == 0) return 0;

        uint256 totalShares = (depositAmount * 1e18) / ctx.assetPrice;
        uint256 feeShares = (totalShares * ctx.entryFeeBps) / 10000;
        shares = totalShares - feeShares;
    }

    /// @inheritdoc IRiskManager
    function estimateRedeem(
        address asset,
        uint256 redeemShares
    ) external view returns (uint256 assetAmount) {
        IRiskManager.RiskContext memory ctx = IFund(fund).getRiskContext(asset, 0);

        if (ctx.assetPrice == 0 || redeemShares == 0) return 0;

        uint256 feeShares = (redeemShares * ctx.exitFeeBps) / 10000;
        uint256 netShares = redeemShares - feeShares;
        assetAmount = (netShares * ctx.assetPrice) / 1e18;
    }

    /// @inheritdoc IRiskManager
    function getMinDepositAmount(address asset) external view returns (uint256) {
        if (minDepositAmount == 0) return 0;

        IRiskManager.RiskContext memory ctx = IFund(fund).getRiskContext(asset, 0);
        if (ctx.basePrice == 0) revert BaseAssetPriceUnavailable();
        if (ctx.assetPrice == 0) revert DepositAssetPriceUnavailable();

        return Math.mulDiv(minDepositAmount, ctx.assetPrice, ctx.basePrice, Math.Rounding.Ceil);
    }

    /// @inheritdoc IRiskManager
    function getMinRedeemShares() external view returns (uint256) {
        if (minRedeemAmount == 0) return 0;

        IRiskManager.RiskContext memory ctx = IFund(fund).getRiskContext(address(0), 0);
        if (ctx.basePrice == 0) revert BaseAssetPriceUnavailable();

        return Math.mulDiv(minRedeemAmount, 1e18, ctx.basePrice, Math.Rounding.Ceil);
    }

    /// @inheritdoc IRiskManager
    function setTvlCap(uint256 cap) external onlyRole(SET_TVL_CAP_ROLE) { _setTvlCap(cap); }

    /// @inheritdoc IRiskManager
    function setMaxBatchDepositCap(uint256 cap) external onlyRole(SET_BATCH_CAPS_ROLE) { _setMaxBatchDepositCap(cap); }

    /// @inheritdoc IRiskManager
    function setMaxBatchRedeemCap(uint256 cap) external onlyRole(SET_BATCH_CAPS_ROLE) { _setMaxBatchRedeemCap(cap); }

    /// @inheritdoc IRiskManager
    function setMinDepositAmount(uint256 amount) external onlyRole(SET_MIN_DEPOSIT_AMOUNT_ROLE) { _setMinDepositAmount(amount); }

    /// @inheritdoc IRiskManager
    function setMinRedeemAmount(uint256 amount) external onlyRole(SET_MIN_REDEEM_AMOUNT_ROLE) { _setMinRedeemAmount(amount); }

    /// @inheritdoc IRiskManager
    function setMaxDrawdown(uint256 bps) external onlyRole(SET_MAX_DRAWDOWN_ROLE) { _setMaxDrawdown(bps); }

    /// @inheritdoc IRiskManager
    function emergencyPause() external onlyRole(EMERGENCY_PAUSE_ROLE) {
        isEmergencyPaused = true;
        emit EmergencyPaused();
    }

    /// @inheritdoc IRiskManager
    function emergencyUnpause() external onlyRole(EMERGENCY_PAUSE_ROLE) {
        isEmergencyPaused = false;
        emit EmergencyUnpaused();
    }

    /// @inheritdoc IRiskManager
    function setMerkleRoot(bytes32 root) external onlyRole(SET_WHITELIST_ROLE) { _setMerkleRoot(root); }

    function _setTvlCap(uint256 cap) internal { tvlCap = cap; emit TvlCapUpdated(cap); }
    function _setMaxBatchDepositCap(uint256 cap) internal { maxBatchDepositCap = cap; emit MaxBatchDepositCapUpdated(cap); }
    function _setMaxBatchRedeemCap(uint256 cap) internal { maxBatchRedeemCap = cap; emit MaxBatchRedeemCapUpdated(cap); }
    function _setMinDepositAmount(uint256 amount) internal { minDepositAmount = amount; emit MinDepositAmountUpdated(amount); }
    function _setMinRedeemAmount(uint256 amount) internal { minRedeemAmount = amount; emit MinRedeemAmountUpdated(amount); }

    function _setMaxDrawdown(uint256 bps) internal {
        if (bps > 10000) revert InvalidDrawdownBps();
        maxDrawdownBps = bps;
        emit MaxDrawdownUpdated(bps);
    }

    function _setMerkleRoot(bytes32 root) internal {
        merkleRoot = root;
        emit MerkleRootUpdated(root);
    }
}
