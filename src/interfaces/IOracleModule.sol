// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

/// @dev Minimal Fund-side surface for Oracle. Admin/submit/reject/view proxies
/// were removed — callers with the appropriate role call the Oracle spoke
/// directly (Oracle does role callback auth against Fund's access control).
interface IOracleModule {
    function oracle() external view returns (address);

    /// @dev Required by DepositQueue/RedeemQueue so they can look up the
    /// current batch without knowing the Oracle address (star architecture).
    function getCurrentBatchId() external view returns (uint256);
}
