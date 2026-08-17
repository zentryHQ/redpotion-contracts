// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./ModuleBase.sol";
import "../libraries/TransferHelper.sol";
import "../interfaces/IStrategyModule.sol";
import "../interfaces/IStrategy.sol";
import "../interfaces/IFundManager.sol";

abstract contract StrategyModule is IStrategyModule, ModuleBase {
    /// @custom:storage-location erc7201:neobank.storage.StrategyModule
    struct StrategyStorage {
        address fundManager;
        mapping(address => bool) isStrategy;
    }

    function _strategyStorage() private pure returns (StrategyStorage storage $) {
        bytes32 slot = _erc7201Slot("erc7201:neobank.storage.StrategyModule");
        assembly {
            $.slot := slot
        }
    }

    function __StrategyModule_init(address fundManager_) internal onlyInitializing {
        _strategyStorage().fundManager = fundManager_;
    }

    /// @inheritdoc IStrategyModule
    function fundManager() public view returns (address) {
        return _strategyStorage().fundManager;
    }

    /// @inheritdoc IStrategyModule
    function isStrategy(address strategy) public view returns (bool) {
        return _strategyStorage().isStrategy[strategy];
    }

    /// @inheritdoc IStrategyModule
    function createStrategy(
        address admin_,
        ACLModule.RoleHolder[] memory roleHolders_
    ) external onlyRole(CREATE_STRATEGY_ROLE) nonReentrant returns (address strategy) {
        StrategyStorage storage $ = _strategyStorage();
        strategy = IFundManager($.fundManager).createStrategyForFund(
            address(this),
            admin_,
            roleHolders_
        );
        $.isStrategy[strategy] = true;
        emit StrategyAdded(strategy);
    }

    /// @inheritdoc IStrategyModule
    function addStrategy(
        address strategy
    ) external onlyRole(ADD_STRATEGY_ROLE) {
        if (IStrategy(strategy).fund() != address(this)) revert InvalidStrategy();
        _strategyStorage().isStrategy[strategy] = true;
        emit StrategyAdded(strategy);
    }

    /// @inheritdoc IStrategyModule
    function removeStrategy(
        address strategy
    ) external onlyRole(REMOVE_STRATEGY_ROLE) {
        _strategyStorage().isStrategy[strategy] = false;
        emit StrategyRemoved(strategy);
    }

    /// @inheritdoc IStrategyModule
    function pushAssetToStrategy(
        address strategy,
        address asset,
        uint256 amount
    ) external onlyRole(PUSH_TO_STRATEGY_ROLE) nonReentrant {
        if (!_strategyStorage().isStrategy[strategy]) revert InvalidStrategy();
        TransferHelper.transfer(asset, strategy, amount);
        emit AssetPushedToStrategy(strategy, asset, amount);
    }

    /// @inheritdoc IStrategyModule
    function pullAssetFromStrategy(
        address strategy,
        address asset,
        uint256 amount
    ) external onlyRole(PULL_FROM_STRATEGY_ROLE) nonReentrant {
        if (!_strategyStorage().isStrategy[strategy]) revert InvalidStrategy();
        IStrategy(strategy).pullAsset(asset, amount);
        emit AssetPulledFromStrategy(strategy, asset, amount);
    }
}
