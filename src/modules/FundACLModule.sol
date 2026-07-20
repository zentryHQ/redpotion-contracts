// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./ACLModule.sol";
import "./FundRoles.sol";

/// @dev Fund-side ACL composition. Inherits role identifiers from FundRoles
/// (so `fund.SET_FEES_ROLE()` etc. are auto-exposed) and access-control
/// machinery from ACLModule (providing AccessControl's `onlyRole` modifier
/// for Fund-side modules).
abstract contract FundACLModule is ACLModule, FundRoles {
    function __FundACLModule_init(
        address admin_,
        RoleHolder[] memory roleHolders_
    ) internal onlyInitializing {
        __ACLModule_init(admin_, roleHolders_);
    }
}
