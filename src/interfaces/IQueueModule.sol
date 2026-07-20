// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./IModuleErrors.sol";

/// @dev Minimal Fund-side surface for the queue subsystem. Admin proxies
/// (pause, setAllowedAssets, pullAsset, adminCancel) were removed — admins
/// call DepositQueue/RedeemQueue directly; both spokes auth via role
/// callback to Fund's access control.
interface IQueueModule is IModuleErrors {
    // Settlement events (emitted by Fund during _settleAll orchestration)
    event ShareUpdated(address indexed share);
    event DepositSettled(address indexed asset, uint256 indexed batchId, uint256 userShares, uint256 feeShares);
    event RedeemSettled(address indexed asset, uint256 indexed batchId, uint256 redeemTotal, uint256 feeShares);

    // Views — stored addresses the queues and other spokes need to resolve
    function share() external view returns (address);
    function depositQueue() external view returns (address);
    function redeemQueue() external view returns (address);
}
