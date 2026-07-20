// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./IModuleErrors.sol";

/// @dev Minimal Fund-side surface for FeeManager. Admin and pure-view proxies
/// were removed — callers read state or invoke admin functions on the
/// FeeManager spoke directly (role-callback auth).
interface IFeeManagerModule is IModuleErrors {
    event FeeManagerUpdated(address indexed feeManager);

    function feeManager() external view returns (address);
}
