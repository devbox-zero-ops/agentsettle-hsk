# AgentSettle HSK — Programmable AI Agent Payment Mandates & Verifiable A2A Settlement

Built for **HSK Chain Horizon Hackathon (DoraHacks)** on **HashKey Chain Testnet (Chain ID `133`)** — *Agent Payments & A2A Settlement Track*.

- **Live Web3 App**: https://devbox-zero-ops.github.io/agentsettle-hsk/
- **Network**: HashKey Chain Testnet (`Chain ID: 133 / 0x85`, RPC: `https://testnet.hsk.xyz`)
- **Explorer**: https://testnet-explorer.hskchain.net

## Key Capabilities
1. **On-Chain Agent Guardrails (`createMandate`)**: Owners grant AI agents scoped spending authority with `maxPerTx`, rolling `dailyLimit`, and hard `expiresAt` deadlines (supporting native HSK or ERC-20 stablecoins like USDT/USDC).
2. **Verifiable A2A Settlement (`executeAgentSettlement`)**: Authorized agents settle autonomously while anchoring a `keccak256(executionLog)` verifiable memory hash on-chain for auditability.
3. **Instant Kill-Switch (`revokeMandate`)**: Owners can revoke an agent mandate at any time and reclaim 100% of unspent vault funds in one transaction.

## Local Verification
```bash
node --test test/vault.test.mjs
```
