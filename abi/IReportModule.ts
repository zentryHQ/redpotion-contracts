export default [
  {
    "type": "function",
    "name": "acceptReport",
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
    "name": "acceptSuspiciousReport",
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
    "name": "MaxAcceptReportDelayUpdated",
    "inputs": [
      {
        "name": "delay",
        "type": "uint48",
        "indexed": false,
        "internalType": "uint48"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "MinAcceptReportDelayUpdated",
    "inputs": [
      {
        "name": "delay",
        "type": "uint48",
        "indexed": false,
        "internalType": "uint48"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "NextCutoffTimeUpdated",
    "inputs": [
      {
        "name": "batchId",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "nextCutoffTime",
        "type": "uint48",
        "indexed": false,
        "internalType": "uint48"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "PriceSafetyUpdated",
    "inputs": [
      {
        "name": "asset",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "safety",
        "type": "tuple",
        "indexed": false,
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
    "anonymous": false
  },
  {
    "type": "event",
    "name": "ReportAccepted",
    "inputs": [
      {
        "name": "batchId",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "asset",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "ReportRejected",
    "inputs": [
      {
        "name": "batchId",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "assets",
        "type": "address[]",
        "indexed": false,
        "internalType": "address[]"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "ReportSubmitted",
    "inputs": [
      {
        "name": "batchId",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "results",
        "type": "tuple[]",
        "indexed": false,
        "internalType": "struct IReportModule.ReportResult[]",
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
          },
          {
            "name": "suspicious",
            "type": "bool",
            "internalType": "bool"
          }
        ]
      }
    ],
    "anonymous": false
  },
  {
    "type": "error",
    "name": "AbsoluteDeltaTooHigh",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AcceptTooEarly",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AcceptTooLate",
    "inputs": []
  },
  {
    "type": "error",
    "name": "BatchAlreadySettled",
    "inputs": []
  },
  {
    "type": "error",
    "name": "BatchNotClosed",
    "inputs": []
  },
  {
    "type": "error",
    "name": "BatchNotSettled",
    "inputs": []
  },
  {
    "type": "error",
    "name": "DelayExceedsLimit",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidCutoffTime",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidPriceSafety",
    "inputs": []
  },
  {
    "type": "error",
    "name": "MinDelayExceedsMax",
    "inputs": []
  },
  {
    "type": "error",
    "name": "NoPendingReport",
    "inputs": []
  },
  {
    "type": "error",
    "name": "PriceAboveMax",
    "inputs": []
  },
  {
    "type": "error",
    "name": "PriceBelowMin",
    "inputs": []
  },
  {
    "type": "error",
    "name": "SuspiciousReportPending",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ZeroDelay",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ZeroPrice",
    "inputs": []
  }
] as const;
