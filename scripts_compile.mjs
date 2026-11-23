import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const solc = require("e:/ai赚钱/projects/aevumpay/node_modules/solc");

const proj = "e:/ai赚钱/projects/agentsettle-hsk";
const src = fs.readFileSync(path.join(proj, "contracts/AgentSettlementVault.sol"), "utf8");
const input = {
  language: "Solidity",
  sources: { "AgentSettlementVault.sol": { content: src } },
  settings: {
    optimizer: { enabled: true, runs: 200 },
    outputSelection: { "*": { "*": ["abi", "evm.bytecode.object"] } }
  }
};
const out = JSON.parse(solc.compile(JSON.stringify(input)));
if (out.errors) {
  for (const e of out.errors) console.log(e.severity.toUpperCase(), e.formattedMessage);
  if (out.errors.some(e => e.severity === "error")) process.exit(1);
}
const c = out.contracts["AgentSettlementVault.sol"]["AgentSettlementVault"];
fs.mkdirSync(path.join(proj, "artifacts"), { recursive: true });
fs.writeFileSync(path.join(proj, "artifacts/AgentSettlementVault.json"), JSON.stringify({
  contractName: "AgentSettlementVault",
  compiler: "solc 0.8.20 (optimizer 200)",
  chainId: 133,
  network: "HashKey Chain Testnet",
  rpc: "https://testnet.hsk.xyz",
  abi: c.abi,
  bytecode: "0x" + c.evm.bytecode.object
}, null, 2));
console.log("COMPILED OK | ABI items:", c.abi.length, "| Bytecode bytes:", c.evm.bytecode.object.length / 2);
