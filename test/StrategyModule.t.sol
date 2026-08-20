// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {Fund} from "../src/Fund.sol";
import {IStrategyModule} from "../src/interfaces/IStrategyModule.sol";
import {ACLModule} from "../src/modules/ACLModule.sol";

contract MockStrategy {
    address public fund;

    constructor(address fund_) {
        fund = fund_;
    }
}

contract StrategyModuleTest is Test {
    Fund internal fund;
    MockStrategy internal strategy;

    function setUp() public {
        fund = Fund(payable(address(new ERC1967Proxy(address(new Fund()), ""))));

        ACLModule.RoleHolder[] memory roleHolders = new ACLModule.RoleHolder[](2);
        roleHolders[0] = ACLModule.RoleHolder({role: fund.ADD_STRATEGY_ROLE(), account: address(this)});
        roleHolders[1] = ACLModule.RoleHolder({role: fund.REMOVE_STRATEGY_ROLE(), account: address(this)});

        fund.initialize(
            address(uint160(uint256(keccak256("SHARE")))),
            address(uint160(uint256(keccak256("DEPOSIT_QUEUE")))),
            address(uint160(uint256(keccak256("REDEEM_QUEUE")))),
            address(uint160(uint256(keccak256("ORACLE")))),
            address(uint160(uint256(keccak256("FEE_MANAGER")))),
            address(uint160(uint256(keccak256("RISK_MANAGER")))),
            address(uint160(uint256(keccak256("FUND_MANAGER")))),
            address(this),
            roleHolders
        );

        strategy = new MockStrategy(address(fund));
    }

    function test_removeStrategy_removesAddedStrategy() public {
        fund.addStrategy(address(strategy));
        assertTrue(fund.isStrategy(address(strategy)));

        vm.expectEmit(address(fund));
        emit IStrategyModule.StrategyRemoved(address(strategy));
        fund.removeStrategy(address(strategy));

        assertFalse(fund.isStrategy(address(strategy)));
    }

    function test_removeStrategy_revertsWhenNeverAdded() public {
        vm.expectRevert(IStrategyModule.InvalidStrategy.selector);
        fund.removeStrategy(address(strategy));
    }

    function test_removeStrategy_revertsWhenAlreadyRemoved() public {
        fund.addStrategy(address(strategy));
        fund.removeStrategy(address(strategy));

        vm.expectRevert(IStrategyModule.InvalidStrategy.selector);
        fund.removeStrategy(address(strategy));
    }
}
