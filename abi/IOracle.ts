export default [
  {
    "type": "function",
    "name": "acceptReport",
    "inputs": [
      {
        "name": "assets",
        "type": "address[]",
        "internalType": "address[]"
      },
      {
        "name": "nextCutoffTime_",
        "type": "uint48",
        "internalType": "uint48"
      }
    ],
    "outputs": [
      {
        "name": "batchId",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "prices",
        "type": "uint256[]",
        "internalType": "uint256[]"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "acceptSuspiciousReport",
    "inputs": [
      {
        "name": "assets",
        "type": "address[]",
        "internalType": "address[]"
      },
      {
        "name": "nextCutoffTime_",
        "type": "uint48",
        "internalType": "uint48"
      }
    ],
    "outputs": [
      {
        "name": "batchId",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "prices",
        "type": "uint256[]",
        "internalType": "uint256[]"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "currentBatchId",
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
    "name": "getPendingReport",
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
        "internalType": "struct IReportModule.PendingReport",
        "components": [
          {
            "name": "price",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "suspicious",
            "type": "bool",
            "internalType": "bool"
          },
          {
            "name": "submittedAt",
            "type": "uint48",
            "internalType": "uint48"
          }
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getReport",
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
        "internalType": "struct IReportModule.Report",
        "components": [
          {
            "name": "price",
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
        "name": "fund_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "firstCutoffTime_",
        "type": "uint48",
        "internalType": "uint48"
      },
      {
        "name": "minAcceptReportDelay_",
        "type": "uint48",
        "internalType": "uint48"
      },
      {
        "name": "maxAcceptReportDelay_",
        "type": "uint48",
        "internalType": "uint48"
      },
      {
        "name": "priceSafeties_",
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
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "lastAcceptedPrice",
    "inputs": [
      {
        "name": "asset",
        "type": "address",
        "internalType": "address"
      }
    ],
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
    "name": "maxAcceptReportDelay",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint48",
        "internalType": "uint48"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "minAcceptReportDelay",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint48",
        "internalType": "uint48"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "nextCutoffTime",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint48",
        "internalType": "uint48"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "priceSafety",
    "inputs": [
      {
        "name": "asset",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "",
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
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "rejectReport",
    "inputs": [
      {
        "name": "assets",
        "type": "address[]",
        "internalType": "address[]"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setMaxAcceptReportDelay",
    "inputs": [
      {
        "name": "delay",
        "type": "uint48",
        "internalType": "uint48"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setMinAcceptReportDelay",
    "inputs": [
      {
        "name": "delay",
        "type": "uint48",
        "internalType": "uint48"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setNextCutoffTime",
    "inputs": [
      {
        "name": "nextCutoffTime_",
        "type": "uint48",
        "internalType": "uint48"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setPriceSafety",
    "inputs": [
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
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setPriceSafetyBatch",
    "inputs": [
      {
        "name": "safeties",
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
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "submitReport",
    "inputs": [
      {
        "name": "reports",
        "type": "tuple[]",
        "internalType": "struct IReportModule.ReportSubmission[]",
        "components": [
          {
            "name": "asset",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "price",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "event",
    "name": "OracleCreated",
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
    "type": "error",
    "name": "OnlyFund",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ZeroAddress",
    "inputs": []
  }
] as const;
