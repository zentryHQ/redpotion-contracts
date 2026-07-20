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
  }
] as const;
