// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./IReportModule.sol";

/// @dev Standalone report contract deployed alongside Fund. All mutations
/// are onlyFund — users call Fund which proxies after role checks.
interface IOracle {
    struct ReportDelays {
        uint48 minAcceptReportDelay;
        uint48 maxAcceptReportDelay;
    }

    error OnlyFund();
    error ZeroAddress();

    event OracleCreated(address indexed fund);

    // Views (public, same as IReportModule)
    function fund() external view returns (address);
    function currentBatchId() external view returns (uint256);
    function nextCutoffTime() external view returns (uint48);
    function minAcceptReportDelay() external view returns (uint48);
    function maxAcceptReportDelay() external view returns (uint48);
    function lastAcceptedPrice(address asset) external view returns (uint256);
    function getCurrentBatchId() external view returns (uint256);
    function getReport(address asset, uint256 batchId) external view returns (IReportModule.Report memory);
    function getPendingReport(address asset, uint256 batchId) external view returns (IReportModule.PendingReport memory);
    function priceSafety(address asset) external view returns (IReportModule.PriceSafety memory);

    // Fund-only mutations
    function initialize(
        address fund_,
        uint48 firstCutoffTime_,
        uint48 minAcceptReportDelay_,
        uint48 maxAcceptReportDelay_,
        IReportModule.PriceSafetyInit[] calldata priceSafeties_
    ) external;

    function submitReport(IReportModule.ReportSubmission[] calldata reports) external;
    function rejectReport(address[] calldata assets) external;
    function acceptReport(
        address[] calldata assets,
        uint48 nextCutoffTime_
    ) external returns (uint256 batchId, uint256[] memory prices);
    function acceptSuspiciousReport(
        address[] calldata assets,
        uint48 nextCutoffTime_
    ) external returns (uint256 batchId, uint256[] memory prices);

    function setPriceSafety(address asset, IReportModule.PriceSafety calldata safety) external;
    function setPriceSafetyBatch(IReportModule.PriceSafetyInit[] calldata safeties) external;
    function setNextCutoffTime(uint48 nextCutoffTime_) external;
    function setMinAcceptReportDelay(uint48 delay) external;
    function setMaxAcceptReportDelay(uint48 delay) external;
}
