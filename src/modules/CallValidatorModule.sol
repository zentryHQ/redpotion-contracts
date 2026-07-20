// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./ACLModule.sol";
import "./ERC7201.sol";
import "../interfaces/ICallValidator.sol";

abstract contract CallValidatorModule is ICallValidator, ERC7201, ACLModule {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    bytes32 public constant ADD_ALLOWED_CALL_ROLE = keccak256("ADD_ALLOWED_CALL_ROLE");
    bytes32 public constant REMOVE_ALLOWED_CALL_ROLE = keccak256("REMOVE_ALLOWED_CALL_ROLE");

    /// @custom:storage-location erc7201:neobank.storage.CallValidator
    struct CallValidatorStorage {
        EnumerableSet.Bytes32Set allowedCalls;
        mapping(bytes32 => Call) calls;
        EnumerableSet.Bytes32Set allowedConstrainedCalls;
        mapping(bytes32 => ConstrainedCall) constrainedCalls;
    }

    function _callValidatorStorage() private pure returns (CallValidatorStorage storage $) {
        bytes32 slot = _erc7201Slot("erc7201:neobank.storage.CallValidator");
        assembly {
            $.slot := slot
        }
    }

    error ZeroAddress();

    // ========================================
    // Call Management
    // ========================================

    function addCalls(
        Call[] calldata calls_
    ) external onlyRole(ADD_ALLOWED_CALL_ROLE) {
        CallValidatorStorage storage $ = _callValidatorStorage();
        for (uint256 i = 0; i < calls_.length; i++) {
            Call calldata call_ = calls_[i];
            if (call_.target == address(0)) revert ZeroAddress();

            bytes32 callHash = getCallHash(call_.caller, call_.target, call_.selector);
            if ($.allowedCalls.contains(callHash)) revert CallAlreadyAllowed();

            $.allowedCalls.add(callHash);
            $.calls[callHash] = call_;

            emit CallAdded(callHash, call_);
        }
    }

    function removeCalls(
        bytes32[] calldata callHashes
    ) external onlyRole(REMOVE_ALLOWED_CALL_ROLE) {
        CallValidatorStorage storage $ = _callValidatorStorage();
        for (uint256 i = 0; i < callHashes.length; i++) {
            bytes32 callHash = callHashes[i];
            if (!$.allowedCalls.contains(callHash)) revert CallNotAllowed();

            Call memory call_ = $.calls[callHash];
            $.allowedCalls.remove(callHash);
            delete $.calls[callHash];

            emit CallRemoved(callHash, call_);
        }
    }

    function addConstrainedCalls(
        ConstrainedCall[] calldata calls_
    ) external onlyRole(ADD_ALLOWED_CALL_ROLE) {
        CallValidatorStorage storage $ = _callValidatorStorage();
        for (uint256 i = 0; i < calls_.length; i++) {
            ConstrainedCall calldata call_ = calls_[i];
            if (call_.target == address(0)) revert ZeroAddress();
            if (call_.constrainedOffsets.length != call_.constrainedValues.length)
                revert LengthMismatch();

            bytes32 callHash = getConstrainedCallHash(
                call_.caller,
                call_.target,
                call_.selector,
                call_.constrainedOffsets,
                call_.constrainedValues
            );
            if ($.allowedConstrainedCalls.contains(callHash)) revert CallAlreadyAllowed();

            $.allowedConstrainedCalls.add(callHash);
            $.constrainedCalls[callHash] = call_;

            emit ConstrainedCallAdded(callHash, call_);
        }
    }

    function removeConstrainedCalls(
        bytes32[] calldata callHashes
    ) external onlyRole(REMOVE_ALLOWED_CALL_ROLE) {
        CallValidatorStorage storage $ = _callValidatorStorage();
        for (uint256 i = 0; i < callHashes.length; i++) {
            bytes32 callHash = callHashes[i];
            if (!$.allowedConstrainedCalls.contains(callHash)) revert CallNotAllowed();

            ConstrainedCall memory call_ = $.constrainedCalls[callHash];
            $.allowedConstrainedCalls.remove(callHash);
            delete $.constrainedCalls[callHash];

            emit ConstrainedCallRemoved(callHash, call_);
        }
    }

    // ========================================
    // Internal — Validation
    // ========================================

    function _isCallPermitted(
        address caller,
        address target,
        bytes4 selector
    ) internal view returns (bool) {
        bytes32 callHash = getCallHash(caller, target, selector);
        return _callValidatorStorage().allowedCalls.contains(callHash);
    }

    function _isCallPermitted(
        address caller,
        address target,
        bytes4 selector,
        uint256[] calldata constrainedOffsets,
        bytes32[] calldata constrainedValues,
        bytes calldata data
    ) internal view returns (bool) {
        bytes32 callHash = getConstrainedCallHash(
            caller, target, selector, constrainedOffsets, constrainedValues
        );
        CallValidatorStorage storage $ = _callValidatorStorage();
        if (!$.allowedConstrainedCalls.contains(callHash)) return false;

        return _checkConstraints($.constrainedCalls[callHash], data);
    }

    function _checkConstraints(
        ConstrainedCall storage cc,
        bytes calldata data
    ) internal view returns (bool) {
        for (uint256 j = 0; j < cc.constrainedOffsets.length; j++) {
            uint256 offset = cc.constrainedOffsets[j];
            if (offset + 32 > data.length) return false;

            bytes32 actual = bytes32(data[offset:offset + 32]);
            if (actual != cc.constrainedValues[j]) return false;
        }
        return true;
    }

    // ========================================
    // Views
    // ========================================

    function getCall(bytes32 callHash) external view returns (Call memory) {
        return _callValidatorStorage().calls[callHash];
    }

    function getConstrainedCall(
        bytes32 callHash
    ) external view returns (ConstrainedCall memory) {
        return _callValidatorStorage().constrainedCalls[callHash];
    }

    function getAllowedCalls() external view returns (bytes32[] memory) {
        return _callValidatorStorage().allowedCalls.values();
    }

    function getAllowedConstrainedCalls() external view returns (bytes32[] memory) {
        return _callValidatorStorage().allowedConstrainedCalls.values();
    }

    function getCallHash(
        address caller,
        address target,
        bytes4 selector
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(caller, target, selector));
    }

    function getConstrainedCallHash(
        address caller,
        address target,
        bytes4 selector,
        uint256[] calldata constrainedOffsets,
        bytes32[] calldata constrainedValues
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encode(caller, target, selector, constrainedOffsets, constrainedValues)
        );
    }
}
