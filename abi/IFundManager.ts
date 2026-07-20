export default [
  {
    "type": "function",
    "name": "createFund",
    "inputs": [
      {
        "name": "params",
        "type": "tuple",
        "internalType": "struct IFundManager.CreateFundParams",
        "components": [
          {
            "name": "depositAssets",
            "type": "address[]",
            "internalType": "address[]"
          },
          {
            "name": "redeemAssets",
            "type": "address[]",
            "internalType": "address[]"
          },
          {
            "name": "shareName",
            "type": "string",
            "internalType": "string"
          },
          {
            "name": "shareSymbol",
            "type": "string",
            "internalType": "string"
          },
          {
            "name": "admin",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "proxyAdmin",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "feeRecipient",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "feeBaseAsset",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "feeConfig",
            "type": "tuple",
            "internalType": "struct IFeeManager.FeeConfig",
            "components": [
              {
                "name": "entryFeeBps",
                "type": "uint256",
                "internalType": "uint256"
              },
              {
                "name": "exitFeeBps",
                "type": "uint256",
                "internalType": "uint256"
              },
              {
                "name": "managementFeeBps",
                "type": "uint256",
                "internalType": "uint256"
              },
              {
                "name": "performanceFeeBps",
                "type": "uint256",
                "internalType": "uint256"
              },
              {
                "name": "protocolFeeBps",
                "type": "uint256",
                "internalType": "uint256"
              }
            ]
          },
          {
            "name": "firstCutoffTime",
            "type": "uint48",
            "internalType": "uint48"
          },
          {
            "name": "reportDelays",
            "type": "tuple",
            "internalType": "struct IOracle.ReportDelays",
            "components": [
              {
                "name": "minAcceptReportDelay",
                "type": "uint48",
                "internalType": "uint48"
              },
              {
                "name": "maxAcceptReportDelay",
                "type": "uint48",
                "internalType": "uint48"
              }
            ]
          },
          {
            "name": "priceSafeties",
            "type": "tuple[]",
            "internalType": "struct IReportModule.PriceSafetyInit[]",
            "components": [
              {
                "name": "asset",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "safety",
                "type": "tuple",
                "internalType": "struct IReportModule.PriceSafety",
                "components": [
                  {
                    "name": "minPrice",
                    "type": "uint256",
                    "internalType": "uint256"
                  },
                  {
                    "name": "maxPrice",
                    "type": "uint256",
                    "internalType": "uint256"
                  },
                  {
                    "name": "maxAbsoluteDelta",
                    "type": "uint256",
                    "internalType": "uint256"
                  },
                  {
                    "name": "maxDeviationBps",
                    "type": "uint256",
                    "internalType": "uint256"
                  }
                ]
              }
            ]
          },
          {
            "name": "riskConfig",
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
          },
          {
            "name": "roleHolders",
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
        ]
      }
    ],
    "outputs": [
      {
        "name": "fund",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "share",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "depositQueue",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "redeemQueue",
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
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "createStrategyForFund",
    "inputs": [
      {
        "name": "fund",
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
    "name": "deployer",
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
    "name": "depositQueueFactory",
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
    "name": "feeManagerFactory",
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
    "name": "fundFactory",
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
    "name": "initialize",
    "inputs": [
      {
        "name": "owner_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "deployer_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "fundFactory_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "shareFactory_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "depositQueueFactory_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "redeemQueueFactory_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "oracleFactory_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "feeManagerFactory_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "riskManagerFactory_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "strategyFactory_",
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
    "name": "oracleFactory",
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
    "name": "redeemQueueFactory",
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
    "name": "riskManagerFactory",
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
    "name": "setDepositQueueFactory",
    "inputs": [
      {
        "name": "depositQueueFactory_",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setDepositQueueImplementation",
    "inputs": [
      {
        "name": "impl",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setFeeManagerFactory",
    "inputs": [
      {
        "name": "feeManagerFactory_",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setFeeManagerImplementation",
    "inputs": [
      {
        "name": "impl",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setFundFactory",
    "inputs": [
      {
        "name": "fundFactory_",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setFundImplementation",
    "inputs": [
      {
        "name": "impl",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setOracleFactory",
    "inputs": [
      {
        "name": "oracleFactory_",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setOracleImplementation",
    "inputs": [
      {
        "name": "impl",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setRedeemQueueFactory",
    "inputs": [
      {
        "name": "redeemQueueFactory_",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setRedeemQueueImplementation",
    "inputs": [
      {
        "name": "impl",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setRiskManagerFactory",
    "inputs": [
      {
        "name": "riskManagerFactory_",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setRiskManagerImplementation",
    "inputs": [
      {
        "name": "impl",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setShareFactory",
    "inputs": [
      {
        "name": "shareFactory_",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setShareImplementation",
    "inputs": [
      {
        "name": "impl",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setStrategyFactory",
    "inputs": [
      {
        "name": "strategyFactory_",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setStrategyImplementation",
    "inputs": [
      {
        "name": "impl",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "shareFactory",
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
    "name": "strategyFactory",
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
    "type": "event",
    "name": "DepositQueueFactoryUpdated",
    "inputs": [
      {
        "name": "depositQueueFactory",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "DepositQueueImplementationUpdated",
    "inputs": [
      {
        "name": "impl",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "FeeManagerFactoryUpdated",
    "inputs": [
      {
        "name": "feeManagerFactory",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "FeeManagerImplementationUpdated",
    "inputs": [
      {
        "name": "impl",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "FundCreated",
    "inputs": [
      {
        "name": "fund",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "share",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "depositQueue",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "redeemQueue",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "oracle",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "feeManager",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "riskManager",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "admin",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "FundFactoryUpdated",
    "inputs": [
      {
        "name": "fundFactory",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "FundImplementationUpdated",
    "inputs": [
      {
        "name": "impl",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "FundManagerCreated",
    "inputs": [
      {
        "name": "fundFactory",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "shareFactory",
        "type": "address",
        "indexed": true,
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
    "name": "OracleFactoryUpdated",
    "inputs": [
      {
        "name": "oracleFactory",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "OracleImplementationUpdated",
    "inputs": [
      {
        "name": "impl",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RedeemQueueFactoryUpdated",
    "inputs": [
      {
        "name": "redeemQueueFactory",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RedeemQueueImplementationUpdated",
    "inputs": [
      {
        "name": "impl",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RiskManagerFactoryUpdated",
    "inputs": [
      {
        "name": "riskManagerFactory",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RiskManagerImplementationUpdated",
    "inputs": [
      {
        "name": "impl",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "ShareFactoryUpdated",
    "inputs": [
      {
        "name": "shareFactory",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "ShareImplementationUpdated",
    "inputs": [
      {
        "name": "impl",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "StrategyFactoryUpdated",
    "inputs": [
      {
        "name": "strategyFactory",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "StrategyImplementationUpdated",
    "inputs": [
      {
        "name": "impl",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "error",
    "name": "InvalidCaller",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ZeroAddress",
    "inputs": []
  }
] as const;
