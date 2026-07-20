# Load .env if it exists
-include .env
export

.PHONY: build test deploy-infra clean deploy-infra-base-sepolia verify-base-sepolia log-owners-base-sepolia log-owners-mainnet log-impls-base-sepolia log-impls-mainnet

# ─── Build & Test ─────────────────────────────────────────────────────────────

build:
	forge build --extra-output-files abi
	@mkdir -p abi
	@find src -name "*.sol" | while read f; do \
		sol=$$(basename $$f); \
		contract=$${sol%.sol}; \
		abi_file="out/$$sol/$$contract.abi.json"; \
		[ -f "$$abi_file" ] && printf 'export default %s as const;\n' "$$(cat $$abi_file)" > "abi/$$contract.ts" || true; \
	done
	@echo "ABIs written to abi/"

test:
	forge test -vvv

# ─── Deploy ───────────────────────────────────────────────────────────────────

## Deploy infrastructure to Base Sepolia testnet and verify on Basescan.
## Requires BASE_SEPOLIA_RPC_URL and ETHER_SCAN_API_KEY in .env.
deploy-infra-base-sepolia:
	FOUNDRY_PROFILE=production NETWORK=base-sepolia forge script script/DeployInfra.s.sol:DeployInfra \
		--rpc-url base-sepolia \
		--private-key $(DEPLOYER_PRIVATE_KEY) \
		--broadcast \
		-vvvv

## Deploy infrastructure to mainnet.
deploy-infra:
	FOUNDRY_PROFILE=production NETWORK=mainnet forge script script/DeployInfra.s.sol:DeployInfra \
		--rpc-url $(MAINNET_RPC_URL) \
		--private-key $(DEPLOYER_PRIVATE_KEY) \
		--broadcast \
		--verify \
		-vvvv


## Log ProxyAdmin owner of every proxy in the system on Base Sepolia.
log-owners-base-sepolia:
	NETWORK=base-sepolia forge script script/LogProxyOwners.s.sol:LogProxyOwners \
		--rpc-url base-sepolia \
		-vv

## Log ProxyAdmin owner of every proxy in the system on mainnet.
log-owners-mainnet:
	NETWORK=mainnet forge script script/LogProxyOwners.s.sol:LogProxyOwners \
		--rpc-url $(MAINNET_RPC_URL) \
		-vv

## Log ERC-1967 implementation address of every proxy on Base Sepolia.
log-impls-base-sepolia:
	NETWORK=base-sepolia forge script script/LogImplementations.s.sol:LogImplementations \
		--rpc-url base-sepolia \
		-vv

## Log ERC-1967 implementation address of every proxy on mainnet.
log-impls-mainnet:
	NETWORK=mainnet forge script script/LogImplementations.s.sol:LogImplementations \
		--rpc-url $(MAINNET_RPC_URL) \
		-vv

## Verify all Base Sepolia contracts on Basescan.
## Requires BASESCAN_API_KEY and DEPLOYER_ADDRESS in .env.
verify-base-sepolia:
	chmod +x script/verify-base-sepolia.sh
	./script/verify-base-sepolia.sh

## Verify all Base mainnet contracts on Basescan.
## Requires ETHER_SCAN_API_KEY and DEPLOYER_ADDRESS in .env.
verify-mainnet:
	chmod +x script/verify-mainnet.sh
	./script/verify-mainnet.sh
# ─── Misc ─────────────────────────────────────────────────────────────────────

clean:
	forge clean
	rm -rf deployments abi
