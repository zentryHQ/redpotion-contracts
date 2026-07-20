// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "@openzeppelin/contracts/access/IAccessControl.sol";

import "./FundRoles.sol";

/// @dev Spoke-side auth module. Inherit to gain:
///   - Role-name `bytes32` constants (from FundRoles), so spoke contracts
///     write `onlyRole(SET_FEES_ROLE)` without importing anything else.
///   - The `onlyRole(ROLE)` modifier, which authorizes via a callback to the
///     Fund's access control registry.
///
/// The concrete spoke must implement `_fund()` to expose its stored Fund
/// address (typically `return fund;`). An internal getter is used rather than
/// the public one so the modifier makes a cheap internal call instead of an
/// external SLOAD through `this.fund()`.
abstract contract FundSpokeACLModule is FundRoles {
    error UnauthorizedRole();

    /// @dev Mirrors OpenZeppelin AccessControl's `DEFAULT_ADMIN_ROLE` so spokes
    /// can write `onlyRole(DEFAULT_ADMIN_ROLE)` against the Fund's ACL.
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    function _fund() internal view virtual returns (address);

    modifier onlyRole(bytes32 role) {
        if (!IAccessControl(_fund()).hasRole(role, msg.sender)) revert UnauthorizedRole();
        _;
    }
}
