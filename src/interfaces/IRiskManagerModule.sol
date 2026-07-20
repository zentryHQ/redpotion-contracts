// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

/// @dev Minimal Fund-side surface for RiskManager. Admin setters and estimate
/// views were removed — callers invoke them on the RiskManager spoke directly
/// (role-callback auth). The `checkDeposit`/`checkRedeem` thin proxies remain
/// because DepositQueue/RedeemQueue route through Fund (star architecture).
interface IRiskManagerModule {
    function checkDeposit(address depositor, address asset, uint256 batchId, uint256 depositAmount, bytes32[] calldata proof) external view;
    function checkRedeem(uint256 batchId, uint256 redeemShares) external view;
}
