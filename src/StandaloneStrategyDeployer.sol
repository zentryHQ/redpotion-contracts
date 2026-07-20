// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./modules/ACLModule.sol";
import "./interfaces/IStandaloneStrategyDeployer.sol";
import "./interfaces/IFactory.sol";
import "./interfaces/IStandaloneStrategy.sol";
import "./modules/StrategyACLModule.sol";

contract StandaloneStrategyDeployer is IStandaloneStrategyDeployer, ACLModule {
    bytes32 public constant CREATE_STRATEGY_ROLE = keccak256("CREATE_STRATEGY_ROLE");
    bytes32 public constant SET_IMPLEMENTATIONS_ROLE = keccak256("SET_IMPLEMENTATIONS_ROLE");

    IFactory public standaloneStrategyFactory;

    address public factoryImplementation;
    address public standaloneStrategyImplementation;

    address public proxyAdmin;

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address admin_,
        address proxyAdmin_,
        address standaloneStrategyFactory_,
        RoleHolder[] memory roleHolders_
    ) external initializer {
        if (admin_ == address(0)) revert ZeroAddress();
        if (proxyAdmin_ == address(0)) revert ZeroAddress();
        if (standaloneStrategyFactory_ == address(0)) revert ZeroAddress();

        __ACLModule_init(admin_, roleHolders_);

        proxyAdmin = proxyAdmin_;
        standaloneStrategyFactory = IFactory(standaloneStrategyFactory_);
    }

    // ========================================
    // View functions
    // ========================================

    function strategyCount() external view returns (uint256) {
        return standaloneStrategyFactory.entityCount();
    }

    function strategyAt(uint256 index) external view returns (address) {
        return standaloneStrategyFactory.entityAt(index);
    }

    function isStrategy(address entity) external view returns (bool) {
        return standaloneStrategyFactory.isEntity(entity);
    }

    // ========================================
    // Mutable functions
    // ========================================

    function setImplementations(
        address factoryImplementation_,
        address standaloneStrategyImplementation_
    ) external onlyRole(SET_IMPLEMENTATIONS_ROLE) {
        if (factoryImplementation_ == address(0)) revert ZeroAddress();
        if (standaloneStrategyImplementation_ == address(0)) revert ZeroAddress();

        factoryImplementation = factoryImplementation_;
        standaloneStrategyImplementation = standaloneStrategyImplementation_;

        standaloneStrategyFactory.setImplementation(standaloneStrategyImplementation_);

        emit ImplementationsSet(factoryImplementation_, standaloneStrategyImplementation_);
    }

    function createStandaloneStrategy(
        address fund_,
        address admin_,
        ACLModule.RoleHolder[] memory roleHolders_
    ) external onlyRole(CREATE_STRATEGY_ROLE) returns (address strategy) {
        if (admin_ == address(0)) revert ZeroAddress();

        strategy = standaloneStrategyFactory.create(
            abi.encodeCall(
                IStandaloneStrategy.initialize,
                (fund_, admin_, roleHolders_)
            )
        );

        emit StandaloneStrategyCreated(strategy, fund_, admin_);
    }
}
