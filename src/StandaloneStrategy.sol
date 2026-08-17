// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "./modules/StrategyACLModule.sol";
import "./modules/CallValidatorModule.sol";
import "./libraries/TransferHelper.sol";
import "./interfaces/IStandaloneStrategy.sol";

contract StandaloneStrategy is
    IStandaloneStrategy,
    ContextUpgradeable,
    StrategyACLModule,
    CallValidatorModule,
    ReentrancyGuardUpgradeable
{
    /// @custom:storage-location erc7201:neobank.storage.StandaloneStrategy
    struct StandaloneStrategyStorage {
        address fund;
    }

    function _standaloneStrategyStorage() private pure returns (StandaloneStrategyStorage storage $) {
        bytes32 slot = _erc7201Slot("erc7201:neobank.storage.StandaloneStrategy");
        assembly {
            $.slot := slot
        }
    }

    function fund() public view returns (address) {
        return _standaloneStrategyStorage().fund;
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

        emit StandaloneStrategyCreated(fund_);
    }

    function call(
        address target,
        bytes calldata data
    ) external payable onlyRole(CALLER_ROLE) nonReentrant returns (bytes memory) {
        if (target == _standaloneStrategyStorage().fund) revert TargetNotAllowed();
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
        if (target == _standaloneStrategyStorage().fund) revert TargetNotAllowed();
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

    function pullAsset(
        address asset,
        address to,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (to == address(0)) revert ZeroAddress();
        TransferHelper.transfer(asset, to, amount);
        emit AssetPulled(asset, to, amount);
    }

    function _setFund(address fund_) internal {
        _standaloneStrategyStorage().fund = fund_;
        emit FundUpdated(fund_);
    }
}
