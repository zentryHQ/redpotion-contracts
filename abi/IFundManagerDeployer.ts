export default [
  {
    "type": "function",
    "name": "createFundManager",
    "inputs": [
      {
        "name": "owner_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "proxyAdmin_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "fundManagerRoleHolders_",
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
        "name": "fundManager",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "depositQueueImplementation",
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
    "name": "factoryImplementation",
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
    "name": "feeManagerImplementation",
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
    "name": "fundImplementation",
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
    "name": "fundManagerAt",
    "inputs": [
      {
        "name": "index",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
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
    "name": "fundManagerCount",
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
    "name": "fundManagerFactory",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "contract IFactory"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "fundManagerImplementation",
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
    "name": "isFundManager",
    "inputs": [
      {
        "name": "entity",
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
    "name": "oracleImplementation",
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
    "name": "redeemQueueImplementation",
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
    "name": "riskManagerImplementation",
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
    "name": "setImplementations",
    "inputs": [
      {
        "name": "factoryImplementation_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "fundManagerImplementation_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "fundImplementation_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "shareImplementation_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "depositQueueImplementation_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "redeemQueueImplementation_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "oracleImplementation_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "feeManagerImplementation_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "riskManagerImplementation_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "strategyImplementation_",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setProtocolFeeRecipient",
    "inputs": [
      {
        "name": "recipient_",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "shareImplementation",
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
    "name": "strategyImplementation",
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
    "name": "FundManagerCreated",
    "inputs": [
      {
        "name": "fundManager",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "owner",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "fundFactory",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "shareFactory",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "depositQueueFactory",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "redeemQueueFactory",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "oracleFactory",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "feeManagerFactory",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "riskManagerFactory",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "strategyFactory",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "ImplementationsSet",
    "inputs": [
      {
        "name": "factoryImplementation",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "fundManagerImplementation",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "fundImplementation",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "shareImplementation",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "depositQueueImplementation",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "redeemQueueImplementation",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "oracleImplementation",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "feeManagerImplementation",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "riskManagerImplementation",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "strategyImplementation",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "ProtocolFeeRecipientUpdated",
    "inputs": [
      {
        "name": "protocolFeeRecipient",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "error",
    "name": "ZeroAddress",
    "inputs": []
  }
] as const;
