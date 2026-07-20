// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../modules/ACLModule.sol";
import "./IFactory.sol";

interface IStandaloneStrategyDeployer {
    // Events

    event StandaloneStrategyCreated(
        address indexed strategy,
        address indexed fund,
        address indexed admin
    );

    event ImplementationsSet(
        address factoryImplementation,
        address standaloneStrategyImplementation
    );

    // Errors

    error ZeroAddress();

    // View functions

    function proxyAdmin() external view returns (address);

    function standaloneStrategyFactory() external view returns (IFactory);

    function factoryImplementation() external view returns (address);

    function standaloneStrategyImplementation() external view returns (address);

    function strategyCount() external view returns (uint256);

    function strategyAt(uint256 index) external view returns (address);

    function isStrategy(address entity) external view returns (bool);

    // Mutable functions

    function setImplementations(
        address factoryImplementation_,
        address standaloneStrategyImplementation_
    ) external;

    function createStandaloneStrategy(
        address fund_,
        address admin_,
        ACLModule.RoleHolder[] memory roleHolders_
    ) external returns (address strategy);
}
