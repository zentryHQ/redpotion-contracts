// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

import {Factory} from "../src/Factory.sol";
import {IFactory} from "../src/interfaces/IFactory.sol";
import {StandaloneStrategy} from "../src/StandaloneStrategy.sol";
import {StandaloneStrategyDeployer} from "../src/StandaloneStrategyDeployer.sol";
import {IStandaloneStrategyDeployer} from "../src/interfaces/IStandaloneStrategyDeployer.sol";
import {ACLModule} from "../src/modules/ACLModule.sol";

contract StandaloneStrategyDeployerTest is Test {
    StandaloneStrategyDeployer internal deployer;
    Factory internal factory;

    address internal constant FUND = address(uint160(uint256(keccak256("FUND"))));
    address internal constant STRATEGY_ADMIN = address(uint160(uint256(keccak256("STRATEGY_ADMIN"))));
    address internal constant PROXY_ADMIN_OWNER = address(uint160(uint256(keccak256("PROXY_ADMIN_OWNER"))));
    address internal constant CALLER = address(uint160(uint256(keccak256("CALLER"))));
    address internal constant STRANGER = address(uint160(uint256(keccak256("STRANGER"))));

    ACLModule.RoleHolder[] internal emptyRoleHolders;

    function setUp() public {
        Factory factoryImplementation = new Factory();
        ERC1967Proxy factoryProxy = new ERC1967Proxy(address(factoryImplementation), bytes(""));
        factory = Factory(address(factoryProxy));

        StandaloneStrategyDeployer deployerImplementation = new StandaloneStrategyDeployer();
        ACLModule.RoleHolder[] memory deployerRoleHolders = new ACLModule.RoleHolder[](2);
        deployerRoleHolders[0] = ACLModule.RoleHolder({
            role: deployerImplementation.CREATE_STRATEGY_ROLE(),
            account: address(this)
        });
        deployerRoleHolders[1] = ACLModule.RoleHolder({
            role: deployerImplementation.SET_IMPLEMENTATION_ROLE(),
            account: address(this)
        });
        ERC1967Proxy deployerProxy = new ERC1967Proxy(
            address(deployerImplementation),
            abi.encodeCall(
                StandaloneStrategyDeployer.initialize,
                (address(this), address(factory), deployerRoleHolders)
            )
        );
        deployer = StandaloneStrategyDeployer(address(deployerProxy));

        factory.initialize(address(deployer));
        deployer.setStrategyImplementation(address(new StandaloneStrategy()));
    }

    function _createStrategy() internal returns (StandaloneStrategy strategy) {
        ACLModule.RoleHolder[] memory strategyRoleHolders = new ACLModule.RoleHolder[](1);
        strategyRoleHolders[0] = ACLModule.RoleHolder({
            role: keccak256("CALLER_ROLE"),
            account: CALLER
        });
        strategy = StandaloneStrategy(payable(
            deployer.createStandaloneStrategy(FUND, STRATEGY_ADMIN, PROXY_ADMIN_OWNER, strategyRoleHolders)
        ));
    }

    function _loadProxyAdmin(address proxy) internal view returns (ProxyAdmin) {
        return ProxyAdmin(address(uint160(uint256(vm.load(proxy, ERC1967Utils.ADMIN_SLOT)))));
    }

    function test_createStandaloneStrategy_proxyAdminOwnedByPassedAddress() public {
        StandaloneStrategy strategy = _createStrategy();

        ProxyAdmin strategyProxyAdmin = _loadProxyAdmin(address(strategy));
        assertEq(strategyProxyAdmin.owner(), PROXY_ADMIN_OWNER);
    }

    function test_createStandaloneStrategy_upgradeableByProxyAdminOwner() public {
        StandaloneStrategy strategy = _createStrategy();
        address newImplementation = address(new StandaloneStrategy());

        vm.prank(PROXY_ADMIN_OWNER);
        _loadProxyAdmin(address(strategy)).upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(strategy))),
            newImplementation,
            bytes("")
        );

        bytes32 implementationSlot = vm.load(address(strategy), ERC1967Utils.IMPLEMENTATION_SLOT);
        assertEq(address(uint160(uint256(implementationSlot))), newImplementation);
    }

    function test_createStandaloneStrategy_initializesStrategy() public {
        StandaloneStrategy strategy = _createStrategy();

        assertEq(strategy.fund(), FUND);
        assertTrue(strategy.hasRole(strategy.DEFAULT_ADMIN_ROLE(), STRATEGY_ADMIN));
        assertTrue(strategy.hasRole(strategy.CALLER_ROLE(), CALLER));
    }

    function test_createStandaloneStrategy_registersEntity() public {
        StandaloneStrategy strategy = _createStrategy();

        assertTrue(deployer.isStrategy(address(strategy)));
        assertEq(deployer.strategyCount(), 1);
        assertEq(deployer.strategyAt(0), address(strategy));
    }

    function test_createStandaloneStrategy_revertsWithoutRole() public {
        bytes32 createStrategyRole = deployer.CREATE_STRATEGY_ROLE();

        vm.prank(STRANGER);
        vm.expectRevert(abi.encodeWithSelector(
            IAccessControl.AccessControlUnauthorizedAccount.selector,
            STRANGER,
            createStrategyRole
        ));
        deployer.createStandaloneStrategy(FUND, STRATEGY_ADMIN, PROXY_ADMIN_OWNER, emptyRoleHolders);
    }

    function test_createStandaloneStrategy_revertsOnZeroAdmin() public {
        vm.expectRevert(IStandaloneStrategyDeployer.ZeroAddress.selector);
        deployer.createStandaloneStrategy(FUND, address(0), PROXY_ADMIN_OWNER, emptyRoleHolders);
    }

    function test_createStandaloneStrategy_revertsOnZeroProxyAdmin() public {
        vm.expectRevert(IFactory.ZeroAddress.selector);
        deployer.createStandaloneStrategy(FUND, STRATEGY_ADMIN, address(0), emptyRoleHolders);
    }

    function test_setStrategyImplementation_updatesFactory() public {
        address newImplementation = address(new StandaloneStrategy());

        deployer.setStrategyImplementation(newImplementation);

        assertEq(factory.implementation(), newImplementation);
    }

    function test_setStrategyImplementation_revertsWithoutRole() public {
        bytes32 setImplementationRole = deployer.SET_IMPLEMENTATION_ROLE();

        vm.prank(STRANGER);
        vm.expectRevert(abi.encodeWithSelector(
            IAccessControl.AccessControlUnauthorizedAccount.selector,
            STRANGER,
            setImplementationRole
        ));
        deployer.setStrategyImplementation(address(0xBEEF));
    }
}
