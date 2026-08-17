// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IFundShare is IERC20 {

    error OnlyFund();
    error ZeroAddress();

    /// @notice Returns the Fund contract that owns this share token.
    function fund() external view returns (address);

    function initialize(
        string memory name_,
        string memory symbol_,
        address fund_
    ) external;

    function mint(address to, uint256 amount) external;

    function burn(address from, uint256 amount) external;
}
