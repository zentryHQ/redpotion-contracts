// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "./interfaces/IFactory.sol";

contract Factory is IFactory, OwnableUpgradeable {
    address public implementation;
    uint256 public version;

    address[] private _entities;
    mapping(address => bool) public isEntity;

    constructor() {
        _disableInitializers();
    }

    function initialize(address owner_) external initializer {
        __Ownable_init(owner_);
    }

    // View functions

    function entityCount() external view returns (uint256) {
        return _entities.length;
    }

    function entityAt(uint256 index) external view returns (address) {
        return _entities[index];
    }

    // Mutable functions

    /// @inheritdoc IFactory
    function setImplementation(
        address implementation_
    ) external onlyOwner {
        if (implementation_ == address(0)) revert ZeroAddress();

        implementation = implementation_;
        version++;

        emit ImplementationSet(implementation_, version);
    }

    /// @inheritdoc IFactory
    function create(
        bytes calldata initData
    ) external onlyOwner returns (address entity) {
        if (implementation == address(0)) revert NoImplementation();

        entity = address(
            new TransparentUpgradeableProxy(
                implementation,
                owner(),
                initData
            )
        );

        _entities.push(entity);
        isEntity[entity] = true;

        emit EntityCreated(entity, version);
    }

    /// @inheritdoc IFactory
    function createFor(
        bytes calldata initData,
        address proxyAdminOwner
    ) external onlyOwner returns (address entity) {
        if (implementation == address(0)) revert NoImplementation();
        if (proxyAdminOwner == address(0)) revert ZeroAddress();

        entity = address(
            new TransparentUpgradeableProxy(
                implementation,
                proxyAdminOwner,
                initData
            )
        );

        _entities.push(entity);
        isEntity[entity] = true;

        emit EntityCreated(entity, version);
    }
}
