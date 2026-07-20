// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import "../src/FundManager.sol";
import "../src/FundManagerDeployer.sol";
import "../src/interfaces/IFactory.sol";
import "../src/interfaces/IFund.sol";

/// @dev Read-only walk of every proxy in the system, logging its ProxyAdmin owner.
///   NETWORK=base-sepolia forge script script/LogProxyOwners.s.sol --rpc-url $RPC_URL
contract LogProxyOwners is Script {
    function _proxyAdmin(address proxy) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xd6), bytes1(0x94), proxy, bytes1(0x01)
        )))));
    }

    function _logOwner(string memory label, address proxy) internal view {
        address admin = _proxyAdmin(proxy);
        address owner = ProxyAdmin(admin).owner();
        console.log(label, proxy);
        console.log("    ProxyAdmin:", admin);
        console.log("    Owner:     ", owner);
    }

    function run() external view {
        string memory network        = vm.envString("NETWORK");
        string memory deploymentPath = string.concat("deployments/", network, ".json");
        string memory deploymentJson = vm.readFile(deploymentPath);

        address fundManagerDeployerProxy = vm.parseJsonAddress(deploymentJson, ".fundManagerDeployer");
        address fundManagerFactoryProxy  = vm.parseJsonAddress(deploymentJson, ".fundManagerFactory");

        console.log("=== Top-level proxies ===\n");
        _logOwner("FundManagerDeployer:", fundManagerDeployerProxy);
        _logOwner("FundManagerFactory: ", fundManagerFactoryProxy);

        FundManagerDeployer fundManagerDeployer = FundManagerDeployer(fundManagerDeployerProxy);
        uint256 fundManagerCount = fundManagerDeployer.fundManagerCount();
        console.log("\nTotal FundManagers:", fundManagerCount);

        for (uint256 fmIndex = 0; fmIndex < fundManagerCount; fmIndex++) {
            address fundManagerProxy = fundManagerDeployer.fundManagerAt(fmIndex);
            console.log("\n=== FundManager %d ===", fmIndex);
            _logOwner("FundManager:", fundManagerProxy);

            _logFactories(fundManagerProxy);
            _logStrategies(fundManagerProxy);
            _logFunds(fundManagerProxy);
        }
    }

    function _logFactories(address fundManagerProxy) internal view {
        FundManager fundManager = FundManager(fundManagerProxy);

        console.log("\n  -- Factories --");
        _logOwner("  fundFactory:        ", address(fundManager.fundFactory()));
        _logOwner("  shareFactory:       ", address(fundManager.shareFactory()));
        _logOwner("  depositQueueFactory:", address(fundManager.depositQueueFactory()));
        _logOwner("  redeemQueueFactory: ", address(fundManager.redeemQueueFactory()));
        _logOwner("  oracleFactory:      ", address(fundManager.oracleFactory()));
        _logOwner("  feeManagerFactory:  ", address(fundManager.feeManagerFactory()));
        _logOwner("  riskManagerFactory: ", address(fundManager.riskManagerFactory()));
        _logOwner("  strategyFactory:    ", address(fundManager.strategyFactory()));
    }

    function _logStrategies(address fundManagerProxy) internal view {
        IFactory strategyFactory = FundManager(fundManagerProxy).strategyFactory();
        uint256 strategyCount = strategyFactory.entityCount();
        console.log("\n  -- Strategies --");
        console.log("  Total:", strategyCount);
        for (uint256 strategyIndex = 0; strategyIndex < strategyCount; strategyIndex++) {
            address strategy = strategyFactory.entityAt(strategyIndex);
            _logOwner(string.concat("  [strategy ", vm.toString(strategyIndex), "]:"), strategy);
        }
    }

    function _logFunds(address fundManagerProxy) internal view {
        FundManager fundManager = FundManager(fundManagerProxy);
        IFactory fundFactory        = fundManager.fundFactory();
        IFactory riskManagerFactory = fundManager.riskManagerFactory();
        uint256 fundCount = fundFactory.entityCount();
        console.log("\n  -- Funds --");
        console.log("  Total:", fundCount);

        for (uint256 fundIndex = 0; fundIndex < fundCount; fundIndex++) {
            address fund = fundFactory.entityAt(fundIndex);
            console.log("\n  === Fund %d ===", fundIndex);
            _logOwner("  fund:       ", fund);
            _logOwner("  share:      ", IFund(fund).share());
            _logOwner("  depositQueue:", IFund(fund).depositQueue());
            _logOwner("  redeemQueue:", IFund(fund).redeemQueue());
            _logOwner("  oracle:     ", IFund(fund).oracle());
            _logOwner("  feeManager: ", IFund(fund).feeManager());
            // riskManager has no Fund getter — matched by creation index
            _logOwner("  riskManager:", riskManagerFactory.entityAt(fundIndex));
        }
    }
}
