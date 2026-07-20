// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

interface IReportModule {
    // Structs
    struct Report {
        uint256 price;
    }

    struct ReportSubmission {
        address asset;
        uint256 price;
    }

    struct ReportResult {
        address asset;
        uint256 price;
        bool suspicious;
    }

    struct PendingReport {
        uint256 price;
        bool suspicious;
        uint48 submittedAt;
    }

    /// @dev Per-asset price safety bounds. A field set to 0 disables that
    /// particular check. minPrice/maxPrice/maxAbsoluteDelta are HARD reverts;
    /// maxDeviationBps flags the report as suspicious (requires elevated role
    /// to accept).
    struct PriceSafety {
        uint256 minPrice;
        uint256 maxPrice;
        uint256 maxAbsoluteDelta;
        uint256 maxDeviationBps;
    }

    /// @dev Pairs an asset with its PriceSafety config for batch input
    /// (initialize and setPriceSafetyBatch), avoiding the parallel-arrays
    /// length-mismatch failure mode.
    struct PriceSafetyInit {
        address asset;
        PriceSafety safety;
    }

    // Events
    event ReportSubmitted(uint256 indexed batchId, ReportResult[] results);
    event ReportAccepted(uint256 indexed batchId, address indexed asset);
    event ReportRejected(uint256 indexed batchId, address[] assets);
    event NextCutoffTimeUpdated(uint256 indexed batchId, uint48 nextCutoffTime);
    event PriceSafetyUpdated(address indexed asset, PriceSafety safety);
    event MinAcceptReportDelayUpdated(uint48 delay);
    event MaxAcceptReportDelayUpdated(uint48 delay);

    // Errors
    error ZeroPrice();
    error InvalidCutoffTime();
    error BatchNotClosed();
    error BatchAlreadySettled();
    error NoPendingReport();
    error SuspiciousReportPending();
    error BatchNotSettled();
    error AcceptTooEarly();
    error AcceptTooLate();
    error DelayExceedsLimit();
    error ZeroDelay();
    error MinDelayExceedsMax();
    error PriceBelowMin();
    error PriceAboveMax();
    error AbsoluteDeltaTooHigh();
    error InvalidPriceSafety();

    // Views
    function currentBatchId() external view returns (uint256);
    function nextCutoffTime() external view returns (uint48);
    function priceSafety(address asset) external view returns (PriceSafety memory);
    function minAcceptReportDelay() external view returns (uint48);
    function maxAcceptReportDelay() external view returns (uint48);
    function lastAcceptedPrice(address asset) external view returns (uint256);
    function getCurrentBatchId() external view returns (uint256);
    function getReport(address asset, uint256 batchId) external view returns (Report memory);
    function getPendingReport(address asset, uint256 batchId) external view returns (PendingReport memory);

    // Mutable
    function setPriceSafety(address asset, PriceSafety calldata safety) external;
    function setPriceSafetyBatch(PriceSafetyInit[] calldata safeties) external;
    function setNextCutoffTime(uint48 nextCutoffTime_) external;
    function setMinAcceptReportDelay(uint48 delay) external;
    function setMaxAcceptReportDelay(uint48 delay) external;
    function submitReport(ReportSubmission[] calldata reports) external;
    function rejectReport(address[] calldata assets) external;
    function acceptReport(uint48 nextCutoffTime_) external;
    function acceptSuspiciousReport(uint48 nextCutoffTime_) external;
}
