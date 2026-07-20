// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "./IFundManager.sol";

interface IFundManagerDeployer {
    event FundManagerCreated(
        address indexed fundManager,
        address indexed owner,
        address fundFactory,
        address shareFactory,
        address depositQueueFactory,
        address redeemQueueFactory,
        address oracleFactory,
        address feeManagerFactory,
        address riskManagerFactory,
        address strategyFactory
    );

    event ProtocolFeeRecipientUpdated(address indexed protocolFeeRecipient);

    event ImplementationsSet(
        address factoryImplementation,
        address fundManagerImplementation,
        address fundImplementation,
        address shareImplementation,
        address depositQueueImplementation,
        address redeemQueueImplementation,
        address oracleImplementation,
        address feeManagerImplementation,
        address riskManagerImplementation,
        address strategyImplementation
    );

    error ZeroAddress();

    function protocolFeeRecipient() external view returns (address);
    function fundManagerFactory() external view returns (IFactory);
    function factoryImplementation() external view returns (address);
    function fundManagerImplementation() external view returns (address);
    function fundImplementation() external view returns (address);
    function shareImplementation() external view returns (address);
    function depositQueueImplementation() external view returns (address);
    function redeemQueueImplementation() external view returns (address);
    function oracleImplementation() external view returns (address);
    function feeManagerImplementation() external view returns (address);
    function riskManagerImplementation() external view returns (address);
    function strategyImplementation() external view returns (address);
    function fundManagerCount() external view returns (uint256);
    function fundManagerAt(uint256 index) external view returns (address);
    function isFundManager(address entity) external view returns (bool);

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
    ) external;

    function createFundManager(address owner_, address proxyAdmin_, ACLModule.RoleHolder[] memory fundManagerRoleHolders_) external returns (address fundManager);
    function setProtocolFeeRecipient(address recipient_) external;
}
