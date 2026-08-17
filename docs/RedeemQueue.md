# RedeemQueue

> Source: [`src/RedeemQueue.sol`](../src/RedeemQueue.sol)

## Responsibility

`RedeemQueue` is the **user entrypoint for redeeming fund shares back into assets**. Like deposits, redemptions are batched: users lock shares into the current batch, the batch is priced when the oracle report is accepted, and payouts become claimable once the Fund **funds** the batch with assets.

Redemption has one more stage than deposits because the fund's assets may be deployed in strategies at settlement time — settling a batch fixes *how much* is owed, while funding (a separate, role-gated Fund action) actually delivers the assets.

Admin functions authorize against the **Fund's** access control (spoke pattern — see [AccessControl.md](AccessControl.md)).

## Redeem lifecycle

```mermaid
stateDiagram-v2
    [*] --> Pending: redeem(asset, shares)
    Pending --> [*]: cancelRedeem / adminCancelRedeem (shares returned)
    Pending --> Settled: Fund.acceptReport → settleRedeem (payout snapshotted)
    Settled --> Funded: Fund.fundRedeem (assets arrive)
    Funded --> [*]: claimRedeem (receive assets)
```

1. **Request** — user calls `redeem`, choosing which allowed asset they want to be paid in. Shares are transferred into the queue (requires prior ERC20 approval of the share token). `Fund.checkRedeem` → [RiskManager](RiskManager.md) enforces minimums and batch caps. A user may redeem into the same asset multiple times in a batch — repeat submissions **accumulate into a single request** per (asset, batch, user) and refresh its timestamp, since everything in a batch settles at the same price anyway.
2. **Cancel** — the user can cancel their current-batch request and get their shares back, except inside the optional **cancel-lock window** (`cancelLockWindow`) just before the batch cutoff — this prevents reserving batch cap and cancelling for free in the final blocks. An admin (`CANCEL_REDEEM_REQUEST_ROLE`) can cancel any request in any unsettled batch. If a closed batch stays unsettled for **30 days past its cutoff** (`FORCE_CANCEL_DELAY`, matching the oracle's hard cap on the accept window), the request owner can `forceCancelRedeem` to reclaim their escrowed shares with no operator involvement — deliberately usable even while the queue is paused.
3. **Settle** — during `Fund.acceptReport`, `settleRedeem` transfers the batch's shares to the Fund (which burns them) and **snapshots the asset payout** (`batchAssetTotals`) computed at the accepted price minus exit fee. Because the payout is snapshotted here, later admin changes to exit fee or price cannot change what the batch is owed. The batch is tracked as *settled-but-unfunded*.
4. **Fund** — the operator first brings assets back to the Fund (either the Fund pulls them from strategy contracts via `Fund.pullAssetFromStrategy`, or external wallets / bridges transfer them back to the Fund address), then `FUND_REDEEM_ROLE` calls `Fund.fundRedeem(asset, batchId)`, which transfers the snapshotted amount to the queue and calls `fundRedeem` here, marking the batch claimable.
5. **Claim** — user calls `claimRedeem` and receives `shares * batchAssetTotals / batchRedeemTotals` (pro-rata).

## Function reference

### User actions

| Function | Access | Description |
|---|---|---|
| `redeem(asset, shares)` | anyone | Queue a redemption into the current batch, paid out in `asset`. Transfers `shares` of the fund share token into the queue. Reverts if asset not allowed/paused or shares 0. Repeat redemptions in the same batch accumulate into the existing request. |
| `cancelRedeem(asset)` | request owner | Cancel own current-batch request; shares returned. Reverts (`CancelLocked`) inside the cancel-lock window before the batch cutoff. |
| `forceCancelRedeem(asset)` | request owner | Escape hatch for a stuck batch: once the settling batch is ≥ `FORCE_CANCEL_DELAY` (30 days) past its cutoff and still unsettled, returns the caller's escrowed shares. Not blocked by pausing. |
| `claimRedeem(asset, batchId)` | request owner | Claim pro-rata assets once the batch is funded. |

### Fund actions

| Function | Access | Description |
|---|---|---|
| `settleRedeem(asset, batchId, assetAmount)` | `onlyFund` | Transfers the batch's shares to the Fund for burning, snapshots `batchAssetTotals[asset][batchId] = assetAmount`, and adds the batch to the unfunded set. No-op bookkeeping if the batch had no requests. |
| `fundRedeem(asset, batchId)` | `onlyFund` | Marks a settled batch as funded (assets were already transferred in by the Fund in the same transaction). Reverts if not settled or already funded. |

### Admin (roles checked on the Fund)

| Function | Role | Description |
|---|---|---|
| `setAllowedAssets(assets[])` | `SET_REDEEM_ALLOWED_ASSETS_ROLE` | Replace the allowed payout-asset list. Reverts if a removed asset has pending requests in the current batch **or in a closed-but-unsettled previous batch** (removal would strand those escrowed shares). |
| `pause()` / `unpause()` | `PAUSE_REDEEM_ROLE` / `UNPAUSE_REDEEM_ROLE` | Global pause — blocks `redeem`, `cancelRedeem`, `claimRedeem`. |
| `pauseAssets(assets[])` / `unpauseAssets(assets[])` | `PAUSE_REDEEM_ROLE` / `UNPAUSE_REDEEM_ROLE` | Per-asset pause for new redemption requests. |
| `adminCancelRedeem(asset, batchId, user)` | `CANCEL_REDEEM_REQUEST_ROLE` | Cancel any user's request in any unsettled batch; shares returned to the user. |
| `setCancelLockWindow(window)` | `SET_CANCEL_LOCK_WINDOW_ROLE` | How long before each batch cutoff public cancellation freezes. Zero (default) disables the lock. |
| `pullAsset(asset, amount)` | `PULL_REDEEM_ASSET_ROLE` | Escape hatch: transfer assets from the queue back to the Fund. |

### Views

| Function | Description |
|---|---|
| `getAllowedAssets()` / `getAssetStatuses()` | Allowed payout assets (+ pause flags). |
| `getRedeemRequest(asset, batchId, investor)` | A single request (`shares`, `timestamp`). |
| `getPendingRedeems(investor)` | The investor's current-batch requests. |
| `getClaimableRedeems(investor)` | The investor's requests in past, **funded** batches. |
| `getUnfundedBatches()` | All settled (asset, batchId) pairs still awaiting `fundRedeem` — the operator's to-do list. |
| `batchRedeemTotals(asset, batchId)` | Total shares queued per asset per batch. |
| `batchAssetTotals(asset, batchId)` | Snapshotted payout per asset per batch (set at settlement). |
| `isBatchFunded(asset, batchId)` | Whether a batch is claimable. |
| `cancelLockWindow()` | Current cancel-lock window in seconds (0 = disabled). |
| `FORCE_CANCEL_DELAY` | Constant, 30 days — how long a batch must sit unsettled past its cutoff before `forceCancelRedeem` opens. |
| `isAssetPaused(asset)` / `fund()` | Pause flag / bound Fund. |
