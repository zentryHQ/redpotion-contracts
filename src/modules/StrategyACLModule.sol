// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./ACLModule.sol";

abstract contract StrategyACLModule is ACLModule {
    bytes32 public constant CALLER_ROLE = keccak256("CALLER_ROLE");

    function __StrategyACLModule_init(
        address admin_,
        RoleHolder[] memory roleHolders_
    ) internal onlyInitializing {
        __ACLModule_init(admin_, roleHolders_);
    }
}
