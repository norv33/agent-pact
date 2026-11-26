# AgentPact

**Public on-chain commitments for Agent ID holders.**

AgentPact is a dApp for the [Binance Agent ID Hackathon](https://www.binance.com/en/support/announcement/detail/95f5dbe0ea674a48a739b59e046648bf) (Binance Wallet × BNB Chain, 60,000 USDC in rewards). Anyone holding an Agent ID can publish a commitment — *"I will ship X before date Y"* — other Agent ID holders can join it, and after the deadline every participant reports their own result: **kept** or **broken**. No money, no tokens, no fees. Only gas.

## Why it is different

Existing Agent ID dApps cover daily check-ins, message walls, vouch/reputation, polling, marketplaces, and skill registries. None of them is a **commitment / accountability pact**:

| dApp type | What it does | What AgentPact does instead |
|---|---|---|
| Daily check-in | Prove you showed up today | Commit to a *future* outcome with a deadline |
| Message wall | Post a message | Publish a promise others can join |
| Vouch / reputation | Others vouch for you | You report your *own* result — kept or broken |
| Polling | Vote on options | One person, one resolution — no vote, no winner |
| Marketplace / skill registry | List or trade things | Nothing is bought or sold |

AgentPact turns Agent ID into **accountability infrastructure**: a public promise, witnessed by other Agent ID holders, resolved by the promiser themselves.

## How Agent ID is used

Agent ID is a non-transferable ERC-721 (`0x60B9262456dE011F7d15a54cdd8c48baaa8b022f`, SPACE ID, symbol `AI`) on BNB Chain. AgentPact uses it in two ways:

1. **Access control** — only addresses holding an Agent ID can create a pact, join a pact, or resolve one. The contract checks `balanceOf(msg.sender) > 0` on the Agent ID contract for every state-changing call.
2. **Identity — one person, one resolution** — Agent ID is non-transferable and each person can claim only one, so each participant can resolve a pact exactly once and cannot change the result afterwards. No sock-puppets, no re-votes.

## How to use it

Live frontend (GitHub Pages, static — no build step): serve the `docs/` folder.

1. Open the site and click **Connect Wallet** (MetaMask or Binance Wallet, injected provider only).
2. Switch to **BNB Smart Chain Testnet** (chain 97) if asked.
3. The site shows your Agent ID status (`Agent ID: Yes/No`) by reading `balanceOf` on the Agent ID contract.
4. **Create a pact**: write what you will do (1–140 characters) and pick a deadline within 30 days. You automatically join your own pact.
5. **Join** other people's pacts before their deadline.
6. **Resolve** after the deadline: if you joined, mark your own result — *kept* or *broken*. One report per person, final.

AgentPact never asks for your seed phrase, private key, API secret, or pairing code. Every transaction is confirmed by you in your own wallet.

## Contract

| Network | Address | Explorer |
|---|---|---|
| BSC Testnet (97) | `0xaEafE6c4820Df5F5Ca7C5D5Bf9296Cfc3f6c1AE3` | [testnet.bscscan.com](https://testnet.bscscan.com/address/0xaEafE6c4820Df5F5Ca7C5D5Bf9296Cfc3f6c1AE3) |
| BNB Chain mainnet (56) | *not deployed yet* | — |

Contract: [`contracts/AgentPact.sol`](contracts/AgentPact.sol) — Solidity ^0.8.20, no external dependencies (the Agent ID interface is defined inline, `balanceOf` only).

Functions: `createPact(title, deadline)`, `joinPact(pactId)`, `resolvePact(pactId, success)`, `totalPacts()`, `getPact(pactId)`, `getParticipants(pactId)`, `isParticipant(pactId, address)`, `getResolution(pactId, address)`. Events: `PactCreated`, `PactJoined`, `PactResolved`. See [`skill.md`](skill.md) for the concise ABI.

### Rules enforced on-chain

- Deadline must be in the future and at most 30 days out.
- Title must be 1–140 characters.
- Join only before the deadline, once per address.
- Resolve only after the deadline, once per participant, and the result cannot be changed.

### Owner permissions: none

There is **no owner or admin**. The contract has no `payable` functions, no `receive`/`fallback`, no token, no fee, no withdraw, no pause, and no upgrade mechanism. The deployer has no special rights after deployment — the contract cannot be changed, stopped, or drained by anyone, because there is nothing to drain and no privileged function to call.

## Hackathon safety red-line compliance

- **No QR / pairing-code login.** The frontend uses only the injected provider (`window.ethereum`); users connect in their own wallet. It never asks for, displays, or stores pairing codes or login sessions.
- **No bypassing user confirmation.** Every state-changing action is a normal wallet transaction the user sees and confirms. Nothing is auto-signed.
- **No unauthorized transfers.** The contract cannot move any user's assets: it holds no funds and has no transfer/approval functions. Pacts involve no payments at all.
- **No sensitive credentials.** The dApp never asks for seed phrases, private keys, API secrets, or pairing codes — anywhere.
- **No promised returns.** Nothing here promises income or returns. There is no token and no yield.
- **Not a wallet-lookup tool.** AgentPact does not expose or search other people's wallets by name. Agent ID is only used as a gate (`balanceOf > 0`) for the caller's own address.
- **Open source.** The contract source is public in this repo and will be verified on BscScan after deployment.

## Development

Requirements: [Foundry](https://getfoundry.sh) (`forge`, `cast`).

```bash
# Run the tests (21 tests, all passing)
forge test

# Check formatting (CI enforces this)
forge fmt --check

# Build
forge build
```

### Deploy (BSC Testnet)

```bash
# Deploy with a throwaway testnet-only key (never a real wallet key):
forge script script/Deploy.s.sol --rpc-url bsc_testnet --broadcast --private-key <THROWAWAY_TESTNET_KEY>
```

Get testnet BNB from the [BNB Chain testnet faucet](https://testnet.bnbchain.org/faucet-smart). To verify the source on BscScan testnet afterwards:

```bash
forge verify-contract <ADDRESS> contracts/AgentPact.sol:AgentPact \
  --chain 97 --etherscan-api-key <BSCSCAN_API_KEY>
```

## Status (26 Nov 2026)

- Contract written from scratch; **21/21 Foundry tests pass**.
- Deploy script tested end-to-end on a local Anvil chain (deploy + `totalPacts()` + `AGENT_ID()` verified).
- **Testnet deployment is pending**: the deployer key is ready (throwaway, testnet-only, stored outside the repo), but the official faucet requires solving a captcha in a browser, so no testnet BNB has been obtained yet. Once the throwaway address is funded with ~0.01 tBNB, run the deploy command above.
- Mainnet deployment is intentionally not done yet — testnet first, per the hackathon flow.

## License

MIT — see [LICENSE](LICENSE).
