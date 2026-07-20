// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../modules/ACLModule.sol";

interface IStrategyModule {
    // Events
    event StrategyAdded(address indexed strategy);
    event StrategyRemoved(address indexed strategy);
    event AssetPushedToStrategy(address indexed strategy, address indexed asset, uint256 amount);
    event AssetPulledFromStrategy(address indexed strategy, address indexed asset, uint256 amount);

    // Errors
    error InvalidStrategy();

    // Views
    function fundManager() external view returns (address);
    function isStrategy(address strategy) external view returns (bool);

    // Mutable
    function createStrategy(
        address admin_,
        ACLModule.RoleHolder[] memory roleHolders_
    ) external returns (address strategy);
    function addStrategy(address strategy) external;
    function removeStrategy(address strategy) external;
    function pushAssetToStrategy(address strategy, address asset, uint256 amount) external;
    function pullAssetFromStrategy(address strategy, address asset, uint256 amount) external;
}
