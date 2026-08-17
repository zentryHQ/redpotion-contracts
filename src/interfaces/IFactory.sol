// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

interface IFactory {

    event ImplementationSet(address indexed implementation, uint256 version);
    event EntityCreated(address indexed entity, uint256 indexed version);

    error NoImplementation();
    error ZeroAddress();

    /// @notice Returns the current implementation address used for new proxies.
    function implementation() external view returns (address);

    /// @notice Returns the current implementation version.
    function version() external view returns (uint256);

    /// @notice Returns the total number of deployed entities.
    function entityCount() external view returns (uint256);

    /// @notice Returns the entity address at a given index.
    function entityAt(uint256 index) external view returns (address);

    /// @notice Returns true if the address was deployed by this factory.
    function isEntity(address entity) external view returns (bool);

    function initialize(address owner_) external;

    /// @notice Sets a new implementation contract for future deployments.
    function setImplementation(address implementation_) external;

    /// @notice Deploys a new proxy pointing to the current implementation.
    /// @param initData ABI-encoded initializer calldata.
    /// @return entity The address of the newly deployed proxy.
    function create(bytes calldata initData) external returns (address entity);

    /// @notice Deploys a new proxy with a specific ProxyAdmin owner.
    /// @param initData ABI-encoded initializer calldata.
    /// @param proxyAdminOwner Address that will own the deployed proxy's ProxyAdmin.
    /// @return entity The address of the newly deployed proxy.
    function createFor(bytes calldata initData, address proxyAdminOwner) external returns (address entity);
}
