// AgentPact configuration — single place to switch networks.
// To move to BNB Chain mainnet: set CHAIN_ID to 56, RPC_URLS to BSC
// public RPCs, CONTRACT_ADDRESS to the mainnet deployment, and update
// EXPLORER_BASE to https://bscscan.com.
const CONFIG = {
  // BSC Testnet (chain 97). Deployed 26 Nov 2026.
  CONTRACT_ADDRESS: "0xaEafE6c4820Df5F5Ca7C5D5Bf9296Cfc3f6c1AE3",
  CHAIN_ID: 97,
  CHAIN_NAME: "BNB Smart Chain Testnet",
  // Public BSC Testnet RPCs, tried in order. Public endpoints rate-limit,
  // so the frontend falls back to the next one when a call fails.
  RPC_URLS: [
    "https://data-seed-prebsc-1-s1.binance.org:8545",
    "https://bsc-testnet.publicnode.com",
    "https://bsc-testnet-dataseed.bnbchain.org"
  ],
  EXPLORER_BASE: "https://testnet.bscscan.com",
  // Binance Agent ID (SPACE ID) contract on BNB Chain.
  AGENT_ID_ADDRESS: "0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F",
  MAX_DURATION_DAYS: 30,
  MAX_TITLE_LENGTH: 140
};
