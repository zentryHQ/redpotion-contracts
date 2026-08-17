# FeeManager

> Source: [`src/FeeManager.sol`](../src/FeeManager.sol)

## Responsibility

`FeeManager` holds the fund's **fee configuration and fee accounting state**, and computes fee accrual at each settlement. It never holds assets or mints shares itself — it returns amounts and recipients, and the [Fund](Fund.md) does the minting.

All fees are paid **in newly minted shares** (diluting existing holders) rather than in assets:

| Fee | When it accrues | Formula | Paid to |
|---|---|---|---|
| **Entry fee** | Deposit batch settlement | `totalShares * entryFeeBps / 10000` withheld from minted shares | `feeRecipient` |
| **Exit fee** | Redeem batch settlement | `redeemShares * exitFeeBps / 10000` re-minted; payout uses net shares | `feeRecipient` |
| **Management fee** | Report acceptance (time-based) | `totalSupply * managementFeeBps * elapsed / (10000 * 365 days)` | `feeRecipient` |
| **Performance fee** | Report acceptance, only above high-water mark | `totalSupply * (price - HWM) * performanceFeeBps / (price * 10000)` | `feeRecipient` |
| **Protocol fee** | Report acceptance (time-based, same shape as management) | `totalSupply * protocolFeeBps * elapsed / (10000 * 365 days)` | protocol fee recipient, resolved live via `Fund → FundManager → FundManagerDeployer` |

Notes:

- **High-water mark (HWM)**: tracked on the fee-base-asset share price. First accrual initializes it to the reported price; afterwards, performance fee only accrues when the new price exceeds the HWM, and the HWM ratchets up to the new price.
- **Fee base asset**: management/performance/protocol fees accrue on the base asset's report, which is why the Fund always includes `feeBaseAsset` in the reported asset set.
- **Protocol fee recipient is not stored here** — it is read from the [FundManagerDeployer](FundManagerDeployer.md) at accrual time, so a protocol-wide migration only needs one pointer flip. If the resolved recipient is zero, the protocol fee is skipped.
- **Fee changes are batch-staged**: `setFeeConfig` never touches a batch already open for requests. The new config is staged to take effect from the **next batch to open** (`currentBatchId + 1`) and is promoted to the active config during that boundary's settlement — so every request settles at the fee config it was quoted when submitted. Restaging for the same boundary overwrites the staged entry.
- All bps values are capped at 10000 (100%).

Admin functions authorize against the **Fund's** access control (spoke pattern).

## Function reference

### Fund-only

| Function | Access | Description |
|---|---|---|
| `accrueFees(totalSupply, newPrice, batchId)` | `onlyFund` | Computes management, performance, and protocol fee shares since `lastFeeAccrual`, updates HWM and `lastFeeAccrual`, and returns `(recipient, feeShares, protocolRecipient, protocolFeeShares)` for the Fund to mint. Called once per accepted report, on the fee base asset. `batchId` is the batch being settled; after accrual, staged fee configs effective from `batchId + 1` are promoted to active. |

### Admin setters (roles checked on the Fund)

| Function | Role | Description |
|---|---|---|
| `setFeeConfig(config)` | `SET_FEES_ROLE` | Stage all five bps values at once (`entry`, `exit`, `management`, `performance`, `protocol`), each ≤ 10000. Takes effect from the **next batch to open**, never the batch already accepting requests (see note above). Emits `FeeConfigPending`. |
| `setFeeRecipient(addr)` | `SET_FEE_RECIPIENT_ROLE` | Where fund-level fee shares are minted. Non-zero. |
| `setFeeBaseAsset(asset)` | `SET_FEE_BASE_ASSET_ROLE` | The asset whose reported price drives HWM/mgmt/perf/protocol accrual and risk valuation. Non-zero. Changing it **resets the high-water mark** (the old HWM is denominated in the old asset); the next accrual seeds a fresh HWM at the new asset's price. |

### Views

| Function | Description |
|---|---|
| `getFeeConfig()` | The **active** config: all five bps values as a struct. |
| `getFeeConfigForBatch(batchId)` | The config a request in `batchId` settles at: the latest staged config effective at or before `batchId`, else the active config. |
| `getPendingFeeConfigs()` | Staged fee changes not yet promoted, ordered by `effectiveBatchId`. |
| `entryFeeBps` / `exitFeeBps` / `managementFeeBps` / `performanceFeeBps` / `protocolFeeBps` | Individual bps values. |
| `feeBaseAsset` / `feeRecipient` | Config addresses. |
| `highWaterMark` | Current HWM (0 until first performance-fee accrual). |
| `lastFeeAccrual` | Timestamp of the last accrual (initialized at deployment). |
| `fund()` | The bound Fund. |
