// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./ModuleBase.sol";
import "../interfaces/IOracle.sol";
import "../interfaces/IOracleModule.sol";
import "../interfaces/IReportModule.sol";

/// @dev Stores the oracle address and exposes only the pieces Fund needs
/// during orchestration. All admin/submit/reject/view proxies have been
/// removed — users call the Oracle spoke directly; Oracle authorizes via a
/// role callback to Fund's access control registry.
abstract contract OracleModule is IOracleModule, ModuleBase {
    /// @custom:storage-location erc7201:neobank.storage.OracleModule
    struct OracleStorage {
        address oracle;
    }

    function _oracleStorage() private pure returns (OracleStorage storage $) {
        bytes32 slot = _erc7201Slot("erc7201:neobank.storage.OracleModule");
        assembly {
            $.slot := slot
        }
    }

    function __OracleModule_init(address oracle_) internal onlyInitializing {
        _oracleStorage().oracle = oracle_;
    }

    /// @inheritdoc IOracleModule
    function oracle() public view returns (address) {
        return _oracleStorage().oracle;
    }

    /// @inheritdoc IOracleModule
    /// @dev Kept as a Fund-side accessor because DepositQueue and RedeemQueue
    /// read the current batch id during user entrypoints; star architecture
    /// requires they route through Fund rather than know Oracle directly.
    function getCurrentBatchId() external view returns (uint256) {
        return IOracle(_oracleStorage().oracle).getCurrentBatchId();
    }

    /// @inheritdoc IOracleModule
    function getSettlingBatch() external view returns (uint256 batchId, uint48 cutoffTime) {
        IOracle oracleContract = IOracle(_oracleStorage().oracle);
        return (oracleContract.currentBatchId(), oracleContract.nextCutoffTime());
    }

    function _getReport(
        address asset,
        uint256 batchId
    ) internal view returns (IReportModule.Report memory) {
        return IOracle(_oracleStorage().oracle).getReport(asset, batchId);
    }

    function _oracleAcceptReport(
        address[] memory assets,
        uint48 nextCutoffTime_
    ) internal returns (uint256 batchId, uint256[] memory prices) {
        return IOracle(_oracleStorage().oracle).acceptReport(assets, nextCutoffTime_);
    }

    function _oracleAcceptSuspiciousReport(
        address[] memory assets,
        uint48 nextCutoffTime_
    ) internal returns (uint256 batchId, uint256[] memory prices) {
        return IOracle(_oracleStorage().oracle).acceptSuspiciousReport(assets, nextCutoffTime_);
    }
}
