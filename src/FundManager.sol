// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "./modules/FundManagerACLModule.sol";
import "./interfaces/IFundManager.sol";
import "./interfaces/IFundManagerDeployer.sol";
import "./interfaces/IFactory.sol";
import "./interfaces/IFund.sol";
import "./interfaces/IFundShare.sol";
import "./interfaces/IDepositQueue.sol";
import "./interfaces/IRedeemQueue.sol";
import "./interfaces/IOracle.sol";
import "./interfaces/IFeeManager.sol";
import "./interfaces/IRiskManager.sol";
import "./interfaces/IStrategy.sol";

contract FundManager is IFundManager, ContextUpgradeable, FundManagerACLModule, ReentrancyGuardUpgradeable {
    IFactory public fundFactory;
    IFactory public shareFactory;
    IFactory public depositQueueFactory;
    IFactory public redeemQueueFactory;
    IFactory public oracleFactory;
    IFactory public feeManagerFactory;
    IFactory public riskManagerFactory;
    IFactory public strategyFactory;
    address public deployer;

    constructor() {
        _disableInitializers();
    }

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
    ) external initializer {
        if (deployer_ == address(0)) revert ZeroAddress();
        if (fundFactory_ == address(0)) revert ZeroAddress();
        if (shareFactory_ == address(0)) revert ZeroAddress();
        if (depositQueueFactory_ == address(0)) revert ZeroAddress();
        if (redeemQueueFactory_ == address(0)) revert ZeroAddress();
        if (oracleFactory_ == address(0)) revert ZeroAddress();
        if (feeManagerFactory_ == address(0)) revert ZeroAddress();
        if (riskManagerFactory_ == address(0)) revert ZeroAddress();
        if (strategyFactory_ == address(0)) revert ZeroAddress();

        __Context_init();
        __FundManagerACLModule_init(owner_, roleHolders_);
        __ReentrancyGuard_init();

        fundFactory = IFactory(fundFactory_);
        shareFactory = IFactory(shareFactory_);
        depositQueueFactory = IFactory(depositQueueFactory_);
        redeemQueueFactory = IFactory(redeemQueueFactory_);
        oracleFactory = IFactory(oracleFactory_);
        feeManagerFactory = IFactory(feeManagerFactory_);
        riskManagerFactory = IFactory(riskManagerFactory_);
        strategyFactory = IFactory(strategyFactory_);
        deployer = deployer_;

        emit FundManagerCreated(
            fundFactory_,
            shareFactory_,
            depositQueueFactory_,
            redeemQueueFactory_,
            oracleFactory_,
            feeManagerFactory_,
            riskManagerFactory_,
            strategyFactory_
        );
    }

    /// @inheritdoc IFundManager
    function setFundFactory(address f) external onlyRole(SET_FUND_FACTORY_ROLE) {
        if (f == address(0)) revert ZeroAddress();
        fundFactory = IFactory(f);
        emit FundFactoryUpdated(f);
    }

    /// @inheritdoc IFundManager
    function setShareFactory(address f) external onlyRole(SET_SHARE_FACTORY_ROLE) {
        if (f == address(0)) revert ZeroAddress();
        shareFactory = IFactory(f);
        emit ShareFactoryUpdated(f);
    }

    /// @inheritdoc IFundManager
    function setDepositQueueFactory(address f) external onlyRole(SET_DEPOSIT_QUEUE_FACTORY_ROLE) {
        if (f == address(0)) revert ZeroAddress();
        depositQueueFactory = IFactory(f);
        emit DepositQueueFactoryUpdated(f);
    }

    /// @inheritdoc IFundManager
    function setRedeemQueueFactory(address f) external onlyRole(SET_REDEEM_QUEUE_FACTORY_ROLE) {
        if (f == address(0)) revert ZeroAddress();
        redeemQueueFactory = IFactory(f);
        emit RedeemQueueFactoryUpdated(f);
    }

    /// @inheritdoc IFundManager
    function setOracleFactory(address f) external onlyRole(SET_ORACLE_FACTORY_ROLE) {
        if (f == address(0)) revert ZeroAddress();
        oracleFactory = IFactory(f);
        emit OracleFactoryUpdated(f);
    }

    /// @inheritdoc IFundManager
    function setFeeManagerFactory(address f) external onlyRole(SET_FEE_MANAGER_FACTORY_ROLE) {
        if (f == address(0)) revert ZeroAddress();
        feeManagerFactory = IFactory(f);
        emit FeeManagerFactoryUpdated(f);
    }

    /// @inheritdoc IFundManager
    function setRiskManagerFactory(address f) external onlyRole(SET_RISK_MANAGER_FACTORY_ROLE) {
        if (f == address(0)) revert ZeroAddress();
        riskManagerFactory = IFactory(f);
        emit RiskManagerFactoryUpdated(f);
    }

    /// @inheritdoc IFundManager
    function setStrategyFactory(address f) external onlyRole(SET_STRATEGY_FACTORY_ROLE) {
        if (f == address(0)) revert ZeroAddress();
        strategyFactory = IFactory(f);
        emit StrategyFactoryUpdated(f);
    }

    /// @inheritdoc IFundManager
    function setFundImplementation(address impl) external onlyRole(SET_FUND_FACTORY_ROLE) {
        if (impl == address(0)) revert ZeroAddress();
        fundFactory.setImplementation(impl);
        emit FundImplementationUpdated(impl);
    }

    /// @inheritdoc IFundManager
    function setShareImplementation(address impl) external onlyRole(SET_SHARE_FACTORY_ROLE) {
        if (impl == address(0)) revert ZeroAddress();
        shareFactory.setImplementation(impl);
        emit ShareImplementationUpdated(impl);
    }

    /// @inheritdoc IFundManager
    function setDepositQueueImplementation(address impl) external onlyRole(SET_DEPOSIT_QUEUE_FACTORY_ROLE) {
        if (impl == address(0)) revert ZeroAddress();
        depositQueueFactory.setImplementation(impl);
        emit DepositQueueImplementationUpdated(impl);
    }

    /// @inheritdoc IFundManager
    function setRedeemQueueImplementation(address impl) external onlyRole(SET_REDEEM_QUEUE_FACTORY_ROLE) {
        if (impl == address(0)) revert ZeroAddress();
        redeemQueueFactory.setImplementation(impl);
        emit RedeemQueueImplementationUpdated(impl);
    }

    /// @inheritdoc IFundManager
    function setOracleImplementation(address impl) external onlyRole(SET_ORACLE_FACTORY_ROLE) {
        if (impl == address(0)) revert ZeroAddress();
        oracleFactory.setImplementation(impl);
        emit OracleImplementationUpdated(impl);
    }

    /// @inheritdoc IFundManager
    function setFeeManagerImplementation(address impl) external onlyRole(SET_FEE_MANAGER_FACTORY_ROLE) {
        if (impl == address(0)) revert ZeroAddress();
        feeManagerFactory.setImplementation(impl);
        emit FeeManagerImplementationUpdated(impl);
    }

    /// @inheritdoc IFundManager
    function setRiskManagerImplementation(address impl) external onlyRole(SET_RISK_MANAGER_FACTORY_ROLE) {
        if (impl == address(0)) revert ZeroAddress();
        riskManagerFactory.setImplementation(impl);
        emit RiskManagerImplementationUpdated(impl);
    }

    /// @inheritdoc IFundManager
    function setStrategyImplementation(address impl) external onlyRole(SET_STRATEGY_FACTORY_ROLE) {
        if (impl == address(0)) revert ZeroAddress();
        strategyFactory.setImplementation(impl);
        emit StrategyImplementationUpdated(impl);
    }

    function _computeProxyAdminAddress(address proxy) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xd6), bytes1(0x94), proxy, bytes1(0x01)
        )))));
    }

    /// @inheritdoc IFundManager
    function protocolFeeRecipient() external view returns (address) {
        return IFundManagerDeployer(deployer).protocolFeeRecipient();
    }

    /// @inheritdoc IFundManager
    function createStrategyForFund(
        address fund,
        address admin_,
        ACLModule.RoleHolder[] memory roleHolders_
    ) external nonReentrant returns (address strategy) {
        if (msg.sender != fund) revert InvalidCaller();
        if (!fundFactory.isEntity(fund)) revert InvalidCaller();

        // Strategy ProxyAdmin must be owned by the same address that owns
        // the Fund's ProxyAdmin (the tenant proxy admin), otherwise the
        // strategy proxy would be un-upgradeable.
        address strategyProxyAdminOwner = ProxyAdmin(_computeProxyAdminAddress(fund)).owner();
        strategy = strategyFactory.createFor(
            abi.encodeCall(IStrategy.initialize, (fund, admin_, roleHolders_)),
            strategyProxyAdminOwner
        );
    }

    function createFund(
        CreateFundParams calldata params
    ) external onlyRole(CREATE_FUND_ROLE) nonReentrant returns (
        address fund, address share, address depositQueue, address redeemQueue,
        address oracle_, address feeManager_, address riskManager_
    ) {
        if (params.admin == address(0)) revert ZeroAddress();
        if (params.proxyAdmin == address(0)) revert ZeroAddress();
        if (params.feeRecipient == address(0)) revert ZeroAddress();

        fund = fundFactory.createFor(bytes(""), params.proxyAdmin);

        share = shareFactory.createFor(
            abi.encodeCall(IFundShare.initialize, (params.shareName, params.shareSymbol, fund)),
            params.proxyAdmin
        );

        depositQueue = depositQueueFactory.createFor(
            abi.encodeCall(IDepositQueue.initialize, (fund, params.depositAssets)),
            params.proxyAdmin
        );

        redeemQueue = redeemQueueFactory.createFor(
            abi.encodeCall(IRedeemQueue.initialize, (fund, params.redeemAssets)),
            params.proxyAdmin
        );

        oracle_ = oracleFactory.createFor(
            abi.encodeCall(
                IOracle.initialize,
                (
                    fund,
                    params.firstCutoffTime,
                    params.reportDelays.minAcceptReportDelay,
                    params.reportDelays.maxAcceptReportDelay,
                    params.priceSafeties
                )
            ),
            params.proxyAdmin
        );

        feeManager_ = feeManagerFactory.createFor(
            abi.encodeCall(
                IFeeManager.initialize,
                (fund, params.feeRecipient, params.feeBaseAsset, params.feeConfig)
            ),
            params.proxyAdmin
        );

        riskManager_ = riskManagerFactory.createFor(
            abi.encodeCall(IRiskManager.initialize, (fund, params.riskConfig)),
            params.proxyAdmin
        );

        IFund(fund).initialize(
            share,
            depositQueue,
            redeemQueue,
            oracle_,
            feeManager_,
            riskManager_,
            address(this),
            params.admin,
            params.roleHolders
        );

        emit FundCreated(fund, share, depositQueue, redeemQueue, oracle_, feeManager_, riskManager_, params.admin);
        emit FundShareCreated(fund, share, params.shareName, params.shareSymbol, IERC20Metadata(share).decimals());
    }
}
