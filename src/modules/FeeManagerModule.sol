// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./ModuleBase.sol";
import "../interfaces/IFeeManager.sol";
import "../interfaces/IFeeManagerModule.sol";

/// @dev Stores the FeeManager address and exposes only the pieces Fund needs
/// during orchestration. All admin and pure-view proxies have been removed —
/// users call FeeManager directly, where role-callback auth applies.
abstract contract FeeManagerModule is IFeeManagerModule, ModuleBase {
    /// @custom:storage-location erc7201:neobank.storage.FeeManagerModule
    struct FeeManagerStorage {
        address feeManager;
    }

    function _feeManagerStorage() private pure returns (FeeManagerStorage storage $) {
        bytes32 slot = _erc7201Slot("erc7201:neobank.storage.FeeManagerModule");
        assembly {
            $.slot := slot
        }
    }

    function __FeeManagerModule_init(address feeManager_) internal onlyInitializing {
        _setFeeManager(feeManager_);
    }

    /// @inheritdoc IFeeManagerModule
    function feeManager() public view returns (address) {
        return _feeManagerStorage().feeManager;
    }

    function _setFeeManager(address feeManager_) internal {
        if (feeManager_ == address(0)) revert ZeroAddress();
        _feeManagerStorage().feeManager = feeManager_;
        emit FeeManagerUpdated(feeManager_);
    }

    // ========================================
    // Internal helpers used by Fund orchestration
    // ========================================

    function _feeBaseAsset() internal view returns (address) {
        return IFeeManager(_feeManagerStorage().feeManager).feeBaseAsset();
    }

    function _feeRecipient() internal view returns (address) {
        return IFeeManager(_feeManagerStorage().feeManager).feeRecipient();
    }

    function _entryFeeBps() internal view returns (uint256) {
        return IFeeManager(_feeManagerStorage().feeManager).entryFeeBps();
    }

    function _exitFeeBps() internal view returns (uint256) {
        return IFeeManager(_feeManagerStorage().feeManager).exitFeeBps();
    }

    /// @dev Calls FeeManager to compute + update fee state. Returns fund
    /// recipient + shares and protocol recipient + shares. Fund does the minting.
    function _accrueFees(
        uint256 totalSupply,
        uint256 newPrice
    ) internal returns (address recipient, uint256 feeShares, address protocolRecipient, uint256 protocolFeeShares) {
        return IFeeManager(_feeManagerStorage().feeManager).accrueFees(totalSupply, newPrice);
    }
}
