// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../modules/ACLModule.sol";
import "./IFactory.sol";

interface IStandaloneStrategyDeployer {

    event StandaloneStrategyCreated(
        address indexed strategy,
        address indexed fund,
        address indexed admin,
        address proxyAdmin
    );

    event StrategyImplementationSet(address strategyImplementation);

    error ZeroAddress();

    function standaloneStrategyFactory() external view returns (IFactory);

    function strategyCount() external view returns (uint256);

    function strategyAt(uint256 index) external view returns (address);

    function isStrategy(address entity) external view returns (bool);

    function setStrategyImplementation(address strategyImplementation_) external;

    function createStandaloneStrategy(
        address fund_,
        address admin_,
        address proxyAdmin_,
        ACLModule.RoleHolder[] memory roleHolders_
    ) external returns (address strategy);
}
