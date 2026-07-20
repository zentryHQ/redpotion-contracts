// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./IFactory.sol";
import "./IFeeManager.sol";
import "./IFund.sol";
import "./IOracle.sol";
import "./IReportModule.sol";
import "./IRiskManager.sol";
import "./IStrategy.sol";
import "../modules/ACLModule.sol";
import "../modules/FundACLModule.sol";

interface IFundManager {
    // Events

    event FundCreated(
        address indexed fund,
        address indexed share,
        address depositQueue,
        address redeemQueue,
        address oracle,
        address feeManager,
        address riskManager,
        address indexed admin
    );
    event FundFactoryUpdated(address indexed fundFactory);
    event ShareFactoryUpdated(address indexed shareFactory);
    event DepositQueueFactoryUpdated(address indexed depositQueueFactory);
    event RedeemQueueFactoryUpdated(address indexed redeemQueueFactory);
    event OracleFactoryUpdated(address indexed oracleFactory);
    event FeeManagerFactoryUpdated(address indexed feeManagerFactory);
    event RiskManagerFactoryUpdated(address indexed riskManagerFactory);
    event StrategyFactoryUpdated(address indexed strategyFactory);
    event FundImplementationUpdated(address indexed impl);
    event ShareImplementationUpdated(address indexed impl);
    event DepositQueueImplementationUpdated(address indexed impl);
    event RedeemQueueImplementationUpdated(address indexed impl);
    event OracleImplementationUpdated(address indexed impl);
    event FeeManagerImplementationUpdated(address indexed impl);
    event RiskManagerImplementationUpdated(address indexed impl);
    event StrategyImplementationUpdated(address indexed impl);

    event FundManagerCreated(
        address indexed fundFactory,
        address indexed shareFactory,
        address depositQueueFactory,
        address redeemQueueFactory,
        address oracleFactory,
        address feeManagerFactory,
        address riskManagerFactory,
        address strategyFactory
    );

    // Errors

    error ZeroAddress();
    error InvalidCaller();


    // View functions

    function fundFactory() external view returns (IFactory);
    function shareFactory() external view returns (IFactory);
    function depositQueueFactory() external view returns (IFactory);
    function redeemQueueFactory() external view returns (IFactory);
    function oracleFactory() external view returns (IFactory);
    function feeManagerFactory() external view returns (IFactory);
    function riskManagerFactory() external view returns (IFactory);
    function strategyFactory() external view returns (IFactory);
    function deployer() external view returns (address);
    function protocolFeeRecipient() external view returns (address);

    // Mutable functions

    function initialize(
        address owner_,
        address deployer_,
        address fundFactory_,
        address shareFactory_,
        address depositQueueFactory_,
        address redeemQueueFactory_,
        address oracleFactory_,
        address feeManagerFactory_,
        address riskManagerFactory_,
        address strategyFactory_,
        ACLModule.RoleHolder[] memory roleHolders_
    ) external;

    function setFundFactory(address fundFactory_) external;
    function setShareFactory(address shareFactory_) external;
    function setDepositQueueFactory(address depositQueueFactory_) external;
    function setRedeemQueueFactory(address redeemQueueFactory_) external;
    function setOracleFactory(address oracleFactory_) external;
    function setFeeManagerFactory(address feeManagerFactory_) external;
    function setRiskManagerFactory(address riskManagerFactory_) external;
    function setStrategyFactory(address strategyFactory_) external;
    function setFundImplementation(address impl) external;
    function setShareImplementation(address impl) external;
    function setDepositQueueImplementation(address impl) external;
    function setRedeemQueueImplementation(address impl) external;
    function setOracleImplementation(address impl) external;
    function setFeeManagerImplementation(address impl) external;
    function setRiskManagerImplementation(address impl) external;
    function setStrategyImplementation(address impl) external;
    function createStrategyForFund(
        address fund,
        address admin_,
        ACLModule.RoleHolder[] memory roleHolders_
    ) external returns (address strategy);

    struct CreateFundParams {
        address[] depositAssets;
        address[] redeemAssets;
        string shareName;
        string shareSymbol;
        address admin;
        address proxyAdmin;
        address feeRecipient;
        address feeBaseAsset;
        IFeeManager.FeeConfig feeConfig;
        uint48 firstCutoffTime;
        IOracle.ReportDelays reportDelays;
        IReportModule.PriceSafetyInit[] priceSafeties;
        IRiskManager.RiskConfig riskConfig;
        FundACLModule.RoleHolder[] roleHolders;
    }

    function createFund(
        CreateFundParams calldata params
    ) external returns (
        address fund,
        address share,
        address depositQueue,
        address redeemQueue,
        address oracle_,
        address feeManager_,
        address riskManager_
    );
}
