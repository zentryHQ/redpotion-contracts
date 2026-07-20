// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Script.sol";

import "../src/FundManager.sol";
import "../src/FundManagerDeployer.sol";
import "../src/interfaces/IFactory.sol";
import "../src/interfaces/IFund.sol";

/// @dev Read-only walk of every proxy in the system, logging its ERC-1967 implementation.
///   NETWORK=base-sepolia forge script script/LogImplementations.s.sol --rpc-url $RPC_URL
contract LogImplementations is Script {
    // bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
    // Matches OZ ERC1967Utils.IMPLEMENTATION_SLOT.
    bytes32 internal constant IMPL_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    function _implementation(address proxy) internal view returns (address) {
        return address(uint160(uint256(vm.load(proxy, IMPL_SLOT))));
    }

    function _logImpl(string memory label, address proxy) internal view {
        console.log(label, proxy);
        console.log("    Impl:", _implementation(proxy));
    }

    function _logFactory(string memory label, IFactory factory) internal view {
        address factoryAddress = address(factory);
        console.log(label, factoryAddress);
        console.log("    Impl:           ", _implementation(factoryAddress));
        console.log("    Current Impl:   ", factory.implementation());
        console.log("    Current Version:", factory.version());
    }

    function run() external view {
        string memory network        = vm.envString("NETWORK");
        string memory deploymentPath = string.concat("deployments/", network, ".json");
        string memory deploymentJson = vm.readFile(deploymentPath);

        address fundManagerDeployerProxy = vm.parseJsonAddress(deploymentJson, ".fundManagerDeployer");
        address fundManagerFactoryProxy  = vm.parseJsonAddress(deploymentJson, ".fundManagerFactory");

        console.log("=== Top-level proxies ===\n");
        _logImpl("FundManagerDeployer:", fundManagerDeployerProxy);
        _logImpl("FundManagerFactory: ", fundManagerFactoryProxy);

        FundManagerDeployer fundManagerDeployer = FundManagerDeployer(fundManagerDeployerProxy);
        uint256 fundManagerCount = fundManagerDeployer.fundManagerCount();
        console.log("\nTotal FundManagers:", fundManagerCount);

        for (uint256 fmIndex = 0; fmIndex < fundManagerCount; fmIndex++) {
            address fundManagerProxy = fundManagerDeployer.fundManagerAt(fmIndex);
            console.log("\n=== FundManager %d ===", fmIndex);
            _logImpl("FundManager:", fundManagerProxy);

            _logFactories(fundManagerProxy);
            _logStrategies(fundManagerProxy);
            _logFunds(fundManagerProxy);
        }
    }

    function _logFactories(address fundManagerProxy) internal view {
        FundManager fundManager = FundManager(fundManagerProxy);

        console.log("\n  -- Factories --");
        _logFactory("  fundFactory:        ", fundManager.fundFactory());
        _logFactory("  shareFactory:       ", fundManager.shareFactory());
        _logFactory("  depositQueueFactory:", fundManager.depositQueueFactory());
        _logFactory("  redeemQueueFactory: ", fundManager.redeemQueueFactory());
        _logFactory("  oracleFactory:      ", fundManager.oracleFactory());
        _logFactory("  feeManagerFactory:  ", fundManager.feeManagerFactory());
        _logFactory("  riskManagerFactory: ", fundManager.riskManagerFactory());
        _logFactory("  strategyFactory:    ", fundManager.strategyFactory());
    }

    function _logStrategies(address fundManagerProxy) internal view {
        IFactory strategyFactory = FundManager(fundManagerProxy).strategyFactory();
        uint256 strategyCount = strategyFactory.entityCount();
        console.log("\n  -- Strategies --");
        console.log("  Total:", strategyCount);
        for (uint256 strategyIndex = 0; strategyIndex < strategyCount; strategyIndex++) {
            address strategy = strategyFactory.entityAt(strategyIndex);
            _logImpl(string.concat("  [strategy ", vm.toString(strategyIndex), "]:"), strategy);
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
            _logImpl("  fund:       ", fund);
            _logImpl("  share:      ", IFund(fund).share());
            _logImpl("  depositQueue:", IFund(fund).depositQueue());
            _logImpl("  redeemQueue:", IFund(fund).redeemQueue());
            _logImpl("  oracle:     ", IFund(fund).oracle());
            _logImpl("  feeManager: ", IFund(fund).feeManager());
            _logImpl("  riskManager:", riskManagerFactory.entityAt(fundIndex));
        }
    }
}
