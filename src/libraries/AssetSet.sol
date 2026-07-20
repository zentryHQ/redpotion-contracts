// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

library AssetSet {
    function union(
        address[] memory a,
        address[] memory b
    ) internal pure returns (address[] memory) {
        uint256 count = a.length;
        for (uint256 i = 0; i < b.length; i++) {
            bool found = false;
            for (uint256 j = 0; j < a.length; j++) {
                if (b[i] == a[j]) {
                    found = true;
                    break;
                }
            }
            if (!found) count++;
        }

        address[] memory result = new address[](count);
        for (uint256 i = 0; i < a.length; i++) {
            result[i] = a[i];
        }

        uint256 idx = a.length;
        for (uint256 i = 0; i < b.length; i++) {
            bool found = false;
            for (uint256 j = 0; j < a.length; j++) {
                if (b[i] == a[j]) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                result[idx] = b[i];
                idx++;
            }
        }

        return result;
    }

    /// @dev Returns `a` plus `x` if `x` is not already in `a`.
    function add(
        address[] memory a,
        address x
    ) internal pure returns (address[] memory) {
        for (uint256 i = 0; i < a.length; i++) {
            if (a[i] == x) return a;
        }
        address[] memory result = new address[](a.length + 1);
        for (uint256 i = 0; i < a.length; i++) {
            result[i] = a[i];
        }
        result[a.length] = x;
        return result;
    }
}
