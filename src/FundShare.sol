// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "./interfaces/IFundShare.sol";

/// @title FundShare
/// @notice ERC20 share token for a Fund. Only the Fund can mint/burn.
contract FundShare is IFundShare, ERC20Upgradeable {
    address public fund;

    modifier onlyFund() {
        if (_msgSender() != fund) revert OnlyFund();
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name_,
        string memory symbol_,
        address fund_
    ) external initializer {
        if (fund_ == address(0)) revert ZeroAddress();

        __ERC20_init(name_, symbol_);
        fund = fund_;
    }

    function mint(address to, uint256 amount) external onlyFund {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyFund {
        _burn(from, amount);
    }

    // --- IERC20 overrides to resolve ambiguity ---

    function totalSupply()
        public
        view
        override(ERC20Upgradeable, IERC20)
        returns (uint256)
    {
        return super.totalSupply();
    }

    function balanceOf(
        address account
    ) public view override(ERC20Upgradeable, IERC20) returns (uint256) {
        return super.balanceOf(account);
    }

    function transfer(
        address to,
        uint256 value
    ) public override(ERC20Upgradeable, IERC20) returns (bool) {
        return super.transfer(to, value);
    }

    function allowance(
        address owner_,
        address spender
    ) public view override(ERC20Upgradeable, IERC20) returns (uint256) {
        return super.allowance(owner_, spender);
    }

    function approve(
        address spender,
        uint256 value
    ) public override(ERC20Upgradeable, IERC20) returns (bool) {
        return super.approve(spender, value);
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public override(ERC20Upgradeable, IERC20) returns (bool) {
        return super.transferFrom(from, to, value);
    }
}
