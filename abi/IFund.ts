export default [
  {
    "type": "function",
    "name": "addExternalWallet",
    "inputs": [
      {
        "name": "wallet",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "addStrategy",
    "inputs": [
      {
        "name": "strategy",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "checkDeposit",
    "inputs": [
      {
        "name": "depositor",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "asset",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "batchId",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "depositAmount",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "proof",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      }
    ],
    "outputs": [],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "checkRedeem",
    "inputs": [
      {
        "name": "batchId",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "redeemShares",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "createStrategy",
    "inputs": [
      {
        "name": "admin_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "roleHolders_",
        "type": "tuple[]",
        "internalType": "struct ACLModule.RoleHolder[]",
        "components": [
          {
            "name": "role",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "account",
            "type": "address",
            "internalType": "address"
          }
        ]
      }
    ],
    "outputs": [
      {
        "name": "strategy",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "depositQueue",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "feeManager",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "fundManager",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "fundRedeem",
    "inputs": [
      {
        "name": "asset",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "batchId",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "getCurrentBatchId",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getExternalWallets",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address[]",
        "internalType": "address[]"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getRiskContext",
    "inputs": [
      {
        "name": "asset",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "batchId",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct IRiskManager.RiskContext",
        "components": [
          {
            "name": "basePrice",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "assetPrice",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "highWaterMark",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "batchDepositTotalInBase",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "batchRedeemTotalInBase",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "shareSupply",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "entryFeeBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "exitFeeBps",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "initialize",
    "inputs": [
      {
        "name": "share_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "depositQueue_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "redeemQueue_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "oracle_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "feeManager_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "riskManager_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "fundManager_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "admin_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "roleHolders_",
        "type": "tuple[]",
        "internalType": "struct ACLModule.RoleHolder[]",
        "components": [
          {
            "name": "role",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "account",
            "type": "address",
            "internalType": "address"
          }
        ]
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "isExternalWallet",
    "inputs": [
      {
        "name": "wallet",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "isStrategy",
    "inputs": [
      {
        "name": "strategy",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "oracle",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "protocolFeeRecipient",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "pullAssetFromStrategy",
    "inputs": [
      {
        "name": "strategy",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "asset",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "pushAssetToStrategy",
    "inputs": [
      {
        "name": "strategy",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "asset",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "pushAssetToWallet",
    "inputs": [
      {
        "name": "wallet",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "asset",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "redeemQueue",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "removeExternalWallet",
    "inputs": [
      {
        "name": "wallet",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "removeStrategy",
    "inputs": [
      {
        "name": "strategy",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "share",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "event",
    "name": "AssetPulledFromStrategy",
    "inputs": [
      {
        "name": "strategy",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "asset",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "AssetPushedToStrategy",
    "inputs": [
      {
        "name": "strategy",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "asset",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "AssetPushedToWallet",
    "inputs": [
      {
        "name": "wallet",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "asset",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "DepositSettled",
    "inputs": [
      {
        "name": "asset",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "batchId",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "userShares",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "feeShares",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "ExternalWalletAdded",
    "inputs": [
      {
        "name": "wallet",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "ExternalWalletRemoved",
    "inputs": [
      {
        "name": "wallet",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "FeeManagerUpdated",
    "inputs": [
      {
        "name": "feeManager",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RedeemSettled",
    "inputs": [
      {
        "name": "asset",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "batchId",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "redeemTotal",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "feeShares",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "ShareUpdated",
    "inputs": [
      {
        "name": "share",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "StrategyAdded",
    "inputs": [
      {
        "name": "strategy",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "StrategyRemoved",
    "inputs": [
      {
        "name": "strategy",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "error",
    "name": "InvalidStrategy",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidWallet",
    "inputs": []
  },
  {
    "type": "error",
    "name": "WalletAlreadyAdded",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ZeroAddress",
    "inputs": []
  }
] as const;
