// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "./modules/ACLModule.sol";
import "./interfaces/IFundManagerDeployer.sol";
import "./interfaces/IFactory.sol";
import "./interfaces/IFundManager.sol";

contract FundManagerDeployer is IFundManagerDeployer, ACLModule {
    bytes32 public constant CREATE_FUND_MANAGER_ROLE = keccak256("CREATE_FUND_MANAGER_ROLE");
    bytes32 public constant SET_IMPLEMENTATIONS_ROLE = keccak256("SET_IMPLEMENTATIONS_ROLE");
    bytes32 public constant SET_PROTOCOL_FEE_RECIPIENT_ROLE = keccak256("SET_PROTOCOL_FEE_RECIPIENT_ROLE");

    IFactory public fundManagerFactory;

    address public factoryImplementation;
    address public fundManagerImplementation;
    address public fundImplementation;
    address public shareImplementation;
    address public depositQueueImplementation;
    address public redeemQueueImplementation;
    address public oracleImplementation;
    address public feeManagerImplementation;
    address public riskManagerImplementation;
    address public strategyImplementation;

    address public proxyAdmin;

    address public protocolFeeRecipient;

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address admin_,
        address proxyAdmin_,
        address fundManagerFactory_,
        address protocolFeeRecipient_,
        RoleHolder[] memory roleHolders_
    ) external initializer {
        if (admin_ == address(0)) revert ZeroAddress();
        if (proxyAdmin_ == address(0)) revert ZeroAddress();
        if (fundManagerFactory_ == address(0)) revert ZeroAddress();

        __ACLModule_init(admin_, roleHolders_);

        proxyAdmin = proxyAdmin_;
        fundManagerFactory = IFactory(fundManagerFactory_);
        _setProtocolFeeRecipient(protocolFeeRecipient_);
    }

    // ========================================
    // Role-gated: protocol fee recipient
    // ========================================

    function setProtocolFeeRecipient(address recipient_) external onlyRole(SET_PROTOCOL_FEE_RECIPIENT_ROLE) {
        _setProtocolFeeRecipient(recipient_);
    }

    // View functions

    function fundManagerCount() external view returns (uint256) {
        return fundManagerFactory.entityCount();
    }

    function fundManagerAt(uint256 index) external view returns (address) {
        return fundManagerFactory.entityAt(index);
    }

    function isFundManager(address entity) external view returns (bool) {
        return fundManagerFactory.isEntity(entity);
    }

    // Mutable functions

    function setImplementations(
        address factoryImplementation_,
        address fundManagerImplementation_,
        address fundImplementation_,
        address shareImplementation_,
        address depositQueueImplementation_,
        address redeemQueueImplementation_,
        address oracleImplementation_,
        address feeManagerImplementation_,
        address riskManagerImplementation_,
        address strategyImplementation_
    ) external onlyRole(SET_IMPLEMENTATIONS_ROLE) {
        if (factoryImplementation_ == address(0)) revert ZeroAddress();
        if (fundManagerImplementation_ == address(0)) revert ZeroAddress();
        if (fundImplementation_ == address(0)) revert ZeroAddress();
        if (shareImplementation_ == address(0)) revert ZeroAddress();
        if (depositQueueImplementation_ == address(0)) revert ZeroAddress();
        if (redeemQueueImplementation_ == address(0)) revert ZeroAddress();
        if (oracleImplementation_ == address(0)) revert ZeroAddress();
        if (feeManagerImplementation_ == address(0)) revert ZeroAddress();
        if (riskManagerImplementation_ == address(0)) revert ZeroAddress();
        if (strategyImplementation_ == address(0)) revert ZeroAddress();

        factoryImplementation = factoryImplementation_;
        fundManagerImplementation = fundManagerImplementation_;
        fundImplementation = fundImplementation_;
        shareImplementation = shareImplementation_;
        depositQueueImplementation = depositQueueImplementation_;
        redeemQueueImplementation = redeemQueueImplementation_;
        oracleImplementation = oracleImplementation_;
        feeManagerImplementation = feeManagerImplementation_;
        riskManagerImplementation = riskManagerImplementation_;
        strategyImplementation = strategyImplementation_;

        fundManagerFactory.setImplementation(fundManagerImplementation_);

        emit ImplementationsSet(
            factoryImplementation_,
            fundManagerImplementation_,
            fundImplementation_,
            shareImplementation_,
            depositQueueImplementation_,
            redeemQueueImplementation_,
            oracleImplementation_,
            feeManagerImplementation_,
            riskManagerImplementation_,
            strategyImplementation_
        );
    }

    function createFundManager(address owner_, address proxyAdmin_, ACLModule.RoleHolder[] memory fundManagerRoleHolders_) external onlyRole(CREATE_FUND_MANAGER_ROLE) returns (address fundManager) {
        if (owner_ == address(0)) revert ZeroAddress();
        if (proxyAdmin_ == address(0)) revert ZeroAddress();

        // 1. Deploy 8 Factory proxies, each owned by this deployer initially
        address fundFactory = _deployFactory();
        address shareFactory = _deployFactory();
        address depositQueueFactory = _deployFactory();
        address redeemQueueFactory = _deployFactory();
        address oracleFactory = _deployFactory();
        address feeManagerFactory = _deployFactory();
        address riskManagerFactory = _deployFactory();
        address strategyFactory = _deployFactory();

        // 2. Set entity implementations on each factory
        IFactory(fundFactory).setImplementation(fundImplementation);
        IFactory(shareFactory).setImplementation(shareImplementation);
        IFactory(depositQueueFactory).setImplementation(depositQueueImplementation);
        IFactory(redeemQueueFactory).setImplementation(redeemQueueImplementation);
        IFactory(oracleFactory).setImplementation(oracleImplementation);
        IFactory(feeManagerFactory).setImplementation(feeManagerImplementation);
        IFactory(riskManagerFactory).setImplementation(riskManagerImplementation);
        IFactory(strategyFactory).setImplementation(strategyImplementation);

        // 3. Deploy FundManager via factory with proxyAdmin_ as the ProxyAdmin owner
        fundManager = fundManagerFactory.createFor(
            abi.encodeCall(
                IFundManager.initialize,
                (owner_, address(this), fundFactory, shareFactory, depositQueueFactory, redeemQueueFactory, oracleFactory, feeManagerFactory, riskManagerFactory, strategyFactory, fundManagerRoleHolders_)
            ),
            proxyAdmin_
        );

        // 4. Transfer factory ProxyAdmin ownership to proxyAdmin_, logic ownership to FundManager
        _transferFactoryOwnership(fundFactory, proxyAdmin_, fundManager);
        _transferFactoryOwnership(shareFactory, proxyAdmin_, fundManager);
        _transferFactoryOwnership(depositQueueFactory, proxyAdmin_, fundManager);
        _transferFactoryOwnership(redeemQueueFactory, proxyAdmin_, fundManager);
        _transferFactoryOwnership(oracleFactory, proxyAdmin_, fundManager);
        _transferFactoryOwnership(feeManagerFactory, proxyAdmin_, fundManager);
        _transferFactoryOwnership(riskManagerFactory, proxyAdmin_, fundManager);
        _transferFactoryOwnership(strategyFactory, proxyAdmin_, fundManager);

        emit FundManagerCreated(
            fundManager,
            owner_,
            fundFactory,
            shareFactory,
            depositQueueFactory,
            redeemQueueFactory,
            oracleFactory,
            feeManagerFactory,
            riskManagerFactory,
            strategyFactory
        );
    }

    function _setProtocolFeeRecipient(address recipient_) internal {
        if (recipient_ == address(0)) revert ZeroAddress();
        protocolFeeRecipient = recipient_;
        emit ProtocolFeeRecipientUpdated(recipient_);
    }

    function _transferFactoryOwnership(address factory, address proxyAdminOwner, address logicOwner) internal {
        ProxyAdmin(_computeProxyAdminAddress(factory)).transferOwnership(proxyAdminOwner);
        OwnableUpgradeable(factory).transferOwnership(logicOwner);
    }

    /// @dev Computes the ProxyAdmin address for a TransparentUpgradeableProxy using the
    ///      deterministic CREATE formula. In OZ v5, the ProxyAdmin is the first contract
    ///      deployed inside the proxy constructor (nonce = 1).
    function _computeProxyAdminAddress(address proxy) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xd6), bytes1(0x94), proxy, bytes1(0x01)
        )))));
    }

    function _deployFactory() internal returns (address) {
        return address(
            new TransparentUpgradeableProxy(
                factoryImplementation,
                address(this),
                abi.encodeCall(IFactory.initialize, (address(this)))
            )
        );
    }
}
