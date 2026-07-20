export default [
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
    "name": "emergencyPause",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "emergencyUnpause",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "estimateDeposit",
    "inputs": [
      {
        "name": "asset",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "depositAmount",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "shares",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "estimateRedeem",
    "inputs": [
      {
        "name": "asset",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "redeemShares",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "assetAmount",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "fund",
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
    "name": "initialize",
    "inputs": [
      {
        "name": "fund_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "config_",
        "type": "tuple",
        "internalType": "struct IRiskManager.RiskConfig",
        "components": [
          {
            "name": "tvlCap",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "maxBatchDepositCap",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "maxBatchRedeemCap",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "minDepositAmount",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "minRedeemAmount",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "maxDrawdownBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "merkleRoot",
            "type": "bytes32",
            "internalType": "bytes32"
          }
        ]
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "isEmergencyPaused",
    "inputs": [],
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
    "name": "maxBatchDepositCap",
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
    "name": "maxBatchRedeemCap",
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
    "name": "maxDrawdownBps",
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
    "name": "merkleRoot",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "minDepositAmount",
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
    "name": "minRedeemAmount",
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
    "name": "setMaxBatchDepositCap",
    "inputs": [
      {
        "name": "cap",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setMaxBatchRedeemCap",
    "inputs": [
      {
        "name": "cap",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setMaxDrawdown",
    "inputs": [
      {
        "name": "bps",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setMerkleRoot",
    "inputs": [
      {
        "name": "root",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setMinDepositAmount",
    "inputs": [
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
    "name": "setMinRedeemAmount",
    "inputs": [
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
    "name": "setTvlCap",
    "inputs": [
      {
        "name": "cap",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "tvlCap",
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
    "type": "event",
    "name": "EmergencyPaused",
    "inputs": [],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "EmergencyUnpaused",
    "inputs": [],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "MaxBatchDepositCapUpdated",
    "inputs": [
      {
        "name": "cap",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "MaxBatchRedeemCapUpdated",
    "inputs": [
      {
        "name": "cap",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "MaxDrawdownUpdated",
    "inputs": [
      {
        "name": "bps",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "MerkleRootUpdated",
    "inputs": [
      {
        "name": "root",
        "type": "bytes32",
        "indexed": false,
        "internalType": "bytes32"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "MinDepositAmountUpdated",
    "inputs": [
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
    "name": "MinRedeemAmountUpdated",
    "inputs": [
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
    "name": "RiskManagerCreated",
    "inputs": [
      {
        "name": "fund",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "TvlCapUpdated",
    "inputs": [
      {
        "name": "cap",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "error",
    "name": "BaseAssetPriceUnavailable",
    "inputs": []
  },
  {
    "type": "error",
    "name": "BatchDepositCapExceeded",
    "inputs": []
  },
  {
    "type": "error",
    "name": "BatchRedeemCapExceeded",
    "inputs": []
  },
  {
    "type": "error",
    "name": "DepositAssetPriceUnavailable",
    "inputs": []
  },
  {
    "type": "error",
    "name": "DepositBelowMinimum",
    "inputs": []
  },
  {
    "type": "error",
    "name": "DrawdownBreached",
    "inputs": []
  },
  {
    "type": "error",
    "name": "EmergencyPausedError",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidDrawdownBps",
    "inputs": []
  },
  {
    "type": "error",
    "name": "NotWhitelisted",
    "inputs": []
  },
  {
    "type": "error",
    "name": "OnlyFund",
    "inputs": []
  },
  {
    "type": "error",
    "name": "RedeemBelowMinimum",
    "inputs": []
  },
  {
    "type": "error",
    "name": "TvlCapExceeded",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ZeroAddress",
    "inputs": []
  }
] as const;
