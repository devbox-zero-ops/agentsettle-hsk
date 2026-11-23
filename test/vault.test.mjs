import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

const RPC_URL = "https://testnet.hsk.xyz";
const EXPECTED_CHAIN_ID = 133;

async function rpc(method, params = []) {
  const res = await fetch(RPC_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params }),
  });
  assert.equal(res.status, 200);
  const data = await res.json();
  assert.ok(!data.error, `RPC error: ${JSON.stringify(data.error)}`);
  return data.result;
}

test("Compiled AgentSettlementVault artifact exposes full mandate & A2A ABI", () => {
  const art = JSON.parse(fs.readFileSync(path.resolve("artifacts/AgentSettlementVault.json"), "utf8"));
  assert.equal(art.contractName, "AgentSettlementVault");
  assert.equal(art.chainId, EXPECTED_CHAIN_ID);
  assert.ok(art.bytecode.startsWith("0x") && art.bytecode.length > 2000);
  const fns = new Set(art.abi.filter((x) => x.type === "function").map((x) => x.name));
  for (const name of ["createMandate", "fundMandateERC20", "executeAgentSettlement", "revokeMandate", "mandates", "settlements"]) {
    assert.ok(fns.has(name), `Missing ABI function ${name}`);
  }
});

test("HashKey Chain Testnet RPC responds with Chain ID 133 and positive block height", async () => {
  const cid = await rpc("eth_chainId");
  assert.equal(parseInt(cid, 16), EXPECTED_CHAIN_ID);
  const bn = await rpc("eth_blockNumber");
  assert.ok(parseInt(bn, 16) > 0);
});
