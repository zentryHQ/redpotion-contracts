#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# ── Config ──────────────────────────────────────────────────────────────────

read -rp "Network (e.g. base-sepolia) [${NETWORK:-}]: " _in
NETWORK="${_in:-${NETWORK:?NETWORK is not set}}"

read -rp "RPC URL [${RPC_URL:-}]: " _in
RPC_URL="${_in:-${RPC_URL:?RPC_URL is not set}}"

read -rp "Private key [${PRIVATE_KEY:-}]: " _in; echo
PRIVATE_KEY="${_in:-${PRIVATE_KEY:?PRIVATE_KEY is not set}}"

DEPLOY_FILE="deployments/${NETWORK}.json"
if [[ ! -f "$DEPLOY_FILE" ]]; then
  echo "Deployment file not found: $DEPLOY_FILE"
  exit 1
fi

# Load current addresses
FUND_MANAGER_DEPLOYER_IMPL=$(jq -r '.fundManagerDeployerImpl' "$DEPLOY_FILE")
FACTORY_IMPL=$(jq -r '.factoryImpl' "$DEPLOY_FILE")
FUND_MANAGER_IMPL=$(jq -r '.fundManagerImpl' "$DEPLOY_FILE")
FUND_IMPL=$(jq -r '.fundImpl' "$DEPLOY_FILE")
SHARE_IMPL=$(jq -r '.shareImpl' "$DEPLOY_FILE")
DEPOSIT_QUEUE_IMPL=$(jq -r '.depositQueueImpl' "$DEPLOY_FILE")
REDEEM_QUEUE_IMPL=$(jq -r '.redeemQueueImpl' "$DEPLOY_FILE")
ORACLE_IMPL=$(jq -r '.oracleImpl // .oracle' "$DEPLOY_FILE")
FEE_MANAGER_IMPL=$(jq -r '.feeManagerImpl' "$DEPLOY_FILE")
RISK_MANAGER_IMPL=$(jq -r '.riskManagerImpl' "$DEPLOY_FILE")
STRATEGY_IMPL=$(jq -r '.strategyImpl' "$DEPLOY_FILE")
FUND_MANAGER_DEPLOYER=$(jq -r '.fundManagerDeployer' "$DEPLOY_FILE")

SENDER=$(cast wallet address --private-key "$PRIVATE_KEY")
DEPLOY_NONCE=$(cast nonce "$SENDER" --rpc-url "$RPC_URL")

FORGE_FLAGS=(--rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --broadcast)

# ── Helper ───────────────────────────────────────────────────────────────────

ask() {
  local name="$1"
  read -rp "Deploy $name? (y/n) [n]: " ans
  [[ "$ans" == "y" || "$ans" == "Y" ]]
}

# Stores the deployed address in DEPLOY_RESULT.
# Uses and increments DEPLOY_NONCE to avoid RPC nonce races between sequential deploys.
DEPLOY_RESULT=""
deploy() {
  local contract="$1" src="$2"
  echo "  → Deploying $contract (nonce ${DEPLOY_NONCE})..." >&2
  local json txhash addr
  json=$(forge create "$src" "${FORGE_FLAGS[@]}" --nonce "$DEPLOY_NONCE" --json)
  DEPLOY_NONCE=$((DEPLOY_NONCE + 1))
  txhash=$(echo "$json" | jq -r '.transactionHash')
  addr=$(echo "$json" | jq -r '.deployedTo')
  if [[ -z "$txhash" || "$txhash" == "null" ]]; then
    echo "Error: could not parse transaction hash from forge output" >&2
    echo "$json" >&2
    exit 1
  fi
  if [[ -z "$addr" || "$addr" == "null" ]]; then
    echo "Error: could not parse deployed address from forge output" >&2
    echo "$json" >&2
    exit 1
  fi
  echo "     waiting for confirmation ($txhash)..." >&2
  cast receipt "$txhash" --rpc-url "$RPC_URL" --confirmations 1 > /dev/null
  DEPLOY_RESULT="$addr"
}

# ── Ask for each implementation ───────────────────────────────────────────────

echo ""
echo "=== Select implementations to redeploy (${NETWORK}) ==="
echo ""

declare -a SELECTED=()

for name in FundManagerDeployer Factory FundManager Fund FundShare DepositQueue RedeemQueue Oracle FeeManager RiskManager Strategy; do
  ask "$name" && SELECTED+=("$name")
done

echo ""

if [[ "${#SELECTED[@]}" == "0" ]]; then
  echo "Nothing selected. Exiting."
  exit 0
fi

selected() { local n="$1"; for x in "${SELECTED[@]}"; do [[ "$x" == "$n" ]] && return 0; done; return 1; }

# ── Deploy selected implementations ──────────────────────────────────────────

echo "=== Deploying... ==="
echo ""

if selected FundManagerDeployer; then deploy FundManagerDeployer "src/FundManagerDeployer.sol:FundManagerDeployer"; FUND_MANAGER_DEPLOYER_IMPL="$DEPLOY_RESULT"; fi
if selected Factory;             then deploy Factory             "src/Factory.sol:Factory";                         FACTORY_IMPL="$DEPLOY_RESULT";             fi
if selected FundManager;         then deploy FundManager         "src/FundManager.sol:FundManager";                 FUND_MANAGER_IMPL="$DEPLOY_RESULT";         fi
if selected Fund;                then deploy Fund                "src/Fund.sol:Fund";                               FUND_IMPL="$DEPLOY_RESULT";                fi
if selected FundShare;           then deploy FundShare           "src/FundShare.sol:FundShare";                     SHARE_IMPL="$DEPLOY_RESULT";               fi
if selected DepositQueue;        then deploy DepositQueue        "src/DepositQueue.sol:DepositQueue";               DEPOSIT_QUEUE_IMPL="$DEPLOY_RESULT";        fi
if selected RedeemQueue;         then deploy RedeemQueue         "src/RedeemQueue.sol:RedeemQueue";                 REDEEM_QUEUE_IMPL="$DEPLOY_RESULT";         fi
if selected Oracle;              then deploy Oracle              "src/Oracle.sol:Oracle";                           ORACLE_IMPL="$DEPLOY_RESULT";               fi
if selected FeeManager;          then deploy FeeManager          "src/FeeManager.sol:FeeManager";                   FEE_MANAGER_IMPL="$DEPLOY_RESULT";          fi
if selected RiskManager;         then deploy RiskManager         "src/RiskManager.sol:RiskManager";                 RISK_MANAGER_IMPL="$DEPLOY_RESULT";         fi
if selected Strategy;            then deploy Strategy            "src/Strategy.sol:Strategy";                       STRATEGY_IMPL="$DEPLOY_RESULT";             fi

# ── Update FundManagerDeployer ────────────────────────────────────────────────

echo ""
echo "=== Calling setImplementations on FundManagerDeployer ==="
echo ""

cast send "$FUND_MANAGER_DEPLOYER" \
  "setImplementations(address,address,address,address,address,address,address,address,address,address)" \
  "$FACTORY_IMPL" \
  "$FUND_MANAGER_IMPL" \
  "$FUND_IMPL" \
  "$SHARE_IMPL" \
  "$DEPOSIT_QUEUE_IMPL" \
  "$REDEEM_QUEUE_IMPL" \
  "$ORACLE_IMPL" \
  "$FEE_MANAGER_IMPL" \
  "$RISK_MANAGER_IMPL" \
  "$STRATEGY_IMPL" \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --nonce "$DEPLOY_NONCE"

# ── Update deployment JSON ────────────────────────────────────────────────────

echo ""
echo "=== Updating $DEPLOY_FILE ==="

jq \
  --arg fundManagerDeployerImpl "$FUND_MANAGER_DEPLOYER_IMPL" \
  --arg factoryImpl      "$FACTORY_IMPL" \
  --arg fundManagerImpl  "$FUND_MANAGER_IMPL" \
  --arg fundImpl         "$FUND_IMPL" \
  --arg shareImpl        "$SHARE_IMPL" \
  --arg depositQueueImpl "$DEPOSIT_QUEUE_IMPL" \
  --arg redeemQueueImpl  "$REDEEM_QUEUE_IMPL" \
  --arg oracleImpl       "$ORACLE_IMPL" \
  --arg feeManagerImpl   "$FEE_MANAGER_IMPL" \
  --arg riskManagerImpl  "$RISK_MANAGER_IMPL" \
  --arg strategyImpl     "$STRATEGY_IMPL" \
  '.fundManagerDeployerImpl = $fundManagerDeployerImpl |
   .factoryImpl      = $factoryImpl      |
   .fundManagerImpl  = $fundManagerImpl  |
   .fundImpl         = $fundImpl         |
   .shareImpl        = $shareImpl        |
   .depositQueueImpl = $depositQueueImpl |
   .redeemQueueImpl  = $redeemQueueImpl  |
   .oracleImpl       = $oracleImpl       |
   .feeManagerImpl   = $feeManagerImpl   |
   .riskManagerImpl  = $riskManagerImpl  |
   .strategyImpl     = $strategyImpl' \
  "$DEPLOY_FILE" > "${DEPLOY_FILE}.tmp" && mv "${DEPLOY_FILE}.tmp" "$DEPLOY_FILE"

echo ""
echo "Done. Updated addresses:"
echo ""
jq '{fundManagerDeployerImpl, factoryImpl, fundManagerImpl, fundImpl, shareImpl, depositQueueImpl, redeemQueueImpl, oracleImpl, feeManagerImpl, riskManagerImpl, strategyImpl}' "$DEPLOY_FILE"
