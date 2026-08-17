# RiskManager

> Source: [`src/RiskManager.sol`](../src/RiskManager.sol)

## Responsibility

`RiskManager` enforces **deposit/redeem guardrails** for a fund. Both queues route every user request through `Fund.checkDeposit` / `Fund.checkRedeem`, which the Fund proxies here; a violated limit reverts the whole request.

All value comparisons are made **in the fee base asset**: a deposit of asset X is valued at `value = amount * basePrice / assetPrice`, computed as a single full-precision division (a two-step share round-trip would floor twice and reject deposits worth exactly the minimum). The valuation context comes from `Fund.getRiskContext` (see [Fund](Fund.md)).

Every limit is **optional — a zero value disables that check**. If no valuation-based check is enabled, price lookups are skipped entirely (deposits then work even without prices, e.g. the very first batch).

| Control | Check applied |
|---|---|
| `isEmergencyPaused` | Blocks **all** deposits and redemptions immediately. |
| `merkleRoot` (whitelist) | Depositor must prove membership: leaf = `keccak256(keccak256(abi.encode(depositor)))` (OZ double-hash). Deposits only. |
| `maxDrawdownBps` | Blocks deposits when the base price has fallen more than this far below the high-water mark (protects new depositors from entering a drawdown, and existing holders from dilution at depressed prices). |
| `minDepositAmount` / `minRedeemAmount` | Minimum request size, valued in the base asset. |
| `maxBatchDepositCap` / `maxBatchRedeemCap` | Cap on total value queued per batch (existing batch total + this request). |
| `tvlCap` | Cap on fund TVL (`shareSupply * basePrice / 1e18` + the current batch's already-queued deposits + this deposit). Deposits only. |

Note: checks run at **request time** against `lastAcceptedPrice`; the batch itself settles at the *next* accepted price.

Admin functions authorize against the **Fund's** access control (spoke pattern).

## Function reference

### Validation (view, called via Fund)

| Function | Description |
|---|---|
| `checkDeposit(depositor, asset, batchId, amount, proof)` | Runs, in order: emergency pause → merkle whitelist → drawdown → min deposit → batch deposit cap → TVL cap. Reverts with a specific error on the first violation (`EmergencyPausedError`, `NotWhitelisted`, `DrawdownBreached`, `DepositBelowMinimum`, `BatchDepositCapExceeded`, `TvlCapExceeded`, `BaseAssetPriceUnavailable`, `DepositAssetPriceUnavailable`). |
| `checkRedeem(batchId, shares)` | Runs: emergency pause → min redeem → batch redeem cap (`RedeemBelowMinimum`, `BatchRedeemCapExceeded`). |

### Estimates (frontend helpers)

| Function | Description |
|---|---|
| `estimateDeposit(asset, amount)` | Shares the user would receive at current prices after entry fee. Returns 0 if no price. |
| `estimateRedeem(asset, shares)` | Assets the user would receive at current prices after exit fee. Returns 0 if no price. |
| `getMinDepositAmount(asset)` | Smallest `asset` amount that passes the minimum-deposit check at current prices (rounded up; 0 if no minimum configured). |
| `getMinRedeemShares()` | Smallest share amount that passes the minimum-redeem check at the current base price (rounded up; 0 if no minimum configured). |

Both are estimates only — actual settlement uses the next accepted report's price.

### Admin setters (roles checked on the Fund; 0 disables a check)

| Function | Role | Description |
|---|---|---|
| `setTvlCap(cap)` | `SET_TVL_CAP_ROLE` | Max TVL in base-asset value. |
| `setMaxBatchDepositCap(cap)` / `setMaxBatchRedeemCap(cap)` | `SET_BATCH_CAPS_ROLE` | Per-batch value caps. |
| `setMinDepositAmount(amount)` | `SET_MIN_DEPOSIT_AMOUNT_ROLE` | Minimum deposit value. |
| `setMinRedeemAmount(amount)` | `SET_MIN_REDEEM_AMOUNT_ROLE` | Minimum redemption value. |
| `setMaxDrawdown(bps)` | `SET_MAX_DRAWDOWN_ROLE` | Max drawdown below HWM before deposits are blocked (≤ 10000). |
| `setMerkleRoot(root)` | `SET_WHITELIST_ROLE` | Depositor whitelist root (`bytes32(0)` disables). |
| `emergencyPause()` / `emergencyUnpause()` | `EMERGENCY_PAUSE_ROLE` | Instant kill switch for deposits and redemptions. |

### Views

`tvlCap`, `maxBatchDepositCap`, `maxBatchRedeemCap`, `minDepositAmount`, `minRedeemAmount`, `maxDrawdownBps`, `isEmergencyPaused`, `merkleRoot`, `fund()` — all public state.
