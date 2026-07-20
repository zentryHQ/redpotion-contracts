// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "../modules/FundACLModule.sol";
import "./IFeeManagerModule.sol";
import "./IQueueModule.sol";
import "./IExternalWalletModule.sol";
import "./IRiskManagerModule.sol";
import "./IOracleModule.sol";
import "./IStrategyModule.sol";
import "./IRiskManager.sol";

interface IFund is IFeeManagerModule, IQueueModule, IExternalWalletModule, IRiskManagerModule, IOracleModule, IStrategyModule {
    function fundRedeem(address asset, uint256 batchId) external;
    function getRiskContext(address asset, uint256 batchId) external view returns (IRiskManager.RiskContext memory);
    function protocolFeeRecipient() external view returns (address);

    function initialize(
        address share_,
        address depositQueue_,
        address redeemQueue_,
        address oracle_,
        address feeManager_,
        address riskManager_,
        address fundManager_,
        address admin_,
        FundACLModule.RoleHolder[] memory roleHolders_
    ) external;
}
