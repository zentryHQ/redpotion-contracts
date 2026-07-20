// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";

abstract contract ACLModule is
    AccessControlEnumerableUpgradeable,
    MulticallUpgradeable
{
    struct RoleHolder {
        bytes32 role;
        address account;
    }

    function __ACLModule_init(
        address admin_,
        RoleHolder[] memory roleHolders_
    ) internal onlyInitializing {
        __AccessControlEnumerable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);

        for (uint256 i = 0; i < roleHolders_.length; i++) {
            _grantRole(roleHolders_[i].role, roleHolders_[i].account);
        }
    }

    function grantRoles(
        RoleHolder[] calldata roleHolders_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < roleHolders_.length; i++) {
            _grantRole(roleHolders_[i].role, roleHolders_[i].account);
        }
    }

    function revokeRoles(
        RoleHolder[] calldata roleHolders_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < roleHolders_.length; i++) {
            _revokeRole(roleHolders_[i].role, roleHolders_[i].account);
        }
    }
}
