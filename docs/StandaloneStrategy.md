# StandaloneStrategy & StandaloneStrategyDeployer

> Sources: [`src/StandaloneStrategy.sol`](../src/StandaloneStrategy.sol) · [`src/StandaloneStrategyDeployer.sol`](../src/StandaloneStrategyDeployer.sol)

## StandaloneStrategy

### Responsibility

`StandaloneStrategy` is the same **allowlisted-call execution wallet** as [Strategy](Strategy.md), but **not controlled by a Fund**. Its purpose is to **deploy fund strategies on a different chain than the Fund itself**: the Fund (and the rest of the fund instance) lives on the home chain, while a StandaloneStrategy executes on another chain where the target protocols live. Assets are moved between the Fund and the strategy by bridging (operationally, outside these contracts), and the results are reflected back into the fund's NAV through the [Oracle](Oracle.md)'s price reports.

Because the Fund does not exist on the strategy's chain, there is no `onlyFund` control — the strategy has its own admin, and the `fund` field is just an optional reference. It reuses the identical `CallValidatorModule` allowlist machinery and `CALLER_ROLE` execution interface; the differences are in who controls the assets:

| | [Strategy](Strategy.md) | StandaloneStrategy |
|---|---|---|
| Deployed by | `Fund.createStrategy` → FundManager | [`StandaloneStrategyDeployer`](#standalonestrategydeployer) |
| `fund` field | Required, enforces `onlyFund` on `pullAsset` | Optional reference — may be zero, i.e. the strategy can be deployed **orphaned** with no fund at all; when set, it's only used to forbid calling the fund via `call` |
| Asset recovery | `pullAsset(asset, amount)` — **only the Fund**, assets always return to the Fund | `pullAsset(asset, to, amount)` — **strategy admin** (`DEFAULT_ADMIN_ROLE`), to any address |
| Registered in `Fund.isStrategy` | Yes (push/pull integration) | No |

Use it for managed execution wallets that operate independently of the fund lifecycle (e.g. proprietary trading wallets with call-level guardrails), while keeping the same operational tooling as fund strategies.

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

`StandaloneStrategyDeployer` is the **root deployer for standalone strategies** — a slimmed-down analog of [FundManagerDeployer](FundManagerDeployer.md). It owns a single [Factory](Factory.md) that stamps out `StandaloneStrategy` proxies, and keeps a registry of everything it deployed.

It has its own `ACLModule` access control (independent of any fund).

### Function reference

| Function | Access | Description |
|---|---|---|
| `initialize(admin, proxyAdmin, standaloneStrategyFactory, roleHolders[])` | initializer | Sets the admin, the ProxyAdmin owner reference, and the factory. |
| `setImplementations(factoryImpl, standaloneStrategyImpl)` | `SET_IMPLEMENTATIONS_ROLE` | Records both implementations and pushes the strategy implementation into the factory (future deploys use it; existing proxies are upgraded separately via their ProxyAdmin). |
| `createStandaloneStrategy(fund, admin, roleHolders[])` | `CREATE_STRATEGY_ROLE` | Deploys a new StandaloneStrategy proxy via `factory.create` (its ProxyAdmin ends up owned by the factory's owner) and initializes it. `fund` may be zero. |
| `strategyCount()` / `strategyAt(i)` / `isStrategy(addr)` | view | Registry, backed by the factory's entity list. |
| `factoryImplementation` / `standaloneStrategyImplementation` / `standaloneStrategyFactory` / `proxyAdmin` | view | Current wiring. |
