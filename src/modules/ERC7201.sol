// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

/// @dev ERC-7201 namespaced-storage helper shared by Fund-side modules
/// (via ModuleBase) and Strategy-side modules (via CallValidatorModule).
abstract contract ERC7201 {
    /// @dev ERC-7201 storage slot for a given namespace.
    /// keccak256(abi.encode(uint256(keccak256(namespace)) - 1)) & ~bytes32(uint256(0xff))
    function _erc7201Slot(string memory namespace) internal pure returns (bytes32) {
        return keccak256(abi.encode(uint256(keccak256(bytes(namespace))) - 1)) & ~bytes32(uint256(0xff));
    }
}
