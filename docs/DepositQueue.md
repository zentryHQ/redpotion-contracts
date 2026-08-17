# DepositQueue

> Source: [`src/DepositQueue.sol`](../src/DepositQueue.sol)

## Responsibility

`DepositQueue` is the **user entrypoint for depositing into a fund**. Deposits are not instant — they are queued into the current **batch** and converted to shares only when the batch's oracle report is accepted (see [Oracle](Oracle.md) for batch semantics). This gives every depositor in a batch the same execution price and lets the operator screen prices before settlement.

It supports multiple deposit assets (ERC20s and native ETH via the `0xEeee…EEeE` sentinel), per-asset and global pausing, cancellation before settlement, and pro-rata claiming after settlement.

Admin functions authorize against the **Fund's** access control (spoke pattern — see [AccessControl.md](AccessControl.md)).

## Deposit lifecycle

```mermaid
stateDiagram-v2
    [*] --> Pending: deposit(asset, amount, proof)
    Pending --> [*]: cancelDeposit / adminCancelDeposit (refund)
    Pending --> Settled: Fund.acceptReport → settleDeposit
    Settled --> [*]: claimDeposit (receive shares)
```

1. **Request** — user calls `deposit`. The queue asks the Fund for the current batch id, runs `Fund.checkDeposit` → [RiskManager](RiskManager.md) (whitelist, caps, minimums), then escrows the assets. A user may deposit the same asset multiple times in a batch — repeat submissions **accumulate into a single request** per (asset, batch, user) and refresh its timestamp, since everything in a batch settles at the same price anyway.
2. **Cancel** — the user can cancel their **current-batch** request for a full refund, except inside the optional **cancel-lock window** (`cancelLockWindow`) just before the batch cutoff — this prevents reserving batch cap and cancelling for free in the final blocks. An admin (`CANCEL_DEPOSIT_REQUEST_ROLE`) can cancel any user's request in any *unsettled* batch (e.g. stuck past batches). If a closed batch stays unsettled for **30 days past its cutoff** (`FORCE_CANCEL_DELAY`, matching the oracle's hard cap on the accept window), the request owner can `forceCancelDeposit` to reclaim their assets with no operator involvement — deliberately usable even while the queue is paused.
3. **Settle** — during `Fund.acceptReport` the Fund mints the batch's user shares *to the queue* and calls `settleDeposit`, which transfers all escrowed assets of that batch to the Fund.
4. **Claim** — the user calls `claimDeposit` and receives `depositAmount * batchShareTotals / batchDepositTotals` (pro-rata share of the batch mint). No deadline; claims stay available indefinitely.

## Function reference

### User actions

| Function | Access | Description |
|---|---|---|
| `deposit(asset, amount, proof)` | anyone (payable) | Queue a deposit into the current batch. `proof` is the merkle whitelist proof (empty if no whitelist configured). For ETH, `msg.value` must equal `amount`; for ERC20s, `msg.value` must be 0 and the queue pulls via `transferFrom`. Reverts if asset not allowed, asset or queue paused, or amount 0. Repeat deposits in the same batch accumulate into the existing request. |
| `cancelDeposit(asset)` | request owner | Cancel own current-batch request, full refund. Reverts (`CancelLocked`) inside the cancel-lock window before the batch cutoff. |
| `forceCancelDeposit(asset)` | request owner | Escape hatch for a stuck batch: once the settling batch is ≥ `FORCE_CANCEL_DELAY` (30 days) past its cutoff and still unsettled, refunds the caller's request. Not blocked by pausing. |
| `claimDeposit(asset, batchId)` | request owner | Claim pro-rata shares after the batch is settled. |

### Fund actions

| Function | Access | Description |
|---|---|---|
| `settleDeposit(asset, batchId, sharesToMint)` | `onlyFund` | Marks the batch settled, records `batchShareTotals` for pro-rata claims, and transfers all escrowed assets of the batch to the Fund. Reverts if already settled. |

### Admin (roles checked on the Fund)

| Function | Role | Description |
|---|---|---|
| `setAllowedAssets(assets[])` | `SET_DEPOSIT_ALLOWED_ASSETS_ROLE` | Replaces the allowed-asset list. Reverts if a removed asset still has pending requests in the current batch **or in a closed-but-unsettled previous batch** (removal would strand those deposits). Duplicates and zero addresses rejected. |
| `pause()` / `unpause()` | `PAUSE_DEPOSIT_ROLE` / `UNPAUSE_DEPOSIT_ROLE` | Global pause — blocks `deposit`, `cancelDeposit`, and `claimDeposit`. |
| `pauseAssets(assets[])` / `unpauseAssets(assets[])` | `PAUSE_DEPOSIT_ROLE` / `UNPAUSE_DEPOSIT_ROLE` | Per-asset pause — blocks new deposits of those assets only. |
| `adminCancelDeposit(asset, batchId, user)` | `CANCEL_DEPOSIT_REQUEST_ROLE` | Cancel any user's request in any unsettled batch; assets are refunded to the user. |
| `setCancelLockWindow(window)` | `SET_CANCEL_LOCK_WINDOW_ROLE` | How long before each batch cutoff public cancellation freezes. Zero (default) disables the lock. |
| `pullAsset(asset, amount)` | `PULL_DEPOSIT_ASSET_ROLE` | Escape hatch: transfer assets from the queue to the Fund (e.g. tokens sent by mistake). Always sends to the Fund, never an arbitrary address. |

### Views

| Function | Description |
|---|---|
| `getAllowedAssets()` | Current allowed deposit assets. |
| `getAssetStatuses()` | Allowed assets with their per-asset pause flag. |
| `getDepositRequest(asset, batchId, investor)` | A single request (`amount`, `timestamp`). |
| `getPendingDeposits(investor)` | The investor's requests in the **current** batch. |
| `getClaimableDeposits(investor)` | The investor's requests in past, **settled** batches (claimable now). |
| `batchDepositTotals(asset, batchId)` | Total deposited per asset per batch (public mapping). |
| `batchShareTotals(asset, batchId)` | Total shares minted for the batch (set at settlement). |
| `isAssetPaused(asset)` | Per-asset pause flag. |
| `cancelLockWindow()` | Current cancel-lock window in seconds (0 = disabled). |
| `FORCE_CANCEL_DELAY` | Constant, 30 days — how long a batch must sit unsettled past its cutoff before `forceCancelDeposit` opens. |
| `fund()` | The bound Fund. |
