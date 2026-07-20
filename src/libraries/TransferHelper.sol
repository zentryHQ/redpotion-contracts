// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library TransferHelper {
    using SafeERC20 for IERC20;

    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    error ETHTransferFailed();
    error InvalidETHAmount();

    function isETH(address asset) internal pure returns (bool) {
        return asset == ETH;
    }

    function transferFrom(
        address asset,
        address from,
        address to,
        uint256 amount
    ) internal {
        if (isETH(asset)) {
            if (msg.value != amount) revert InvalidETHAmount();
        } else {
            IERC20(asset).safeTransferFrom(from, to, amount);
        }
    }

    function transfer(
        address asset,
        address to,
        uint256 amount
    ) internal {
        if (amount == 0) return;
        if (isETH(asset)) {
            (bool success, ) = payable(to).call{value: amount}("");
            if (!success) revert ETHTransferFailed();
        } else {
            IERC20(asset).safeTransfer(to, amount);
        }
    }
}
