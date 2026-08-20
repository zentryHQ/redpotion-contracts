// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./IModuleErrors.sol";

/// @dev Minimal Fund-side surface for the queue subsystem. Admin proxies
/// (pause, setAllowedAssets, pullAsset, adminCancel) were removed — admins
/// call DepositQueue/RedeemQueue directly; both spokes auth via role
/// callback to Fund's access control.
interface IQueueModule is IModuleErrors {
    event ShareUpdated(address indexed share);

    // Entry/exit fee accruals emitted by Fund during _settleAll
    // orchestration; batch totals are on the queues' *Settled events.
    event EntryFeeAccrued(address indexed asset, uint256 indexed batchId, uint256 feeShares);
    event ExitFeeAccrued(address indexed asset, uint256 indexed batchId, uint256 feeShares);

    // Views — stored addresses the queues and other spokes need to resolve
    function share() external view returns (address);
    function depositQueue() external view returns (address);
    function redeemQueue() external view returns (address);
}
