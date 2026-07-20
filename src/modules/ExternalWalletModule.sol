// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./ModuleBase.sol";
import "../libraries/TransferHelper.sol";
import "../interfaces/IExternalWalletModule.sol";

abstract contract ExternalWalletModule is IExternalWalletModule, ModuleBase {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @custom:storage-location erc7201:neobank.storage.ExternalWalletModule
    struct ExternalWalletStorage {
        EnumerableSet.AddressSet wallets;
    }

    function _externalWalletStorage() private pure returns (ExternalWalletStorage storage $) {
        bytes32 slot = _erc7201Slot("erc7201:neobank.storage.ExternalWalletModule");
        assembly {
            $.slot := slot
        }
    }

    function __ExternalWalletModule_init() internal onlyInitializing {}

    function isExternalWallet(address wallet) public view returns (bool) {
        return _externalWalletStorage().wallets.contains(wallet);
    }

    function getExternalWallets() external view returns (address[] memory) {
        return _externalWalletStorage().wallets.values();
    }

    function addExternalWallet(address wallet) external onlyRole(ADD_EXTERNAL_WALLET_ROLE) {
        if (wallet == address(0)) revert InvalidWallet();
        if (!_externalWalletStorage().wallets.add(wallet)) revert WalletAlreadyAdded();
        emit ExternalWalletAdded(wallet);
    }

    function removeExternalWallet(address wallet) external onlyRole(REMOVE_EXTERNAL_WALLET_ROLE) {
        if (!_externalWalletStorage().wallets.remove(wallet)) revert InvalidWallet();
        emit ExternalWalletRemoved(wallet);
    }

    function pushAssetToWallet(
        address wallet,
        address asset,
        uint256 amount
    ) external onlyRole(PUSH_TO_WALLET_ROLE) nonReentrant {
        if (!_externalWalletStorage().wallets.contains(wallet)) revert InvalidWallet();
        TransferHelper.transfer(asset, wallet, amount);
        emit AssetPushedToWallet(wallet, asset, amount);
    }
}
