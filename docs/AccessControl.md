# Access Control & Roles

> Sources: [`src/modules/ACLModule.sol`](../src/modules/ACLModule.sol) · [`src/modules/FundRoles.sol`](../src/modules/FundRoles.sol) · [`src/modules/FundSpokeACLModule.sol`](../src/modules/FundSpokeACLModule.sol) · [`src/modules/FundACLModule.sol`](../src/modules/FundACLModule.sol) · [`src/modules/FundManagerACLModule.sol`](../src/modules/FundManagerACLModule.sol) · [`src/modules/StrategyACLModule.sol`](../src/modules/StrategyACLModule.sol)

## The two auth patterns

### 1. Local ACL (`ACLModule`)

OpenZeppelin `AccessControlEnumerable` + `Multicall`, plus batch `grantRoles`/`revokeRoles` (admin-only) and constructor-time role seeding via `RoleHolder[] {role, account}`. Used directly by contracts that own their role state:

| Contract | Role constants module |
|---|---|
| [Fund](Fund.md) | `FundACLModule` (= `ACLModule` + `FundRoles`) |
| [FundManager](FundManager.md) | `FundManagerACLModule` |
| [FundManagerDeployer](FundManagerDeployer.md) | roles declared inline |
| [Strategy](Strategy.md) / [StandaloneStrategy](StandaloneStrategy.md) | `StrategyACLModule` (+ `CallValidatorModule` roles) |
| [StandaloneStrategyDeployer](StandaloneStrategy.md#standalonestrategydeployer) | roles declared inline |

### 2. Spoke callback ACL (`FundSpokeACLModule`)

The fund spokes ([DepositQueue](DepositQueue.md), [RedeemQueue](RedeemQueue.md), [Oracle](Oracle.md), [FeeManager](FeeManager.md), [RiskManager](RiskManager.md)) hold **no role state of their own**. Their `onlyRole(ROLE)` modifier calls back to the Fund:

```solidity
if (!IAccessControl(_fund()).hasRole(role, msg.sender)) revert UnauthorizedRole();
```

So **all roles for a fund and its five spokes are granted/revoked in one place: the Fund contract** (`fund.grantRoles(...)` by the fund's `DEFAULT_ADMIN_ROLE`). Role name constants live in `FundRoles`, inherited by both Fund and spokes so identifiers always match.

## Fund role table (`FundRoles`)

All identifiers are `keccak256("<NAME>")`. Enforced-by shows where the guarded function lives.

| Role | Enforced by | Grants ability to |
|---|---|---|
| `DEFAULT_ADMIN_ROLE` (`0x00`) | Fund | Grant/revoke every other role. |
| `ACCEPT_REPORT_ROLE` | Fund | `acceptReport` — accept prices & settle batches. |
| `ACCEPT_SUSPICIOUS_REPORT_ROLE` | Fund | `acceptSuspiciousReport` — settle despite suspicious price flags. |
| `FUND_REDEEM_ROLE` | Fund | `fundRedeem` — deliver assets to settled redeem batches. |
| `CREATE_STRATEGY_ROLE` | Fund | `createStrategy`. |
| `ADD_STRATEGY_ROLE` / `REMOVE_STRATEGY_ROLE` | Fund | Manage the strategy registry. |
| `PUSH_TO_STRATEGY_ROLE` / `PULL_FROM_STRATEGY_ROLE` | Fund | Move assets Fund ↔ strategies. |
| `ADD_EXTERNAL_WALLET_ROLE` / `REMOVE_EXTERNAL_WALLET_ROLE` / `PUSH_TO_WALLET_ROLE` | Fund | Manage the external-wallet whitelist and push assets to it. |
| `SUBMIT_REPORT_ROLE` | Oracle | `submitReport` — post batch prices. |
| `REJECT_REPORT_ROLE` | Oracle | `rejectReport` — veto pending prices. |
| `SET_PRICE_SAFETY_ROLE` | Oracle | Configure suspicious-price bounds. |
| `SET_NEXT_CUTOFF_TIME_ROLE` | Oracle | Move the batch cutoff. |
| `SET_MIN_ACCEPT_REPORT_DELAY_ROLE` / `SET_MAX_ACCEPT_REPORT_DELAY_ROLE` | Oracle | Tune the accept window. |
| `SET_FEES_ROLE` | FeeManager | `setFeeConfig` (all five fee bps). |
| `SET_FEE_RECIPIENT_ROLE` | FeeManager | `setFeeRecipient`. |
| `SET_FEE_BASE_ASSET_ROLE` | FeeManager | `setFeeBaseAsset`. |
| `SET_DEPOSIT_ALLOWED_ASSETS_ROLE` | DepositQueue | `setAllowedAssets`. |
| `PAUSE_DEPOSIT_ROLE` / `UNPAUSE_DEPOSIT_ROLE` | DepositQueue | Global & per-asset pause. |
| `CANCEL_DEPOSIT_REQUEST_ROLE` | DepositQueue | `adminCancelDeposit`. |
| `PULL_DEPOSIT_ASSET_ROLE` | DepositQueue | `pullAsset` (queue → Fund). |
| `SET_REDEEM_ALLOWED_ASSETS_ROLE` | RedeemQueue | `setAllowedAssets`. |
| `PAUSE_REDEEM_ROLE` / `UNPAUSE_REDEEM_ROLE` | RedeemQueue | Global & per-asset pause. |
| `CANCEL_REDEEM_REQUEST_ROLE` | RedeemQueue | `adminCancelRedeem`. |
| `PULL_REDEEM_ASSET_ROLE` | RedeemQueue | `pullAsset` (queue → Fund). |
| `SET_CANCEL_LOCK_WINDOW_ROLE` | DepositQueue & RedeemQueue | `setCancelLockWindow` — how long before each batch cutoff public cancellation freezes. |
| `SET_TVL_CAP_ROLE` | RiskManager | `setTvlCap`. |
| `SET_BATCH_CAPS_ROLE` | RiskManager | `setMaxBatchDepositCap` / `setMaxBatchRedeemCap`. |
| `SET_MIN_DEPOSIT_AMOUNT_ROLE` / `SET_MIN_REDEEM_AMOUNT_ROLE` | RiskManager | Minimum request sizes. |
| `SET_MAX_DRAWDOWN_ROLE` | RiskManager | `setMaxDrawdown`. |
| `SET_WHITELIST_ROLE` | RiskManager | `setMerkleRoot` (depositor whitelist). |
| `EMERGENCY_PAUSE_ROLE` | RiskManager | `emergencyPause` / `emergencyUnpause`. |

## Other role tables

**FundManager** (`FundManagerACLModule`): `CREATE_FUND_ROLE`, plus one `SET_<COMPONENT>_FACTORY_ROLE` per component (fund, share, deposit queue, redeem queue, oracle, fee manager, risk manager, strategy) guarding both `set<Component>Factory` and `set<Component>Implementation`.

**FundManagerDeployer**: `CREATE_FUND_MANAGER_ROLE`, `SET_IMPLEMENTATIONS_ROLE`, `SET_PROTOCOL_FEE_RECIPIENT_ROLE`.

**Strategy / StandaloneStrategy** (`StrategyACLModule` + `CallValidatorModule`): `CALLER_ROLE` (execute allowlisted calls), `ADD_ALLOWED_CALL_ROLE`, `REMOVE_ALLOWED_CALL_ROLE`.

**StandaloneStrategyDeployer**: `CREATE_STRATEGY_ROLE`, `SET_IMPLEMENTATION_ROLE`.

## Upgrade authority (separate from roles)

Every contract is a `TransparentUpgradeableProxy`; upgrade rights belong to whoever owns each proxy's auto-deployed **ProxyAdmin** — the `proxyAdmin` address chosen at tenant/fund creation (see [FundManagerDeployer](FundManagerDeployer.md) and [Factory](Factory.md)). Roles govern behavior; ProxyAdmin ownership governs code.
