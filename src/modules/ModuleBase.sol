// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "./FundACLModule.sol";
import "./ERC7201.sol";

/// @dev Single shared base for every Fund module. Guarantees a uniform
/// linearization order so multi-module contracts (Fund) compose without C3
/// conflicts.
abstract contract ModuleBase is ERC7201, FundACLModule, ReentrancyGuardUpgradeable {}
