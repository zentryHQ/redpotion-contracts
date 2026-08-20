// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

interface IFeeManager {

    struct FeeConfig {
        uint256 entryFeeBps;
        uint256 exitFeeBps;
        uint256 managementFeeBps;
        uint256 performanceFeeBps;
        uint256 protocolFeeBps;
    }

    struct PendingFeeConfig {
        FeeConfig config;
        uint256 effectiveBatchId;
    }

    /// @dev `newHighWaterMark` is nonzero only when a performance fee accrued.
    struct FeeAccrualResult {
        address recipient;
        uint256 managementFeeShares;
        uint256 performanceFeeShares;
        uint256 newHighWaterMark;
        address protocolRecipient;
        uint256 protocolFeeShares;
    }

    event FeeRecipientUpdated(address indexed feeRecipient);
    event FeeConfigUpdated(FeeConfig config);
    event FeeConfigPending(FeeConfig config, uint256 effectiveBatchId);
    event FeeBaseAssetUpdated(address indexed asset);
    event HighWaterMarkUpdated(uint256 highWaterMark);
    event LastFeeAccrualUpdated(uint256 timestamp);
    event FeeManagerCreated(address indexed fund);

    error OnlyFund();
    error ZeroAddress();
    error EntryFeeTooHigh();
    error ExitFeeTooHigh();
    error ManagementFeeTooHigh();
    error PerformanceFeeTooHigh();
    error ProtocolFeeTooHigh();

    function fund() external view returns (address);
    function feeBaseAsset() external view returns (address);
    function highWaterMark() external view returns (uint256);
    function lastFeeAccrual() external view returns (uint256);
    function feeRecipient() external view returns (address);
    function entryFeeBps() external view returns (uint256);
    function exitFeeBps() external view returns (uint256);
    function managementFeeBps() external view returns (uint256);
    function performanceFeeBps() external view returns (uint256);
    function protocolFeeBps() external view returns (uint256);
    function getFeeConfig() external view returns (FeeConfig memory);
    /// @dev Staged fee changes not yet promoted, ordered by effectiveBatchId.
    function getPendingFeeConfigs() external view returns (PendingFeeConfig[] memory);
    /// @dev The config a request in `batchId` settles at: the latest staged
    /// config effective at or before `batchId`, else the active config.
    function getFeeConfigForBatch(uint256 batchId) external view returns (FeeConfig memory);

    function initialize(
        address fund_,
        address feeRecipient_,
        address feeBaseAsset_,
        FeeConfig calldata feeConfig_
    ) external;

    function setFeeConfig(FeeConfig calldata config) external;
    function setFeeRecipient(address feeRecipient_) external;
    function setFeeBaseAsset(address asset) external;
    /// @dev Computes management + performance fee shares for the base asset.
    /// Splits protocol fee from fund fee using protocolFeeBps. Updates HWM and
    /// lastFeeAccrual. `batchId` is the batch being settled; staged fee configs
    /// effective from `batchId + 1` are promoted to active after accrual.
    /// Fund mints the shares and emits the accrual events.
    function accrueFees(
        uint256 totalSupply,
        uint256 newPrice,
        uint256 batchId
    ) external returns (FeeAccrualResult memory result);
}
