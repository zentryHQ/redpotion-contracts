# FundShare

> Source: [`src/FundShare.sol`](../src/FundShare.sol)

## Responsibility

`FundShare` is the **ERC20 share token** of a fund. One FundShare is deployed per fund, with 18 decimals (OZ default). Holding shares represents a pro-rata claim on the fund's assets at the oracle-reported price.

It is deliberately minimal: a standard `ERC20Upgradeable` where **only the Fund can mint and burn**. All supply changes happen inside the Fund's settlement flow:

- **Minted** to the DepositQueue (user shares) and to fee recipients (entry/exit/management/performance/protocol fee shares) during `Fund.acceptReport`.
- **Burned** from the Fund's own balance when redeem batches settle (the RedeemQueue transfers the batch's shares to the Fund first).

Shares are freely transferable ERC20s; users receive them by calling `DepositQueue.claimDeposit` after their batch settles.

## Flow

```
deposit settle:   Fund → mint(DepositQueue, userShares), mint(feeRecipient, feeShares)
user claim:       DepositQueue → transfer(user, proRataShares)
redeem request:   user → transferFrom(user, RedeemQueue, shares)
redeem settle:    RedeemQueue → transfer(Fund, batchShares); Fund → burn(Fund, batchShares)
```

## Function reference

| Function | Access | Description |
|---|---|---|
| `initialize(name, symbol, fund)` | initializer (called by FundManager during `createFund`) | Sets ERC20 metadata and binds the Fund. `fund` cannot be zero. |
| `mint(to, amount)` | `onlyFund` | Mints shares. Used exclusively by settlement/fee accrual. |
| `burn(from, amount)` | `onlyFund` | Burns shares. Used when redeem batches settle. |
| `fund()` | view | The bound Fund address. |
| `totalSupply` / `balanceOf` / `transfer` / `approve` / `allowance` / `transferFrom` | standard ERC20 | Standard OZ ERC20 behavior (overridden only to resolve interface ambiguity with `IFundShare`). |

## Errors

| Error | When |
|---|---|
| `OnlyFund` | `mint`/`burn` called by anyone other than the Fund. |
| `ZeroAddress` | `initialize` with zero fund address. |
