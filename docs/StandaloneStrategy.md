# StandaloneStrategy & StandaloneStrategyDeployer

> Sources: [`src/StandaloneStrategy.sol`](../src/StandaloneStrategy.sol) · [`src/StandaloneStrategyDeployer.sol`](../src/StandaloneStrategyDeployer.sol)

## StandaloneStrategy

### Responsibility

`StandaloneStrategy` is the same **allowlisted-call execution wallet** as [Strategy](Strategy.md), but **not controlled by a Fund**. Its purpose is to **deploy fund strategies on a different chain than the Fund itself**: the Fund (and the rest of the fund instance) lives on the home chain, while a StandaloneStrategy executes on another chain where the target protocols live. Assets are moved between the Fund and the strategy by bridging (operationally, outside these contracts), and the results are reflected back into the fund's NAV through the [Oracle](Oracle.md)'s price reports.

Because the Fund does not exist on the strategy's chain, there is no `onlyFund` control — the strategy has its own admin, and the `fund` field is just an optional reference. It reuses the identical `CallValidatorModule` allowlist machinery and `CALLER_ROLE` execution interface; the differences are in who controls the assets:

| | [Strategy](Strategy.md) | StandaloneStrategy |
|---|---|---|
| Deployed by | `Fund.createStrategy` → FundManager | [`StandaloneStrategyDeployer`](#standalonestrategydeployer) |
| Chain | Same chain as the Fund | **Any chain** — typically not the Fund's chain |
| `fund` field | Required, enforces `onlyFund` on `pullAsset` | Optional reference — may be zero (**orphan**), since the Fund usually doesn't exist on this chain; when set, it's only used to forbid calling that address via `call` |
| Asset recovery | `pullAsset(asset, amount)` — **only the Fund**, assets always return to the Fund | `pullAsset(asset, to, amount)` — **strategy admin** (`DEFAULT_ADMIN_ROLE`), to any address (e.g. a bridge or the Fund's address on the home chain) |
| Registered in `Fund.isStrategy` | Yes (push/pull integration) | No |
| Asset in/out | `Fund.pushAssetToStrategy` / `pullAssetFromStrategy` | Bridged/transferred externally |

### Function reference

| Function | Access | Description |
|---|---|---|
| `initialize(fund, admin, roleHolders[])` | initializer (via deployer) | Sets the optional fund reference and the strategy's own ACL. `admin` must be non-zero. |
| `call(target, data)` | `CALLER_ROLE` (payable) | Execute an allowlisted call. Same rules as Strategy: target must not be the referenced fund, selector must be allowlisted for this caller. |
| `call(target, data, constrainedOffsets, constrainedValues)` | `CALLER_ROLE` (payable) | Constrained variant — verifies pinned calldata words (see [Strategy](Strategy.md#call-allowlisting-callvalidatormodule)). |
| `pullAsset(asset, to, amount)` | `DEFAULT_ADMIN_ROLE` | Withdraw any asset to any non-zero address. |
| `addCalls` / `removeCalls` / `addConstrainedCalls` / `removeConstrainedCalls` | `ADD_ALLOWED_CALL_ROLE` / `REMOVE_ALLOWED_CALL_ROLE` | Allowlist management, identical to Strategy. |
| `fund()` / `getAllowedCalls()` / `getCallHash(...)` etc. | view | Same views as Strategy. |
| `receive()` | anyone | Accepts ETH. |

## StandaloneStrategyDeployer

### Responsibility

`StandaloneStrategyDeployer` is the **root deployer for standalone strategies** — a slimmed-down analog of [FundManagerDeployer](FundManagerDeployer.md), deployed on each **strategy chain** (the chains where funds execute remotely, without the rest of the protocol stack). It owns a single [Factory](Factory.md) that stamps out `StandaloneStrategy` proxies, and keeps a registry of everything it deployed.

It has its own `ACLModule` access control (independent of any fund).

### Function reference

| Function | Access | Description |
|---|---|---|
| `initialize(admin, standaloneStrategyFactory, roleHolders[])` | initializer | Sets the admin and the factory. |
| `setStrategyImplementation(strategyImpl)` | `SET_IMPLEMENTATION_ROLE` | Pushes a new strategy implementation into the factory (future deploys use it; existing proxies are upgraded separately via their ProxyAdmin). |
| `createStandaloneStrategy(fund, admin, proxyAdmin, roleHolders[])` | `CREATE_STRATEGY_ROLE` | Deploys a new StandaloneStrategy proxy via `factory.createFor` with `proxyAdmin` as the ProxyAdmin owner (upgrade authority, chosen per strategy) and initializes it. `fund` may be zero. |
| `strategyCount()` / `strategyAt(i)` / `isStrategy(addr)` | view | Registry, backed by the factory's entity list. |
| `standaloneStrategyFactory` | view | The bound factory. |
