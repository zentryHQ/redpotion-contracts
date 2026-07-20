// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

interface ICallValidator {
    struct Call {
        address caller;
        address target;
        bytes4 selector;
    }

    struct ConstrainedCall {
        address caller;
        address target;
        bytes4 selector;
        uint256[] constrainedOffsets;
        bytes32[] constrainedValues;
    }

    // Events

    event CallAdded(bytes32 indexed callHash, Call call_);
    event CallRemoved(bytes32 indexed callHash, Call call_);
    event ConstrainedCallAdded(bytes32 indexed callHash, ConstrainedCall call_);
    event ConstrainedCallRemoved(bytes32 indexed callHash, ConstrainedCall call_);

    // Errors

    error CallNotAllowed();
    error CallAlreadyAllowed();
    error LengthMismatch();

    // View functions

    function getCall(bytes32 callHash) external view returns (Call memory);

    function getConstrainedCall(
        bytes32 callHash
    ) external view returns (ConstrainedCall memory);

    function getAllowedCalls() external view returns (bytes32[] memory);

    function getAllowedConstrainedCalls() external view returns (bytes32[] memory);

    function getCallHash(
        address caller,
        address target,
        bytes4 selector
    ) external pure returns (bytes32);

    function getConstrainedCallHash(
        address caller,
        address target,
        bytes4 selector,
        uint256[] calldata constrainedOffsets,
        bytes32[] calldata constrainedValues
    ) external pure returns (bytes32);

    // Mutable functions

    function addCalls(Call[] calldata calls_) external;

    function removeCalls(bytes32[] calldata callHashes) external;

    function addConstrainedCalls(ConstrainedCall[] calldata calls_) external;

    function removeConstrainedCalls(bytes32[] calldata callHashes) external;
}
