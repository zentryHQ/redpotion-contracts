// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "./interfaces/IOracle.sol";
import "./interfaces/IReportModule.sol";
import "./modules/FundSpokeACLModule.sol";

contract Oracle is
    IOracle,
    ContextUpgradeable,
    ReentrancyGuardUpgradeable,
    FundSpokeACLModule
{
    uint48 public constant MIN_ACCEPT_REPORT_DELAY_LIMIT = 30 days;
    uint48 public constant MAX_ACCEPT_REPORT_DELAY_LIMIT = 30 days;
    uint48 internal constant DEFAULT_MIN_ACCEPT_REPORT_DELAY = 1 hours;
    uint48 internal constant DEFAULT_MAX_ACCEPT_REPORT_DELAY = 7 days;

    address public fund;

    uint256 public currentBatchId;
    uint48 public nextCutoffTime;
    uint48 public minAcceptReportDelay;
    uint48 public maxAcceptReportDelay;

    mapping(address asset => mapping(uint256 batchId => IReportModule.Report)) private _batchReports;
    mapping(address asset => mapping(uint256 batchId => IReportModule.StoredPendingReport)) private _pendingReports;
    mapping(address asset => uint256) public lastAcceptedPrice;
    mapping(address asset => IReportModule.PriceSafety) private _priceSafety;

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
        uint48 firstCutoffTime_,
        uint48 minAcceptReportDelay_,
        uint48 maxAcceptReportDelay_,
        IReportModule.PriceSafetyInit[] calldata priceSafeties_
    ) external initializer {
        if (fund_ == address(0)) revert ZeroAddress();

        __Context_init();
        __ReentrancyGuard_init();

        fund = fund_;
        _setMinAcceptReportDelay(minAcceptReportDelay_ == 0 ? DEFAULT_MIN_ACCEPT_REPORT_DELAY : minAcceptReportDelay_);
        _setMaxAcceptReportDelay(maxAcceptReportDelay_ == 0 ? DEFAULT_MAX_ACCEPT_REPORT_DELAY : maxAcceptReportDelay_);
        _setNextCutoffTime(firstCutoffTime_);

        for (uint256 i = 0; i < priceSafeties_.length; i++) {
            _setPriceSafety(priceSafeties_[i].asset, priceSafeties_[i].safety);
        }

        emit OracleCreated(fund_);
    }

    function priceSafety(address asset) external view returns (IReportModule.PriceSafety memory) {
        return _priceSafety[asset];
    }

    function getCurrentBatchId() public view returns (uint256) {
        if (nextCutoffTime != 0 && block.timestamp >= nextCutoffTime) {
            return currentBatchId + 1;
        }
        return currentBatchId;
    }

    function getReport(
        address asset,
        uint256 batchId
    ) external view returns (IReportModule.Report memory) {
        return _batchReports[asset][batchId];
    }

    function getPendingReport(
        address asset,
        uint256 batchId
    ) external view returns (IReportModule.PendingReport memory) {
        IReportModule.StoredPendingReport storage pending = _pendingReports[asset][batchId];
        return IReportModule.PendingReport({
            price: pending.price,
            suspicious: pending.price != 0 && _checkPriceSafety(asset, pending.price),
            submittedAt: pending.submittedAt
        });
    }

    /// @inheritdoc IOracle
    function submitReport(
        IReportModule.ReportSubmission[] calldata reports
    ) external onlyRole(SUBMIT_REPORT_ROLE) {
        if (block.timestamp < nextCutoffTime) revert IReportModule.BatchNotClosed();
        uint256 batchId = currentBatchId;

        IReportModule.ReportResult[] memory results = new IReportModule.ReportResult[](reports.length);

        for (uint256 i = 0; i < reports.length; i++) {
            address asset = reports[i].asset;
            uint256 price = reports[i].price;

            if (price == 0) revert IReportModule.ZeroPrice();
            if (_batchReports[asset][batchId].price != 0)
                revert IReportModule.BatchAlreadySettled();

            bool suspicious = _checkPriceSafety(asset, price);

            _pendingReports[asset][batchId] = IReportModule.StoredPendingReport({
                price: price,
                submittedAt: uint48(block.timestamp)
            });

            results[i] = IReportModule.ReportResult({ asset: asset, price: price, suspicious: suspicious });
        }

        emit IReportModule.ReportSubmitted(batchId, results);
    }

    /// @inheritdoc IOracle
    function rejectReport(
        address[] calldata assets
    ) external onlyRole(REJECT_REPORT_ROLE) {
        if (nextCutoffTime == 0 || block.timestamp < nextCutoffTime)
            revert IReportModule.BatchNotClosed();
        uint256 batchId = currentBatchId;

        for (uint256 i = 0; i < assets.length; i++) {
            if (_pendingReports[assets[i]][batchId].price == 0)
                revert IReportModule.NoPendingReport();

            delete _pendingReports[assets[i]][batchId];
        }

        emit IReportModule.ReportRejected(batchId, assets);
    }

    /// @inheritdoc IOracle
    function acceptReport(
        address[] calldata assets,
        uint48 nextCutoffTime_
    ) external onlyFund nonReentrant returns (uint256 batchId, uint256[] memory prices) {
        _requireBatchClosed();
        batchId = currentBatchId;
        _requireAcceptWindow(assets, batchId);

        for (uint256 i = 0; i < assets.length; i++) {
            if (_checkPriceSafety(assets[i], _pendingReports[assets[i]][batchId].price))
                revert IReportModule.SuspiciousReportPending();
        }

        prices = _consumeAndAdvance(assets, batchId, nextCutoffTime_);
    }

    /// @inheritdoc IOracle
    function acceptSuspiciousReport(
        address[] calldata assets,
        uint48 nextCutoffTime_
    ) external onlyFund nonReentrant returns (uint256 batchId, uint256[] memory prices) {
        _requireBatchClosed();
        batchId = currentBatchId;
        _requireAcceptWindow(assets, batchId);
        prices = _consumeAndAdvance(assets, batchId, nextCutoffTime_);
    }

    /// @inheritdoc IOracle
    function setPriceSafety(
        address asset,
        IReportModule.PriceSafety calldata safety
    ) external onlyRole(SET_PRICE_SAFETY_ROLE) {
        _setPriceSafety(asset, safety);
    }

    /// @inheritdoc IOracle
    function setPriceSafetyBatch(
        IReportModule.PriceSafetyInit[] calldata safeties
    ) external onlyRole(SET_PRICE_SAFETY_ROLE) {
        for (uint256 i = 0; i < safeties.length; i++) {
            _setPriceSafety(safeties[i].asset, safeties[i].safety);
        }
    }

    /// @inheritdoc IOracle
    function setNextCutoffTime(uint48 nextCutoffTime_) external onlyRole(SET_NEXT_CUTOFF_TIME_ROLE) {
        if (nextCutoffTime != 0 && block.timestamp >= nextCutoffTime)
            revert IReportModule.BatchAlreadyClosed();
        _setNextCutoffTime(nextCutoffTime_);
    }

    /// @inheritdoc IOracle
    function setMinAcceptReportDelay(uint48 delay) external onlyRole(SET_MIN_ACCEPT_REPORT_DELAY_ROLE) {
        _setMinAcceptReportDelay(delay);
    }

    /// @inheritdoc IOracle
    function setMaxAcceptReportDelay(uint48 delay) external onlyRole(SET_MAX_ACCEPT_REPORT_DELAY_ROLE) {
        _setMaxAcceptReportDelay(delay);
    }

    function _requireBatchClosed() internal view {
        if (nextCutoffTime == 0 || block.timestamp < nextCutoffTime)
            revert IReportModule.BatchNotClosed();
    }

    function _requireAcceptWindow(address[] calldata assets, uint256 batchId) internal view {
        for (uint256 i = 0; i < assets.length; i++) {
            uint256 submittedAt = _pendingReports[assets[i]][batchId].submittedAt;
            if (submittedAt == 0) revert IReportModule.NoPendingReport();
            uint256 elapsed = block.timestamp - submittedAt;
            if (elapsed < minAcceptReportDelay) revert IReportModule.AcceptTooEarly();
            if (elapsed > maxAcceptReportDelay) revert IReportModule.AcceptTooLate();
        }
    }

    function _consumeAndAdvance(
        address[] calldata assets,
        uint256 batchId,
        uint48 nextCutoffTime_
    ) internal returns (uint256[] memory prices) {
        prices = new uint256[](assets.length);
        for (uint256 i = 0; i < assets.length; i++) {
            prices[i] = _consumePendingReport(assets[i], batchId);
        }
        _advanceBatch(nextCutoffTime_);
    }

    function _consumePendingReport(
        address asset,
        uint256 batchId
    ) internal returns (uint256 price) {
        IReportModule.StoredPendingReport storage pending = _pendingReports[asset][batchId];
        price = pending.price;
        if (price == 0) revert IReportModule.NoPendingReport();

        delete _pendingReports[asset][batchId];

        _batchReports[asset][batchId] = IReportModule.Report({price: price});
        lastAcceptedPrice[asset] = price;

        emit IReportModule.ReportAccepted(batchId, asset);
    }

    function _advanceBatch(uint48 nextCutoffTime_) internal {
        if (nextCutoffTime_ == 0 || nextCutoffTime_ <= uint48(block.timestamp)) {
            revert IReportModule.InvalidCutoffTime();
        }
        currentBatchId++;
        _setNextCutoffTime(nextCutoffTime_);
    }

    function _setNextCutoffTime(uint48 nextCutoffTime_) internal {
        if (nextCutoffTime_ <= uint48(block.timestamp)) revert IReportModule.InvalidCutoffTime();
        nextCutoffTime = nextCutoffTime_;
        emit IReportModule.NextCutoffTimeUpdated(currentBatchId, nextCutoffTime_);
    }

    function _setMinAcceptReportDelay(uint48 delay) internal {
        if (delay == 0) revert IReportModule.ZeroDelay();
        if (delay > MIN_ACCEPT_REPORT_DELAY_LIMIT) revert IReportModule.DelayExceedsLimit();
        if (maxAcceptReportDelay != 0 && delay > maxAcceptReportDelay)
            revert IReportModule.MinDelayExceedsMax();
        minAcceptReportDelay = delay;
        emit IReportModule.MinAcceptReportDelayUpdated(delay);
    }

    function _setMaxAcceptReportDelay(uint48 delay) internal {
        if (delay == 0) revert IReportModule.ZeroDelay();
        if (delay > MAX_ACCEPT_REPORT_DELAY_LIMIT) revert IReportModule.DelayExceedsLimit();
        if (delay < minAcceptReportDelay) revert IReportModule.MinDelayExceedsMax();
        maxAcceptReportDelay = delay;
        emit IReportModule.MaxAcceptReportDelayUpdated(delay);
    }

    function _setPriceSafety(address asset, IReportModule.PriceSafety calldata safety) internal {
        if (asset == address(0)) revert IReportModule.InvalidPriceSafety();
        if (safety.maxPrice != 0 && safety.minPrice > safety.maxPrice)
            revert IReportModule.InvalidPriceSafety();
        if (safety.maxDeviationBps > 10000) revert IReportModule.InvalidPriceSafety();
        _priceSafety[asset] = safety;
        emit IReportModule.PriceSafetyUpdated(asset, safety);
    }

    function _checkPriceSafety(
        address asset,
        uint256 price
    ) internal view returns (bool suspicious) {
        IReportModule.PriceSafety storage safety = _priceSafety[asset];

        if (safety.minPrice != 0 && price < safety.minPrice) return true;
        if (safety.maxPrice != 0 && price > safety.maxPrice) return true;

        uint256 lastPrice = lastAcceptedPrice[asset];
        if (lastPrice == 0) return false;

        uint256 delta = price > lastPrice ? price - lastPrice : lastPrice - price;

        if (safety.maxAbsoluteDelta != 0 && delta > safety.maxAbsoluteDelta) return true;

        if (safety.maxDeviationBps != 0) {
            uint256 maxDelta = (lastPrice * safety.maxDeviationBps) / 10000;
            if (delta > maxDelta) return true;
        }
    }
}
