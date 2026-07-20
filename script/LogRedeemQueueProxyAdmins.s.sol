// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import "../src/FundManager.sol";
import "../src/FundManagerDeployer.sol";
import "../src/interfaces/IFactory.sol";
import "../src/interfaces/IFund.sol";

/// @dev Read-only walk of every fund in every fund manager, logging each fund's
///   redeem queue proxy together with its ProxyAdmin (and the ProxyAdmin owner —
///   the wallet authorized to call upgradeAndCall).
///
///   NETWORK=base-sepolia forge script script/LogRedeemQueueProxyAdmins.s.sol --rpc-url $RPC_URL
contract LogRedeemQueueProxyAdmins is Script {
    /// @dev The ProxyAdmin is the first contract deployed inside a
    ///   TransparentUpgradeableProxy constructor (CREATE, nonce = 1).
    function _proxyAdmin(address proxy) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xd6), bytes1(0x94), proxy, bytes1(0x01)
        )))));
    }

    /// @dev The ERC-1967 implementation slot:
    ///   bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1).
    bytes32 internal constant _IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    function _implementation(address proxy) internal view returns (address) {
        return address(uint160(uint256(vm.load(proxy, _IMPLEMENTATION_SLOT))));
    }

    function run() external view {
        string memory network        = vm.envString("NETWORK");
        string memory deploymentPath = string.concat("deployments/", network, ".json");
        string memory deploymentJson = vm.readFile(deploymentPath);

        address fundManagerDeployerProxy =
            vm.parseJsonAddress(deploymentJson, ".fundManagerDeployer");

        FundManagerDeployer fundManagerDeployer =
            FundManagerDeployer(fundManagerDeployerProxy);
        uint256 fundManagerCount = fundManagerDeployer.fundManagerCount();

        console.log("=== Redeem queue ProxyAdmins ===");
        console.log("FundManagerDeployer:", fundManagerDeployerProxy);
        console.log("Total FundManagers: ", fundManagerCount);

        for (uint256 fmIndex = 0; fmIndex < fundManagerCount; fmIndex++) {
            address fundManagerProxy = fundManagerDeployer.fundManagerAt(fmIndex);
            console.log("\n=== FundManager %d ===", fmIndex);
            console.log("FundManager:", fundManagerProxy);

            IFactory redeemQueueFactory = FundManager(fundManagerProxy).redeemQueueFactory();
            console.log("RedeemQueue impl (factory):", redeemQueueFactory.implementation());

            IFactory fundFactory = FundManager(fundManagerProxy).fundFactory();
            uint256 fundCount = fundFactory.entityCount();
            console.log("Funds:", fundCount);

            for (uint256 fundIndex = 0; fundIndex < fundCount; fundIndex++) {
                address fund = fundFactory.entityAt(fundIndex);
                address redeemQueue = IFund(fund).redeemQueue();
                address proxyAdmin = _proxyAdmin(redeemQueue);

                console.log("\n  -- Fund %d --", fundIndex);
                console.log("  fund:        ", fund);
                console.log("  redeemQueue: ", redeemQueue);
                console.log("  impl:        ", _implementation(redeemQueue));
                console.log("  ProxyAdmin:  ", proxyAdmin);
                console.log("  Can upgrade: ", ProxyAdmin(proxyAdmin).owner());
            }
        }
    }
}
