// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

/// @dev Single source of truth for every Fund role identifier. Extended by
/// both FundACLModule (so Fund exposes `fund.SET_FEES_ROLE()` etc. for
/// external tooling) and FundSpokeACLModule (so spoke contracts can write
/// `onlyRole(SET_FEES_ROLE)` without importing a separate roles module).
///
/// Constants are `public` so the auto-generated external getters are present
/// anywhere this is inherited. Fund's external role-name API depends on this;
/// on spoke contracts the extra getters are harmless bytecode (spokes aren't
/// size-pressured).
abstract contract FundRoles {
    bytes32 public constant SET_FEES_ROLE = keccak256("SET_FEES_ROLE");
    bytes32 public constant SET_FEE_RECIPIENT_ROLE = keccak256("SET_FEE_RECIPIENT_ROLE");
    bytes32 public constant SET_FEE_BASE_ASSET_ROLE = keccak256("SET_FEE_BASE_ASSET_ROLE");
    bytes32 public constant SET_DEPOSIT_ALLOWED_ASSETS_ROLE = keccak256("SET_DEPOSIT_ALLOWED_ASSETS_ROLE");
    bytes32 public constant SET_REDEEM_ALLOWED_ASSETS_ROLE = keccak256("SET_REDEEM_ALLOWED_ASSETS_ROLE");
    bytes32 public constant SUBMIT_REPORT_ROLE = keccak256("SUBMIT_REPORT_ROLE");
    bytes32 public constant ACCEPT_REPORT_ROLE = keccak256("ACCEPT_REPORT_ROLE");
    bytes32 public constant ACCEPT_SUSPICIOUS_REPORT_ROLE = keccak256("ACCEPT_SUSPICIOUS_REPORT_ROLE");
    bytes32 public constant REJECT_REPORT_ROLE = keccak256("REJECT_REPORT_ROLE");
    bytes32 public constant FUND_REDEEM_ROLE = keccak256("FUND_REDEEM_ROLE");
    bytes32 public constant PULL_DEPOSIT_ASSET_ROLE = keccak256("PULL_DEPOSIT_ASSET_ROLE");
    bytes32 public constant PULL_REDEEM_ASSET_ROLE = keccak256("PULL_REDEEM_ASSET_ROLE");
    bytes32 public constant CREATE_STRATEGY_ROLE = keccak256("CREATE_STRATEGY_ROLE");
    bytes32 public constant ADD_STRATEGY_ROLE = keccak256("ADD_STRATEGY_ROLE");
    bytes32 public constant REMOVE_STRATEGY_ROLE = keccak256("REMOVE_STRATEGY_ROLE");
    bytes32 public constant PUSH_TO_STRATEGY_ROLE = keccak256("PUSH_TO_STRATEGY_ROLE");
    bytes32 public constant PULL_FROM_STRATEGY_ROLE = keccak256("PULL_FROM_STRATEGY_ROLE");
    bytes32 public constant ADD_EXTERNAL_WALLET_ROLE = keccak256("ADD_EXTERNAL_WALLET_ROLE");
    bytes32 public constant REMOVE_EXTERNAL_WALLET_ROLE = keccak256("REMOVE_EXTERNAL_WALLET_ROLE");
    bytes32 public constant PUSH_TO_WALLET_ROLE = keccak256("PUSH_TO_WALLET_ROLE");
    bytes32 public constant PAUSE_DEPOSIT_ROLE = keccak256("PAUSE_DEPOSIT_ROLE");
    bytes32 public constant UNPAUSE_DEPOSIT_ROLE = keccak256("UNPAUSE_DEPOSIT_ROLE");
    bytes32 public constant PAUSE_REDEEM_ROLE = keccak256("PAUSE_REDEEM_ROLE");
    bytes32 public constant UNPAUSE_REDEEM_ROLE = keccak256("UNPAUSE_REDEEM_ROLE");
    bytes32 public constant SET_PRICE_SAFETY_ROLE = keccak256("SET_PRICE_SAFETY_ROLE");
    bytes32 public constant SET_BATCH_CAPS_ROLE = keccak256("SET_BATCH_CAPS_ROLE");
    bytes32 public constant SET_TVL_CAP_ROLE = keccak256("SET_TVL_CAP_ROLE");
    bytes32 public constant SET_MIN_DEPOSIT_AMOUNT_ROLE = keccak256("SET_MIN_DEPOSIT_AMOUNT_ROLE");
    bytes32 public constant SET_MIN_REDEEM_AMOUNT_ROLE = keccak256("SET_MIN_REDEEM_AMOUNT_ROLE");
    bytes32 public constant SET_NEXT_CUTOFF_TIME_ROLE = keccak256("SET_NEXT_CUTOFF_TIME_ROLE");
    bytes32 public constant SET_MIN_ACCEPT_REPORT_DELAY_ROLE = keccak256("SET_MIN_ACCEPT_REPORT_DELAY_ROLE");
    bytes32 public constant SET_MAX_ACCEPT_REPORT_DELAY_ROLE = keccak256("SET_MAX_ACCEPT_REPORT_DELAY_ROLE");
    bytes32 public constant SET_MAX_DRAWDOWN_ROLE = keccak256("SET_MAX_DRAWDOWN_ROLE");
    bytes32 public constant EMERGENCY_PAUSE_ROLE = keccak256("EMERGENCY_PAUSE_ROLE");
    bytes32 public constant SET_WHITELIST_ROLE = keccak256("SET_WHITELIST_ROLE");
    bytes32 public constant CANCEL_DEPOSIT_REQUEST_ROLE = keccak256("CANCEL_DEPOSIT_REQUEST_ROLE");
    bytes32 public constant CANCEL_REDEEM_REQUEST_ROLE = keccak256("CANCEL_REDEEM_REQUEST_ROLE");
}
