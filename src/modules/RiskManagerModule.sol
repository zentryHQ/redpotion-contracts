// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./ModuleBase.sol";
import "../interfaces/IRiskManager.sol";
import "../interfaces/IRiskManagerModule.sol";

/// @dev Stores the RiskManager address and exposes only the pieces Fund needs
/// to mediate queue → RiskManager validation (star architecture). Admin
/// setters and estimate views were removed — users call RiskManager directly.
abstract contract RiskManagerModule is IRiskManagerModule, ModuleBase {
    /// @custom:storage-location erc7201:neobank.storage.RiskManagerModule
    struct RiskManagerStorage {
        address riskManager;
    }

    function _riskManagerStorage() private pure returns (RiskManagerStorage storage $) {
        bytes32 slot = _erc7201Slot("erc7201:neobank.storage.RiskManagerModule");
        assembly {
            $.slot := slot
        }
    }

    function __RiskManagerModule_init(address riskManager_) internal onlyInitializing {
        _riskManagerStorage().riskManager = riskManager_;
    }

    /// @dev Called by DepositQueue.deposit. The queue passes the end-user's
    /// address (its own `_msgSender()`) as `depositor` so whitelist checks
    /// apply to the actual depositor, not the queue contract.
    function checkDeposit(
        address depositor,
        address asset,
        uint256 batchId,
        uint256 depositAmount,
        bytes32[] calldata proof
    ) external view {
        IRiskManager(_riskManagerStorage().riskManager).checkDeposit(
            depositor, asset, batchId, depositAmount, proof
        );
    }

    function checkRedeem(
        uint256 batchId,
        uint256 redeemShares
    ) external view {
        IRiskManager(_riskManagerStorage().riskManager).checkRedeem(
            batchId, redeemShares
        );
    }
}
