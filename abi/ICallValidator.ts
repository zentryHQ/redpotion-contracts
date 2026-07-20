export default [
  {
    "type": "function",
    "name": "addCalls",
    "inputs": [
      {
        "name": "calls_",
        "type": "tuple[]",
        "internalType": "struct ICallValidator.Call[]",
        "components": [
          {
            "name": "caller",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "target",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "selector",
            "type": "bytes4",
            "internalType": "bytes4"
          }
        ]
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "addConstrainedCalls",
    "inputs": [
      {
        "name": "calls_",
        "type": "tuple[]",
        "internalType": "struct ICallValidator.ConstrainedCall[]",
        "components": [
          {
            "name": "caller",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "target",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "selector",
            "type": "bytes4",
            "internalType": "bytes4"
          },
          {
            "name": "constrainedOffsets",
            "type": "uint256[]",
            "internalType": "uint256[]"
          },
          {
            "name": "constrainedValues",
            "type": "bytes32[]",
            "internalType": "bytes32[]"
          }
        ]
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "getAllowedCalls",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getAllowedConstrainedCalls",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getCall",
    "inputs": [
      {
        "name": "callHash",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct ICallValidator.Call",
        "components": [
          {
            "name": "caller",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "target",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "selector",
            "type": "bytes4",
            "internalType": "bytes4"
          }
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getCallHash",
    "inputs": [
      {
        "name": "caller",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "target",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "selector",
        "type": "bytes4",
        "internalType": "bytes4"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "getConstrainedCall",
    "inputs": [
      {
        "name": "callHash",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct ICallValidator.ConstrainedCall",
        "components": [
          {
            "name": "caller",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "target",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "selector",
            "type": "bytes4",
            "internalType": "bytes4"
          },
          {
            "name": "constrainedOffsets",
            "type": "uint256[]",
            "internalType": "uint256[]"
          },
          {
            "name": "constrainedValues",
            "type": "bytes32[]",
            "internalType": "bytes32[]"
          }
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getConstrainedCallHash",
    "inputs": [
      {
        "name": "caller",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "target",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "selector",
        "type": "bytes4",
        "internalType": "bytes4"
      },
      {
        "name": "constrainedOffsets",
        "type": "uint256[]",
        "internalType": "uint256[]"
      },
      {
        "name": "constrainedValues",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "removeCalls",
    "inputs": [
      {
        "name": "callHashes",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "removeConstrainedCalls",
    "inputs": [
      {
        "name": "callHashes",
        "type": "bytes32[]",
        "internalType": "bytes32[]"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "event",
    "name": "CallAdded",
    "inputs": [
      {
        "name": "callHash",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "call_",
        "type": "tuple",
        "indexed": false,
        "internalType": "struct ICallValidator.Call",
        "components": [
          {
            "name": "caller",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "target",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "selector",
            "type": "bytes4",
            "internalType": "bytes4"
          }
        ]
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "CallRemoved",
    "inputs": [
      {
        "name": "callHash",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "call_",
        "type": "tuple",
        "indexed": false,
        "internalType": "struct ICallValidator.Call",
        "components": [
          {
            "name": "caller",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "target",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "selector",
            "type": "bytes4",
            "internalType": "bytes4"
          }
        ]
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "ConstrainedCallAdded",
    "inputs": [
      {
        "name": "callHash",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "call_",
        "type": "tuple",
        "indexed": false,
        "internalType": "struct ICallValidator.ConstrainedCall",
        "components": [
          {
            "name": "caller",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "target",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "selector",
            "type": "bytes4",
            "internalType": "bytes4"
          },
          {
            "name": "constrainedOffsets",
            "type": "uint256[]",
            "internalType": "uint256[]"
          },
          {
            "name": "constrainedValues",
            "type": "bytes32[]",
            "internalType": "bytes32[]"
          }
        ]
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "ConstrainedCallRemoved",
    "inputs": [
      {
        "name": "callHash",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "call_",
        "type": "tuple",
        "indexed": false,
        "internalType": "struct ICallValidator.ConstrainedCall",
        "components": [
          {
            "name": "caller",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "target",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "selector",
            "type": "bytes4",
            "internalType": "bytes4"
          },
          {
            "name": "constrainedOffsets",
            "type": "uint256[]",
            "internalType": "uint256[]"
          },
          {
            "name": "constrainedValues",
            "type": "bytes32[]",
            "internalType": "bytes32[]"
          }
        ]
      }
    ],
    "anonymous": false
  },
  {
    "type": "error",
    "name": "CallAlreadyAllowed",
    "inputs": []
  },
  {
    "type": "error",
    "name": "CallNotAllowed",
    "inputs": []
  },
  {
    "type": "error",
    "name": "LengthMismatch",
    "inputs": []
  }
] as const;
