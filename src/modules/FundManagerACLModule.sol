// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./ACLModule.sol";

abstract contract FundManagerACLModule is ACLModule {
    bytes32 public constant CREATE_FUND_ROLE = keccak256("CREATE_FUND_ROLE");
    bytes32 public constant SET_FUND_FACTORY_ROLE = keccak256("SET_FUND_FACTORY_ROLE");
    bytes32 public constant SET_SHARE_FACTORY_ROLE = keccak256("SET_SHARE_FACTORY_ROLE");
    bytes32 public constant SET_DEPOSIT_QUEUE_FACTORY_ROLE = keccak256("SET_DEPOSIT_QUEUE_FACTORY_ROLE");
    bytes32 public constant SET_REDEEM_QUEUE_FACTORY_ROLE = keccak256("SET_REDEEM_QUEUE_FACTORY_ROLE");
    bytes32 public constant SET_ORACLE_FACTORY_ROLE = keccak256("SET_ORACLE_FACTORY_ROLE");
    bytes32 public constant SET_FEE_MANAGER_FACTORY_ROLE = keccak256("SET_FEE_MANAGER_FACTORY_ROLE");
    bytes32 public constant SET_RISK_MANAGER_FACTORY_ROLE = keccak256("SET_RISK_MANAGER_FACTORY_ROLE");
    bytes32 public constant SET_STRATEGY_FACTORY_ROLE = keccak256("SET_STRATEGY_FACTORY_ROLE");

    function __FundManagerACLModule_init(
        address admin_,
        RoleHolder[] memory roleHolders_
    ) internal onlyInitializing {
        __ACLModule_init(admin_, roleHolders_);
    }
}
