// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "./interfaces/IFeeManager.sol";
import "./interfaces/IFund.sol";
import "./modules/FundSpokeACLModule.sol";

contract FeeManager is
    IFeeManager,
    ContextUpgradeable,
    ReentrancyGuardUpgradeable,
    FundSpokeACLModule
{
    address public fund;
    uint256 public entryFeeBps;
    uint256 public exitFeeBps;
    uint256 public managementFeeBps;
    uint256 public performanceFeeBps;
    address public feeBaseAsset;
    uint256 public highWaterMark;
    uint256 public lastFeeAccrual;
    address public feeRecipient;
    uint256 public protocolFeeBps;

    modifier onlyFund() {
        if (_msgSender() != fund) revert OnlyFund();
        _;
    }

    function _fund() internal view override returns (address) {
        return fund;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address fund_,
        address feeRecipient_,
        address feeBaseAsset_,
        FeeConfig calldata feeConfig_
    ) external initializer {
        if (fund_ == address(0)) revert ZeroAddress();
        if (feeRecipient_ == address(0)) revert ZeroAddress();
        if (feeBaseAsset_ == address(0)) revert ZeroAddress();

        __Context_init();
        __ReentrancyGuard_init();

        fund = fund_;
        _setFeeRecipient(feeRecipient_);
        _setFeeBaseAsset(feeBaseAsset_);
        _setFeeConfig(feeConfig_);
        _setLastFeeAccrual(block.timestamp);
        emit FeeManagerCreated(fund_);
    }

    // ========================================
    // Views
    // ========================================

    function getFeeConfig() external view returns (FeeConfig memory) {
        return FeeConfig({
            entryFeeBps: entryFeeBps,
            exitFeeBps: exitFeeBps,
            managementFeeBps: managementFeeBps,
            performanceFeeBps: performanceFeeBps,
            protocolFeeBps: protocolFeeBps
        });
    }

    // ========================================
    // Role-gated: admin setters
    // ========================================

    function setFeeConfig(FeeConfig calldata config) external onlyRole(SET_FEES_ROLE) {
        _setFeeConfig(config);
    }

    function setFeeRecipient(address feeRecipient_) external onlyRole(SET_FEE_RECIPIENT_ROLE) {
        _setFeeRecipient(feeRecipient_);
    }

    function setFeeBaseAsset(address asset) external onlyRole(SET_FEE_BASE_ASSET_ROLE) {
        _setFeeBaseAsset(asset);
    }

    // ========================================
    // Fund-only: fee accrual
    // ========================================

    /// @inheritdoc IFeeManager
    function accrueFees(
        uint256 totalSupply,
        uint256 newPrice
    ) external onlyFund returns (address recipient, uint256 feeShares, address protocolRecipient, uint256 protocolFeeShares) {
        recipient = feeRecipient;
        uint256 elapsed = block.timestamp - lastFeeAccrual;

        // Management fee
        if (managementFeeBps != 0 && totalSupply != 0 && elapsed > 0) {
            uint256 mgmtShares = (totalSupply * managementFeeBps * elapsed) /
                (10000 * 365 days);
            feeShares += mgmtShares;
            if (mgmtShares > 0) emit ManagementFeeAccrued(mgmtShares);
        }

        // Performance fee
        if (performanceFeeBps != 0 && totalSupply != 0) {
            if (highWaterMark == 0) {
                _setHighWaterMark(newPrice);
            } else if (newPrice > highWaterMark) {
                uint256 gain = newPrice - highWaterMark;
                uint256 perfShares = (totalSupply * gain * performanceFeeBps) /
                    (newPrice * 10000);
                feeShares += perfShares;
                _setHighWaterMark(newPrice);
                if (perfShares > 0) emit PerformanceFeeAccrued(perfShares, newPrice);
            }
        }

        // Protocol fee — same time-based formula as management fee, independent of fund fees.
        // Recipient is resolved live via Fund -> FundManager -> deployer so that protocol
        // migrations only need to flip a single pointer on FundManager.
        if (protocolFeeBps != 0 && totalSupply != 0 && elapsed > 0) {
            address protocolFeeRecipient_ = IFund(fund).protocolFeeRecipient();
            if (protocolFeeRecipient_ != address(0)) {
                protocolFeeShares = (totalSupply * protocolFeeBps * elapsed) /
                    (10000 * 365 days);
                protocolRecipient = protocolFeeRecipient_;
                if (protocolFeeShares > 0) emit ProtocolFeeAccrued(protocolFeeShares);
            }
        }

        _setLastFeeAccrual(block.timestamp);
    }

    // ========================================
    // Internals
    // ========================================

    function _setFeeConfig(FeeConfig calldata config) internal {
        if (config.entryFeeBps > 10000) revert EntryFeeTooHigh();
        if (config.exitFeeBps > 10000) revert ExitFeeTooHigh();
        if (config.managementFeeBps > 10000) revert ManagementFeeTooHigh();
        if (config.performanceFeeBps > 10000) revert PerformanceFeeTooHigh();
        if (config.protocolFeeBps > 10000) revert ProtocolFeeTooHigh();
        entryFeeBps = config.entryFeeBps;
        exitFeeBps = config.exitFeeBps;
        managementFeeBps = config.managementFeeBps;
        performanceFeeBps = config.performanceFeeBps;
        protocolFeeBps = config.protocolFeeBps;
        emit FeeConfigUpdated(config);
    }

    function _setFeeBaseAsset(address asset) internal {
        if (asset == address(0)) revert ZeroAddress();
        feeBaseAsset = asset;
        emit FeeBaseAssetUpdated(asset);
    }

    function _setFeeRecipient(address feeRecipient_) internal {
        if (feeRecipient_ == address(0)) revert ZeroAddress();
        feeRecipient = feeRecipient_;
        emit FeeRecipientUpdated(feeRecipient_);
    }

    function _setHighWaterMark(uint256 highWaterMark_) internal {
        highWaterMark = highWaterMark_;
        emit HighWaterMarkUpdated(highWaterMark_);
    }

    function _setLastFeeAccrual(uint256 lastFeeAccrual_) internal {
        lastFeeAccrual = lastFeeAccrual_;
        emit LastFeeAccrualUpdated(lastFeeAccrual_);
    }
}
