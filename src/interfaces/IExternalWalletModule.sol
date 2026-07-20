// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

interface IExternalWalletModule {
    event ExternalWalletAdded(address indexed wallet);
    event ExternalWalletRemoved(address indexed wallet);
    event AssetPushedToWallet(address indexed wallet, address indexed asset, uint256 amount);

    error InvalidWallet();
    error WalletAlreadyAdded();

    function isExternalWallet(address wallet) external view returns (bool);
    function getExternalWallets() external view returns (address[] memory);

    function addExternalWallet(address wallet) external;
    function removeExternalWallet(address wallet) external;
    function pushAssetToWallet(address wallet, address asset, uint256 amount) external;
}
