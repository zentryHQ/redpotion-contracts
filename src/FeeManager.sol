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
    PendingFeeConfig[] private _pendingFeeConfigs;

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
        _validateFeeConfig(feeConfig_);
        _setFeeConfig(feeConfig_);
        _setLastFeeAccrual(block.timestamp);
        emit FeeManagerCreated(fund_);
    }

    function getFeeConfig() public view returns (FeeConfig memory) {
        return FeeConfig({
            entryFeeBps: entryFeeBps,
            exitFeeBps: exitFeeBps,
            managementFeeBps: managementFeeBps,
            performanceFeeBps: performanceFeeBps,
            protocolFeeBps: protocolFeeBps
        });
    }

    /// @inheritdoc IFeeManager
    function getPendingFeeConfigs() external view returns (PendingFeeConfig[] memory) {
        return _pendingFeeConfigs;
    }

    /// @inheritdoc IFeeManager
    function getFeeConfigForBatch(uint256 batchId) public view returns (FeeConfig memory) {
        for (uint256 i = _pendingFeeConfigs.length; i > 0; i--) {
            PendingFeeConfig storage pending = _pendingFeeConfigs[i - 1];
            if (pending.effectiveBatchId <= batchId) return pending.config;
        }
        return getFeeConfig();
    }

    /// @dev Fee changes never touch a batch that is already open for
    /// requests: they take effect from the next batch to open, which cannot
    /// contain requests yet. Restaging for a boundary that already has an
    /// entry replaces that entry; once the batch opens, a new staging targets
    /// the following batch, so every request settles at the config it was
    /// quoted.
    function setFeeConfig(FeeConfig calldata config) external onlyRole(SET_FEES_ROLE) {
        _validateFeeConfig(config);
        uint256 effectiveBatchId = IFund(fund).getCurrentBatchId() + 1;
        for (uint256 i = 0; i < _pendingFeeConfigs.length; i++) {
            if (_pendingFeeConfigs[i].effectiveBatchId == effectiveBatchId) {
                _pendingFeeConfigs[i].config = config;
                emit FeeConfigPending(config, effectiveBatchId);
                return;
            }
        }
        _pendingFeeConfigs.push(PendingFeeConfig({config: config, effectiveBatchId: effectiveBatchId}));
        emit FeeConfigPending(config, effectiveBatchId);
    }

    function setFeeRecipient(address feeRecipient_) external onlyRole(SET_FEE_RECIPIENT_ROLE) {
        _setFeeRecipient(feeRecipient_);
    }

    function setFeeBaseAsset(address asset) external onlyRole(SET_FEE_BASE_ASSET_ROLE) {
        _setFeeBaseAsset(asset);
    }

    /// @inheritdoc IFeeManager
    function accrueFees(
        uint256 totalSupply,
        uint256 newPrice,
        uint256 batchId
    ) external onlyFund returns (FeeAccrualResult memory result) {
        result.recipient = feeRecipient;
        uint256 elapsed = block.timestamp - lastFeeAccrual;

        if (managementFeeBps != 0 && totalSupply != 0 && elapsed > 0) {
            result.managementFeeShares = (totalSupply * managementFeeBps * elapsed) /
                (10000 * 365 days);
        }

        if (performanceFeeBps != 0 && totalSupply != 0) {
            if (highWaterMark == 0) {
                _setHighWaterMark(newPrice);
            } else if (newPrice > highWaterMark) {
                uint256 gain = newPrice - highWaterMark;
                result.performanceFeeShares = (totalSupply * gain * performanceFeeBps) /
                    (newPrice * 10000);
                result.newHighWaterMark = newPrice;
                _setHighWaterMark(newPrice);
            }
        }

        // Protocol fee — same time-based formula as management fee, independent of fund fees.
        // Recipient is resolved live via Fund -> FundManager -> deployer so that protocol
        // migrations only need to flip a single pointer on FundManager.
        if (protocolFeeBps != 0 && totalSupply != 0 && elapsed > 0) {
            address protocolFeeRecipient_ = IFund(fund).protocolFeeRecipient();
            if (protocolFeeRecipient_ != address(0)) {
                result.protocolFeeShares = (totalSupply * protocolFeeBps * elapsed) /
                    (10000 * 365 days);
                result.protocolRecipient = protocolFeeRecipient_;
            }
        }

        _setLastFeeAccrual(block.timestamp);
        _promotePendingFeeConfigs(batchId);
    }

    /// @dev Settling `batchId` is the boundary where configs staged for
    /// `batchId + 1` become active. Staged configs never target the batch
    /// being settled, so the accrual that just ran always used the rates in
    /// force over the elapsed period. Promoted entries are trimmed so the
    /// array only holds upcoming changes.
    function _promotePendingFeeConfigs(uint256 batchId) internal {
        uint256 length = _pendingFeeConfigs.length;
        uint256 promoted = 0;
        while (promoted < length && _pendingFeeConfigs[promoted].effectiveBatchId <= batchId + 1) {
            promoted++;
        }
        if (promoted == 0) return;
        _setFeeConfig(_pendingFeeConfigs[promoted - 1].config);
        for (uint256 i = promoted; i < length; i++) {
            _pendingFeeConfigs[i - promoted] = _pendingFeeConfigs[i];
        }
        for (uint256 i = 0; i < promoted; i++) {
            _pendingFeeConfigs.pop();
        }
    }

    function _validateFeeConfig(FeeConfig calldata config) internal pure {
        if (config.entryFeeBps > 10000) revert EntryFeeTooHigh();
        if (config.exitFeeBps > 10000) revert ExitFeeTooHigh();
        if (config.managementFeeBps > 10000) revert ManagementFeeTooHigh();
        if (config.performanceFeeBps > 10000) revert PerformanceFeeTooHigh();
        if (config.protocolFeeBps > 10000) revert ProtocolFeeTooHigh();
    }

    function _setFeeConfig(FeeConfig memory config) internal {
        entryFeeBps = config.entryFeeBps;
        exitFeeBps = config.exitFeeBps;
        managementFeeBps = config.managementFeeBps;
        performanceFeeBps = config.performanceFeeBps;
        protocolFeeBps = config.protocolFeeBps;
        emit FeeConfigUpdated(config);
    }

    function _setFeeBaseAsset(address asset) internal {
        if (asset == address(0)) revert ZeroAddress();
        // The high-water mark is a share price denominated in the fee base
        // asset, so it is meaningless in the new denomination. Reset it so the
        // next accrual seeds a fresh mark at the new asset's price instead of
        // minting phantom performance fees or tripping the drawdown check.
        if (asset != feeBaseAsset && highWaterMark != 0) {
            _setHighWaterMark(0);
        }
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
