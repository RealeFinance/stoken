const { ethers } = require("ethers");

// 合约 ABI（必须包含自定义 Error 的定义）
const abi = [
  {
    inputs: [],
    name: "BelowMinAmount",
    type: "error",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "previous",
        type: "address",
      },
      {
        indexed: false,
        internalType: "address",
        name: "newAdmin",
        type: "address",
      },
    ],
    name: "CCIPAdminTransferred",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "previous",
        type: "address",
      },
      {
        indexed: false,
        internalType: "address",
        name: "newAdmin",
        type: "address",
      },
    ],
    name: "PoolAdminTransferred",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "redemptionId",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "uAmount",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "address",
        name: "uAddress",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "stokenAmount",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "address",
        name: "user",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "price",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "time",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "bytes32",
        name: "udaTxHash",
        type: "bytes32",
      },
      {
        indexed: false,
        internalType: "uint16",
        name: "source",
        type: "uint16",
      },
      {
        indexed: false,
        internalType: "string",
        name: "offChainId",
        type: "string",
      },
    ],
    name: "RedemptionEvent",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "id",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "mintTime",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "price",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "address",
        name: "tokenOwner",
        type: "address",
      },
    ],
    name: "addNewTokenDataEvent",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "oldRecipient",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "newRecipient",
        type: "address",
      },
    ],
    name: "assetRecipientUpdatedEvent",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "oldSender",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "newSender",
        type: "address",
      },
    ],
    name: "assetSenderUpdatedEvent",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "redemptionId",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "uAmount",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "address",
        name: "uAddress",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "stokenAmount",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "address",
        name: "user",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "price",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "time",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "bytes32",
        name: "udaTxHash",
        type: "bytes32",
      },
      {
        indexed: false,
        internalType: "uint16",
        name: "source",
        type: "uint16",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "technicalServiceFee",
        type: "uint256",
      },
    ],
    name: "burnEvent",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "redemptionId",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "uAmount",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "address",
        name: "uAddress",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "stokenAmount",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "address",
        name: "user",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "price",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "time",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "bytes32",
        name: "udaTxHash",
        type: "bytes32",
      },
      {
        indexed: false,
        internalType: "uint16",
        name: "source",
        type: "uint16",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "technicalServiceFee",
        type: "uint256",
      },
      {
        components: [
          {
            internalType: "uint256",
            name: "id",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "amount",
            type: "uint256",
          },
        ],
        indexed: false,
        internalType: "struct ISAmMMF.TokenTransferDetail[]",
        name: "tokenTransferDetails",
        type: "tuple[]",
      },
    ],
    name: "burnEvent",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "subscriptionId",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "uAmount",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "address",
        name: "uAddress",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "stokenAmount",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "address",
        name: "user",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "price",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "time",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "bytes32",
        name: "udaTxHash",
        type: "bytes32",
      },
      {
        indexed: false,
        internalType: "uint16",
        name: "source",
        type: "uint16",
      },
    ],
    name: "claimEvent",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "subscriptionId",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "uAmount",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "address",
        name: "uAddress",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "stokenAmount",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "address",
        name: "user",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "price",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "time",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "bytes32",
        name: "udaTxHash",
        type: "bytes32",
      },
      {
        indexed: false,
        internalType: "uint16",
        name: "source",
        type: "uint16",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "tokenId",
        type: "uint256",
      },
    ],
    name: "claimEvent",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "redemptionId",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "uAmount",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "address",
        name: "uAddress",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "stokenAmount",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "address",
        name: "user",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "price",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "time",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "bytes32",
        name: "udaTxHash",
        type: "bytes32",
      },
      {
        indexed: false,
        internalType: "uint16",
        name: "source",
        type: "uint16",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "technicalServiceFee",
        type: "uint256",
      },
    ],
    name: "claimUSDEvent",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "subscriptionId",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "uAmount",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "address",
        name: "uAddress",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "stokenAmount",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "address",
        name: "user",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "price",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "time",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "bytes32",
        name: "udaTxHash",
        type: "bytes32",
      },
      {
        indexed: false,
        internalType: "uint16",
        name: "source",
        type: "uint16",
      },
    ],
    name: "executeEvent",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "subscriptionId",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "uAmount",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "address",
        name: "uAddress",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "stokenAmount",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "address",
        name: "user",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "price",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "time",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "bytes32",
        name: "udaTxHash",
        type: "bytes32",
      },
      {
        indexed: false,
        internalType: "uint16",
        name: "source",
        type: "uint16",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "tokenId",
        type: "uint256",
      },
    ],
    name: "executeEvent",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "oldAmount",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "newAmount",
        type: "uint256",
      },
    ],
    name: "maxRedemptionAmountUpdatedEvent",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "oldAmount",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "newAmount",
        type: "uint256",
      },
    ],
    name: "maxSubscriptionAmountUpdatedEvent",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "oldAmount",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "newAmount",
        type: "uint256",
      },
    ],
    name: "minRedemptionAmountUpdatedEvent",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "oldAmount",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "newAmount",
        type: "uint256",
      },
    ],
    name: "minSubscriptionAmountUpdatedEvent",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "redemptionId",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "address",
        name: "uAddress",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "stokenAmount",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "address",
        name: "user",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint16",
        name: "source",
        type: "uint16",
      },
    ],
    name: "onChainBurnEvent",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "redemptionId",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "address",
        name: "uAddress",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "stokenAmount",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "address",
        name: "user",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint16",
        name: "source",
        type: "uint16",
      },
    ],
    name: "onChainRedemptionEvent",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "subscriptionId",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "uAmount",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "address",
        name: "uAddress",
        type: "address",
      },
      {
        indexed: false,
        internalType: "address",
        name: "user",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint16",
        name: "source",
        type: "uint16",
      },
    ],
    name: "onChainSubscribeEvent",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "redemptionId",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "uAmount",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "price",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "time",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "bytes32",
        name: "udaTxHash",
        type: "bytes32",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "technicalServiceFee",
        type: "uint256",
      },
    ],
    name: "overwriteOnChainRedemptionEvent",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "redemptionId",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "uAmount",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "price",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "time",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "bytes32",
        name: "udaTxHash",
        type: "bytes32",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "technicalServiceFee",
        type: "uint256",
      },
      {
        components: [
          {
            internalType: "uint256",
            name: "id",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "amount",
            type: "uint256",
          },
        ],
        indexed: false,
        internalType: "struct ISAmMMF.TokenTransferDetail[]",
        name: "tokenTransferDetails",
        type: "tuple[]",
      },
    ],
    name: "overwriteOnChainRedemptionEvent",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "subscriptionId",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "stokenAmount",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "price",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "time",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "bytes32",
        name: "udaTxHash",
        type: "bytes32",
      },
      {
        indexed: false,
        internalType: "string",
        name: "offChainId",
        type: "string",
      },
    ],
    name: "overwriteOnChainSubscribeEvent",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "oldRecipient",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "newRecipient",
        type: "address",
      },
    ],
    name: "serviceFeeRecipientUpdatedEvent",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "subscriptionId",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "uAmount",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "address",
        name: "uAddress",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "stokenAmount",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "address",
        name: "user",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "price",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "time",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "bytes32",
        name: "udaTxHash",
        type: "bytes32",
      },
      {
        indexed: false,
        internalType: "uint16",
        name: "source",
        type: "uint16",
      },
      {
        indexed: false,
        internalType: "string",
        name: "offChainId",
        type: "string",
      },
    ],
    name: "subscribeEvent",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "token",
        type: "address",
      },
    ],
    name: "supportedTokenAddressAddedEvent",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "token",
        type: "address",
      },
    ],
    name: "supportedTokenAddressRemovedEvent",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "redemptionId",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256[]",
        name: "tokenIds",
        type: "uint256[]",
      },
      {
        indexed: false,
        internalType: "uint256[]",
        name: "amounts",
        type: "uint256[]",
      },
    ],
    name: "technicalServiceFeeEvent",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint256",
        name: "oldRate",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "newRate",
        type: "uint256",
      },
    ],
    name: "technicalServiceFeeRateUpdatedEvent",
    type: "event",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "token",
        type: "address",
      },
    ],
    name: "addSupportedTokenAddress",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "assetRecipient",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "assetSender",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "getAssetRecipient",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "getAssetSender",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "getServiceFeeRecipient",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "getSupportedTokenAddresses",
    outputs: [
      {
        internalType: "address[]",
        name: "",
        type: "address[]",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "getTechnicalServiceFeeRate",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "token",
        type: "address",
      },
    ],
    name: "removeSupportedTokenAddress",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "serviceFeeRecipient",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "newRecipient",
        type: "address",
      },
    ],
    name: "setAssetRecipient",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "newSender",
        type: "address",
      },
    ],
    name: "setAssetSender",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "newRecipient",
        type: "address",
      },
    ],
    name: "setServiceFeeRecipient",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "newRate",
        type: "uint256",
      },
    ],
    name: "setTechnicalServiceFeeRate",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    name: "supportedTokenAddress",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "technicalServiceFeeRate",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
];

// 模拟链上返回的错误数据（unknown custom error 对应的 bytes）
const errorData =
  "0xf46a974a0000000000000000000000001afb66e33b75b146d91a68dbb7e64eeb21834b6a0000000000000000000000000000000000000000000000000de0b6b3a7640000000000000000000000000000000000000000000000000000000000000000001c"; // 实际报错时的 bytes 数据

// 解析自定义 Error
function decodeCustomError(abi, errorData) {
  const iface = new ethers.Interface(abi);
  try {
    const decoded = iface.parseError(errorData);
    console.log("解析后的错误：", iface.formatError(decoded));
    return {
      name: decoded.name, // 错误名称（如 InsufficientBalance）
      args: decoded.args, // 错误参数（如 requested: 200, available: 100）
    };
  } catch (e) {
    return { name: "UnknownError", message: e.message };
  }
}

// 使用示例
const decodedError = decodeCustomError(abi, errorData);
console.log("解析后的错误：", decodedError);
