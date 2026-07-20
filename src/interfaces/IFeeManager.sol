// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

interface IFeeManager {
    // Structs

    struct FeeConfig {
        uint256 entryFeeBps;
        uint256 exitFeeBps;
        uint256 managementFeeBps;
        uint256 performanceFeeBps;
        uint256 protocolFeeBps;
    }

    // Events

    event ManagementFeeAccrued(uint256 feeShares);
    event PerformanceFeeAccrued(uint256 feeShares, uint256 newHighWaterMark);
    event ProtocolFeeAccrued(uint256 protocolFeeShares);
    event FeeRecipientUpdated(address indexed feeRecipient);
    event FeeConfigUpdated(FeeConfig config);
    event FeeBaseAssetUpdated(address indexed asset);
    event HighWaterMarkUpdated(uint256 highWaterMark);
    event LastFeeAccrualUpdated(uint256 timestamp);
    event FeeManagerCreated(address indexed fund);

    // Errors

    error OnlyFund();
    error ZeroAddress();
    error EntryFeeTooHigh();
    error ExitFeeTooHigh();
    error ManagementFeeTooHigh();
    error PerformanceFeeTooHigh();
    error ProtocolFeeTooHigh();

    // View functions

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

    // Mutable functions

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
    /// lastFeeAccrual. Returns (feeRecipient, feeShares, protocolFeeRecipient, protocolFeeShares).
    function accrueFees(
        uint256 totalSupply,
        uint256 newPrice
    ) external returns (address recipient, uint256 feeShares, address protocolRecipient, uint256 protocolFeeShares);
}
