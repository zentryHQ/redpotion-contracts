// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Script.sol";

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "../src/Factory.sol";
import "../src/FundManager.sol";
import "../src/interfaces/IFactory.sol";
import "../src/FundManagerDeployer.sol";
import "../src/Fund.sol";
import "../src/FundShare.sol";
import "../src/DepositQueue.sol";
import "../src/RedeemQueue.sol";
import "../src/Oracle.sol";
import "../src/FeeManager.sol";
import "../src/RiskManager.sol";
import "../src/Strategy.sol";

contract DeployInfra is Script {
    function run() external {
        address deployer = msg.sender;
        string memory network = vm.envString("NETWORK");

        vm.startBroadcast();

        // ── 1. Deploy implementation contracts ──────────────────────────

        Factory factoryImpl = new Factory();
        FundManager fundManagerImpl = new FundManager();
        Fund fundImpl = new Fund();
        FundShare shareImpl = new FundShare();
        DepositQueue depositQueueImpl = new DepositQueue();
        RedeemQueue redeemQueueImpl = new RedeemQueue();
        Oracle oracleImpl = new Oracle();
        FeeManager feeManagerImpl = new FeeManager();
        RiskManager riskManagerImpl = new RiskManager();
        Strategy strategyImpl = new Strategy();

        // ── 2. Deploy FundManagerDeployer behind a proxy ────────────────

        FundManagerDeployer fundManagerDeployerImpl = new FundManagerDeployer();

        ACLModule.RoleHolder[] memory roleHolders = new ACLModule.RoleHolder[](3);
        roleHolders[0] = ACLModule.RoleHolder({
            role: fundManagerDeployerImpl.CREATE_FUND_MANAGER_ROLE(),
            account: deployer
        });
        roleHolders[1] = ACLModule.RoleHolder({
            role: fundManagerDeployerImpl.SET_IMPLEMENTATIONS_ROLE(),
            account: deployer
        });
        roleHolders[2] = ACLModule.RoleHolder({
            role: fundManagerDeployerImpl.SET_PROTOCOL_FEE_RECIPIENT_ROLE(),
            account: deployer
        });
        // Deploy fundManagerFactory proxy
        TransparentUpgradeableProxy fundManagerFactoryProxy = new TransparentUpgradeableProxy(
            address(factoryImpl),
            deployer,
            abi.encodeCall(IFactory.initialize, (deployer))
        );

        TransparentUpgradeableProxy fundManagerDeployerProxy = new TransparentUpgradeableProxy(
            address(fundManagerDeployerImpl),
            deployer,
            abi.encodeCall(
                FundManagerDeployer.initialize,
                (deployer, deployer, address(fundManagerFactoryProxy), deployer, roleHolders)
            )
        );

        FundManagerDeployer fundManagerDeployer = FundManagerDeployer(address(fundManagerDeployerProxy));

        // Transfer fundManagerFactory ownership to the deployer contract
        OwnableUpgradeable(address(fundManagerFactoryProxy)).transferOwnership(address(fundManagerDeployer));

        // ── 3. Set implementations on FundManagerDeployer ───────────────

        fundManagerDeployer.setImplementations(
            address(factoryImpl),
            address(fundManagerImpl),
            address(fundImpl),
            address(shareImpl),
            address(depositQueueImpl),
            address(redeemQueueImpl),
            address(oracleImpl),
            address(feeManagerImpl),
            address(riskManagerImpl),
            address(strategyImpl)
        );

        vm.stopBroadcast();

        // ── 4. Write deployment addresses to JSON ───────────────────────

        string memory json = "deployment";
        vm.serializeAddress(json, "factoryImpl", address(factoryImpl));
        vm.serializeAddress(json, "fundManagerImpl", address(fundManagerImpl));
        vm.serializeAddress(json, "fundImpl", address(fundImpl));
        vm.serializeAddress(json, "shareImpl", address(shareImpl));
        vm.serializeAddress(json, "depositQueueImpl", address(depositQueueImpl));
        vm.serializeAddress(json, "redeemQueueImpl", address(redeemQueueImpl));
        vm.serializeAddress(json, "oracleImpl", address(oracleImpl));
        vm.serializeAddress(json, "feeManagerImpl", address(feeManagerImpl));
        vm.serializeAddress(json, "riskManagerImpl", address(riskManagerImpl));
        vm.serializeAddress(json, "strategyImpl", address(strategyImpl));
        vm.serializeAddress(json, "fundManagerFactory", address(fundManagerFactoryProxy));
        vm.serializeAddress(json, "fundManagerDeployerImpl", address(fundManagerDeployerImpl));
        string memory output = vm.serializeAddress(json, "fundManagerDeployer", address(fundManagerDeployer));

        string memory path = string.concat("deployments/", network, ".json");
        vm.writeJson(output, path);
    }
}
