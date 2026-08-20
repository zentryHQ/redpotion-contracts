// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./IModuleErrors.sol";

/// @dev Minimal Fund-side surface for FeeManager. Admin and pure-view proxies
/// were removed — callers read state or invoke admin functions on the
/// FeeManager spoke directly (role-callback auth).
interface IFeeManagerModule is IModuleErrors {
    event FeeManagerUpdated(address indexed feeManager);

    // Accrual events are emitted by Fund (not the FeeManager spoke) so the
    // emitter identifies the fund and the payload carries the settled batch.
    event ManagementFeeAccrued(uint256 indexed batchId, uint256 feeShares);
    event PerformanceFeeAccrued(uint256 indexed batchId, uint256 feeShares, uint256 newHighWaterMark);
    event ProtocolFeeAccrued(uint256 indexed batchId, uint256 feeShares);

    function feeManager() external view returns (address);
}
