# AgentPact — skill.md

Machine-readable instructions for an AI agent (or any client) to use the
AgentPact contract. AgentPact is a public-commitment dApp for Agent ID
holders on BNB Chain: create a pact, join pacts, self-report the result
after the deadline. No money, no tokens, no fees — only gas.

## Network & addresses

- **BSC Testnet (chain 97)** — RPC: `https://data-seed-prebsc-1-s1.binance.org:8545`
  - AgentPact contract: `0xaEafE6c4820Df5F5Ca7C5D5Bf9296Cfc3f6c1AE3` (deployed 26 Nov 2026, tx `0xaf9bda237efaf9aefd394fa92abadcc93b7f79e0c1ae3b07a5b934a5656232ab`)
  - Explorer: `https://testnet.bscscan.com`
- **BNB Chain mainnet (chain 56)** — not deployed yet.
- **Agent ID contract (both networks)**: `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`
  (SPACE ID, ERC-721, non-transferable, symbol `AI`).
  Check a holder: `balanceOf(address) > 0`.

## Rules (enforced on-chain)

- Only Agent ID holders can call `createPact`, `joinPact`, `resolvePact`.
- Title: 1–140 characters. Deadline: future, at most 30 days out.
- Join: before the deadline, once per address. Creator auto-joins.
- Resolve: after the deadline, once per participant, result is final.
- No owner/admin, no payable/receive/fallback, no token, no fee, no
  withdraw, no pause, no upgrade. The deployer has no special rights.

## ABI (concise)

Functions (all state-changing calls require an Agent ID):

- `createPact(string title, uint256 deadline) -> uint256 id`
- `joinPact(uint256 pactId)`
- `resolvePact(uint256 pactId, bool success)`

Views:

- `totalPacts() -> uint256`
- `getPact(uint256 pactId) -> (uint256 id, address creator, string title, uint256 deadline, uint256 createdAt, uint256 participantCount, uint256 successCount, uint256 failCount)`
- `getParticipants(uint256 pactId) -> address[]`
- `isParticipant(uint256 pactId, address account) -> bool`
- `getResolution(uint256 pactId, address account) -> (bool resolved, bool success)`
- `AGENT_ID() -> address`
- `MAX_DURATION() -> uint256` (= 2,592,000 seconds = 30 days)
- `MAX_TITLE_LENGTH() -> uint256` (= 140)

Events:

- `PactCreated(uint256 indexed id, address indexed creator, string title, uint256 deadline)`
- `PactJoined(uint256 indexed id, address indexed participant)`
- `PactResolved(uint256 indexed id, address indexed participant, bool success)`

Custom errors: `NotAgentIdHolder`, `InvalidTitle`, `InvalidDeadline`,
`PactNotFound`, `AlreadyJoined`, `NotParticipant`, `AlreadyResolved`,
`DeadlineNotPassed`, `PactClosed`.

## Calling via cast (read-only examples)

```bash
RPC=https://data-seed-prebsc-1-s1.binance.org:8545
PACT=<DEPLOYED_ADDRESS>   # fill in after testnet deploy

# How many pacts exist
cast call $PACT "totalPacts()" --rpc-url $RPC

# Full details of pact 0
cast call $PACT "getPact(uint256)(uint256,address,string,uint256,uint256,uint256,uint256,uint256)" 0 --rpc-url $RPC

# Does 0x... hold an Agent ID?
cast call 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F "balanceOf(address)(uint256)" 0x7fb95B2e1B4EFeba43fcFa1a9843ac04De5d2eEB --rpc-url $RPC
```

## Calling via cast (state-changing — needs an Agent ID holder key)

```bash
# Create a pact with a deadline 7 days from now
DEADLINE=$(($(date +%s) + 7*24*3600))
cast send $PACT "createPact(string,uint256)" "Ship my first dApp" $DEADLINE \
  --rpc-url $RPC --private-key <HOLDER_KEY>

# Join pact 0 / resolve pact 0 as kept
cast send $PACT "joinPact(uint256)" 0 --rpc-url $RPC --private-key <HOLDER_KEY>
cast send $PACT "resolvePact(uint256,bool)" 0 true --rpc-url $RPC --private-key <HOLDER_KEY>
```

Never use a real wallet key in scripts. Never ask a user for a seed phrase,
private key, API secret, or pairing code. Transactions must always be
confirmed by the user in their own wallet.

## Safety

This dApp never moves user funds: the contract holds no ETH/BNB, has no
transfer/approval functions, and promises no returns. It is not a tool for
looking up other people's wallets — Agent ID is only checked for the
caller's own address (`balanceOf(msg.sender) > 0`).
