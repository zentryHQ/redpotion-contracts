// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../modules/StrategyACLModule.sol";
import "./ICallValidator.sol";

interface IStrategy is ICallValidator {
    // Events

    event CallExecuted(
        address indexed caller,
        address indexed target,
        bytes4 indexed selector,
        bytes data,
        bytes result
    );
    event AssetPulled(address indexed asset, uint256 amount);
    event FundUpdated(address indexed fund);
    event StrategyCreated(address indexed fund);

    // Errors

    error CallFailed();
    error TargetNotAllowed();
    error OnlyFund();

    // View functions

    function fund() external view returns (address);

    // Mutable functions

    function initialize(
        address fund_,
        address admin_,
        StrategyACLModule.RoleHolder[] memory roleHolders_
    ) external;

    function call(
        address target,
        bytes calldata data
    ) external payable returns (bytes memory);

    function call(
        address target,
        bytes calldata data,
        uint256[] calldata constrainedOffsets,
        bytes32[] calldata constrainedValues
    ) external payable returns (bytes memory);

    function pullAsset(address asset, uint256 amount) external;
}
