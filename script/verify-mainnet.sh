#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

CHAIN="mainnet"
COMPILER="0.8.34"
RUNS=200
FILE="deployments/mainnet.json"
API_KEY="${ETHER_SCAN_API_KEY:?ETHER_SCAN_API_KEY is not set}"
DEPLOYER="${DEPLOYER_ADDRESS:?DEPLOYER_ADDRESS is not set}"

FACTORY_IMPL=$(jq -r '.factoryImpl' "$FILE")
FUND_MANAGER_IMPL=$(jq -r '.fundManagerImpl' "$FILE")
FUND_IMPL=$(jq -r '.fundImpl' "$FILE")
SHARE_IMPL=$(jq -r '.shareImpl' "$FILE")
DEPOSIT_QUEUE_IMPL=$(jq -r '.depositQueueImpl' "$FILE")
REDEEM_QUEUE_IMPL=$(jq -r '.redeemQueueImpl' "$FILE")
STRATEGY_IMPL=$(jq -r '.strategyImpl' "$FILE")
FUND_MANAGER_DEPLOYER_IMPL=$(jq -r '.fundManagerDeployerImpl' "$FILE")
FUND_MANAGER_DEPLOYER=$(jq -r '.fundManagerDeployer' "$FILE")
FUND_MANAGER_FACTORY=$(jq -r '.fundManagerFactory' "$FILE")

BASE_FLAGS=(
  --chain "$CHAIN"
  --compiler-version "$COMPILER"
  --optimizer-runs "$RUNS"
  --via-ir
  --evm-version cancun
  --etherscan-api-key "$API_KEY"
  --watch
)

verify() {
  local addr="$1" contract="$2"; shift 2
  echo "→ Verifying $contract @ $addr"
  forge verify-contract "$addr" "$contract" "${BASE_FLAGS[@]}" "$@"
}

# ── Implementation contracts (no constructor args) ───────────────────────────

verify "$FACTORY_IMPL"                "src/Factory.sol:Factory"
verify "$FUND_MANAGER_IMPL"           "src/FundManager.sol:FundManager"
verify "$FUND_IMPL"                   "src/Fund.sol:Fund"
verify "$SHARE_IMPL"                  "src/FundShare.sol:FundShare"
verify "$DEPOSIT_QUEUE_IMPL"          "src/DepositQueue.sol:DepositQueue"
verify "$REDEEM_QUEUE_IMPL"           "src/RedeemQueue.sol:RedeemQueue"
verify "$STRATEGY_IMPL"               "src/Strategy.sol:Strategy"
verify "$FUND_MANAGER_DEPLOYER_IMPL"  "src/FundManagerDeployer.sol:FundManagerDeployer"

# ── FundManagerDeployer proxy: TransparentUpgradeableProxy(impl, admin, data)
PROXY="lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy"

# Reconstruct the initialize calldata that was used during deployment
# initialize(address admin_, address proxyAdmin_, address fundManagerFactory_, RoleHolder[] memory roleHolders_)
# RoleHolder = (bytes32 role, address account)
CREATE_FUND_MANAGER_ROLE=$(cast keccak "CREATE_FUND_MANAGER_ROLE")
SET_IMPLEMENTATIONS_ROLE=$(cast keccak "SET_IMPLEMENTATIONS_ROLE")

INIT_DATA=$(cast calldata \
  "initialize(address,address,address,(bytes32,address)[])" \
  "$DEPLOYER" "$DEPLOYER" "$FUND_MANAGER_FACTORY" \
  "[($CREATE_FUND_MANAGER_ROLE,$DEPLOYER),($SET_IMPLEMENTATIONS_ROLE,$DEPLOYER)]")

PROXY_ARGS=$(cast abi-encode \
  "constructor(address,address,bytes)" \
  "$FUND_MANAGER_DEPLOYER_IMPL" "$DEPLOYER" "$INIT_DATA")

verify "$FUND_MANAGER_DEPLOYER" "$PROXY" --constructor-args "$PROXY_ARGS"

echo "All contracts submitted for verification!"
