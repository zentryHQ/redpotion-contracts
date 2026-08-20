// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";

import {AssetSet} from "../src/libraries/AssetSet.sol";

contract AssetSetTest is Test {
    address internal constant ASSET_ONE = address(0xA1);
    address internal constant ASSET_TWO = address(0xA2);
    address internal constant ASSET_THREE = address(0xA3);
    address internal constant ASSET_FOUR = address(0xA4);

    function test_union_disjointSetsConcatenates() public pure {
        address[] memory result = AssetSet.union(
            _assets(ASSET_ONE, ASSET_TWO),
            _assets(ASSET_THREE, ASSET_FOUR)
        );

        assertEq(result.length, 4);
        assertEq(result[0], ASSET_ONE);
        assertEq(result[1], ASSET_TWO);
        assertEq(result[2], ASSET_THREE);
        assertEq(result[3], ASSET_FOUR);
    }

    function test_union_overlapKeepsFirstOccurrenceOrder() public pure {
        address[] memory result = AssetSet.union(
            _assets(ASSET_ONE, ASSET_TWO),
            _assets(ASSET_TWO, ASSET_THREE)
        );

        assertEq(result.length, 3);
        assertEq(result[0], ASSET_ONE);
        assertEq(result[1], ASSET_TWO);
        assertEq(result[2], ASSET_THREE);
    }

    function test_union_identicalSetsReturnsFirstSet() public pure {
        address[] memory result = AssetSet.union(
            _assets(ASSET_ONE, ASSET_TWO),
            _assets(ASSET_ONE, ASSET_TWO)
        );

        assertEq(result.length, 2);
        assertEq(result[0], ASSET_ONE);
        assertEq(result[1], ASSET_TWO);
    }

    function test_union_fullOverlapIgnoresSecondSetOrder() public pure {
        address[] memory result = AssetSet.union(
            _assets(ASSET_ONE, ASSET_TWO),
            _assets(ASSET_TWO, ASSET_ONE)
        );

        assertEq(result.length, 2);
        assertEq(result[0], ASSET_ONE);
        assertEq(result[1], ASSET_TWO);
    }

    function test_union_emptyFirstSetReturnsSecond() public pure {
        address[] memory result = AssetSet.union(
            new address[](0),
            _assets(ASSET_ONE, ASSET_TWO)
        );

        assertEq(result.length, 2);
        assertEq(result[0], ASSET_ONE);
        assertEq(result[1], ASSET_TWO);
    }

    function test_union_emptySecondSetReturnsFirst() public pure {
        address[] memory result = AssetSet.union(
            _assets(ASSET_ONE, ASSET_TWO),
            new address[](0)
        );

        assertEq(result.length, 2);
        assertEq(result[0], ASSET_ONE);
        assertEq(result[1], ASSET_TWO);
    }

    function test_union_bothEmptyReturnsEmpty() public pure {
        address[] memory result = AssetSet.union(new address[](0), new address[](0));

        assertEq(result.length, 0);
    }

    /// @dev The shrunk array must not corrupt memory allocated after it: a
    /// later allocation starts past the over-allocated tail, so writing to it
    /// cannot touch the union result and vice versa.
    function test_union_shrunkArrayLeavesLaterAllocationsIntact() public pure {
        address[] memory result = AssetSet.union(
            _assets(ASSET_ONE, ASSET_TWO),
            _assets(ASSET_ONE, ASSET_TWO)
        );

        address[] memory laterAllocation = _assets(ASSET_THREE, ASSET_FOUR);

        assertEq(result.length, 2);
        assertEq(result[0], ASSET_ONE);
        assertEq(result[1], ASSET_TWO);
        assertEq(laterAllocation.length, 2);
        assertEq(laterAllocation[0], ASSET_THREE);
        assertEq(laterAllocation[1], ASSET_FOUR);
    }

    function test_union_fuzz_containsExactlyBothSets(
        address[] memory a,
        address[] memory b
    ) public pure {
        address[] memory result = AssetSet.union(a, b);

        assertLe(result.length, a.length + b.length);
        for (uint256 i = 0; i < a.length; i++) {
            assertTrue(_contains(result, a[i]));
        }
        for (uint256 i = 0; i < b.length; i++) {
            assertTrue(_contains(result, b[i]));
        }
        for (uint256 i = 0; i < result.length; i++) {
            assertTrue(_contains(a, result[i]) || _contains(b, result[i]));
        }
    }

    function _assets(address first, address second) internal pure returns (address[] memory assets) {
        assets = new address[](2);
        assets[0] = first;
        assets[1] = second;
    }

    function _contains(address[] memory assets, address asset) internal pure returns (bool) {
        for (uint256 i = 0; i < assets.length; i++) {
            if (assets[i] == asset) return true;
        }
        return false;
    }
}
