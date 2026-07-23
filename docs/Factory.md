# Factory

> Source: [`src/Factory.sol`](../src/Factory.sol)

## Responsibility

`Factory` is a **generic proxy factory + registry**, reused for every entity type in the system. Each factory instance is configured with one implementation address and stamps out `TransparentUpgradeableProxy` instances of it, while recording every proxy it created (`isEntity`).

Where factories appear:

- [FundManagerDeployer](FundManagerDeployer.md) owns one factory that creates `FundManager` proxies.
- Each [FundManager](FundManager.md) owns **eight** factories — one per fund component (Fund, FundShare, DepositQueue, RedeemQueue, Oracle, FeeManager, RiskManager, Strategy).
- [StandaloneStrategyDeployer](StandaloneStrategy.md#standalonestrategydeployer) owns one factory for standalone strategies.

The registry matters for trust decisions: e.g. `FundManager.createStrategyForFund` uses `fundFactory.isEntity(caller)` to verify the caller is a genuine fund it deployed.

`isEntity` only means "this factory deployed it" — implementation `version` is recorded per creation event, and upgrading existing proxies is done through their ProxyAdmins, not the factory.

## Proxy admin model (OZ v5)

Every `TransparentUpgradeableProxy` auto-deploys its own `ProxyAdmin` contract, owned by the address passed at creation. Upgrades of an entity go through that ProxyAdmin. The system computes ProxyAdmin addresses deterministically (CREATE, nonce 1) where it needs them — see [FundManagerDeployer](FundManagerDeployer.md).

- `create(initData)` — ProxyAdmin owner = the **factory's owner**.
- `createFor(initData, proxyAdminOwner)` — ProxyAdmin owner = an explicit address (used by FundManager to give each tenant's `proxyAdmin` control of all its fund proxies).

## Function reference

| Function | Access | Description |
|---|---|---|
| `initialize(owner)` | initializer | Sets the factory owner (Ownable). |
| `setImplementation(impl)` | `onlyOwner` | Sets the implementation for **future** creations and bumps `version`. Non-zero. |
| `create(initData)` | `onlyOwner` | Deploys a proxy of the current implementation, ProxyAdmin owned by the factory owner, initialized with `initData`. Registers the entity. |
| `createFor(initData, proxyAdminOwner)` | `onlyOwner` | Same, but the ProxyAdmin is owned by `proxyAdminOwner`. |
| `implementation` / `version` | view | Current implementation and how many times it has been set. |
| `entityCount()` / `entityAt(i)` / `isEntity(addr)` | view | Registry of all proxies this factory created. |
