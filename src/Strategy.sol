// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./modules/StrategyACLModule.sol";
import "./modules/CallValidatorModule.sol";
import "./libraries/TransferHelper.sol";
import "./interfaces/IStrategy.sol";

contract Strategy is
    IStrategy,
    ContextUpgradeable,
    StrategyACLModule,
    CallValidatorModule,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    /// @custom:storage-location erc7201:neobank.storage.Strategy
    struct StrategyStorage {
        address fund;
    }

    function _strategyStorage() private pure returns (StrategyStorage storage $) {
        bytes32 slot = _erc7201Slot("erc7201:neobank.storage.Strategy");
        assembly {
            $.slot := slot
        }
    }

    function fund() public view returns (address) {
        return _strategyStorage().fund;
    }

    modifier onlyFund() {
        if (_msgSender() != _strategyStorage().fund) revert OnlyFund();
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address fund_,
        address admin_,
        StrategyACLModule.RoleHolder[] memory roleHolders_
    ) external initializer {
        if (admin_ == address(0)) revert ZeroAddress();

        __Context_init();
        __StrategyACLModule_init(admin_, roleHolders_);
        __ReentrancyGuard_init();
        _setFund(fund_);

        emit StrategyCreated(fund_);
    }

    function call(
        address target,
        bytes calldata data
    ) external payable onlyRole(CALLER_ROLE) nonReentrant returns (bytes memory) {
        if (target == _strategyStorage().fund) revert TargetNotAllowed();
        if (data.length < 4) revert CallNotAllowed();
        bytes4 selector = bytes4(data[:4]);

        if (!_isCallPermitted(_msgSender(), target, selector))
            revert CallNotAllowed();

        (bool success, bytes memory result) = target.call{value: msg.value}(data);
        if (!success) revert CallFailed();

        emit CallExecuted(_msgSender(), target, selector, data, result);
        return result;
    }

    function call(
        address target,
        bytes calldata data,
        uint256[] calldata constrainedOffsets,
        bytes32[] calldata constrainedValues
    ) external payable onlyRole(CALLER_ROLE) nonReentrant returns (bytes memory) {
        if (target == _strategyStorage().fund) revert TargetNotAllowed();
        if (data.length < 4) revert CallNotAllowed();
        bytes4 selector = bytes4(data[:4]);

        if (!_isCallPermitted(
            _msgSender(), target, selector, constrainedOffsets, constrainedValues, data
        )) revert CallNotAllowed();

        (bool success, bytes memory result) = target.call{value: msg.value}(data);
        if (!success) revert CallFailed();

        emit CallExecuted(_msgSender(), target, selector, data, result);
        return result;
    }

    receive() external payable {}

    function pullAsset(address asset, uint256 amount) external onlyFund {
        address fund_ = _strategyStorage().fund;
        TransferHelper.transfer(asset, fund_, amount);
        emit AssetPulled(asset, amount);
    }

    function _setFund(address fund_) internal {
        if (fund_ == address(0)) revert ZeroAddress();
        _strategyStorage().fund = fund_;
        emit FundUpdated(fund_);
    }
}
