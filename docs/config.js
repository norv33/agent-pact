// AgentPact configuration — single place to switch networks.
// Testnet deployment (chain 97) for reference:
// 0xaEafE6c4820Df5F5Ca7C5D5Bf9296Cfc3f6c1AE3
const CONFIG = {
  // BNB Smart Chain mainnet (chain 56). Deployed 26 Nov 2026.
  CONTRACT_ADDRESS: "0x09332206622be2850bbac8ad64c22b89c22b7b40",
  CHAIN_ID: 56,
  CHAIN_NAME: "BNB Smart Chain",
  // Public BSC mainnet RPCs, tried in order. Public endpoints rate-limit,
  // so the frontend falls back to the next one when a call fails.
  RPC_URLS: [
    "https://bsc-dataseed.binance.org",
    "https://bsc-dataseed1.defibit.io",
    "https://bsc-dataseed1.ninicoin.io"
  ],
  EXPLORER_BASE: "https://bscscan.com",
  // Binance Agent ID (SPACE ID) contract on BNB Chain.
  AGENT_ID_ADDRESS: "0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F",
  MAX_DURATION_DAYS: 30,
  MAX_TITLE_LENGTH: 140
};
