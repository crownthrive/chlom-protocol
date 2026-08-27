import { createMcpHandler } from "mcp-handler";
import { z } from "zod";
import { requireApiAuthorization } from "@/lib/chlom/auth";
import { CHAIN_KEYS } from "@/lib/chlom/chains";
import { runtimeReadiness } from "@/lib/chlom/config";
import { prepareAnchorIntent } from "@/lib/chlom/evidence";
import { runBlockchainAnalytics } from "@/lib/chlom/bigquery";
import { callGovernedRpc } from "@/lib/chlom/rpc";
import { errorResponse } from "@/lib/chlom/errors";

export const runtime = "nodejs";
export const maxDuration = 60;

const analyticsTemplate = z.enum([
  "latest_block",
  "transaction_evidence",
  "address_activity",
  "contract_logs",
]);

const handler = createMcpHandler(
  (server) => {
    server.registerTool(
      "chlom_provider_status",
      {
        title: "CHLOM Provider Status",
        description:
          "Reports configured CHLOM RPC, Google Blockchain Analytics, governance, and authority readiness without disclosing secrets.",
        inputSchema: z.object({}),
      },
      async () => ({
        content: [
          {
            type: "text",
            text: JSON.stringify(runtimeReadiness(), null, 2),
          },
        ],
      }),
    );

    server.registerTool(
      "chlom_chain_read",
      {
        title: "CHLOM Governed Chain Read",
        description:
          "Executes one allowlisted read-only JSON-RPC method against a server-configured blockchain provider and returns a CHLOM evidence envelope.",
        inputSchema: z.object({
          chain: z.enum(CHAIN_KEYS),
          method: z.string().min(1).max(128),
          params: z.array(z.unknown()).max(64).default([]),
        }),
      },
      async (input) => {
        const envelope = await callGovernedRpc(input);
        return {
          content: [
            { type: "text", text: JSON.stringify(envelope, null, 2) },
          ],
        };
      },
    );

    server.registerTool(
      "chlom_verify_transaction",
      {
        title: "CHLOM Verify Transaction",
        description:
          "Reads a transaction receipt through the governed RPC fabric and returns deterministic evidence.",
        inputSchema: z.object({
          chain: z.enum(CHAIN_KEYS),
          transactionHash: z.string().regex(/^0x[0-9a-fA-F]+$/),
        }),
      },
      async ({ chain, transactionHash }) => {
        const envelope = await callGovernedRpc({
          chain,
          method: "eth_getTransactionReceipt",
          params: [transactionHash],
        });
        return {
          content: [
            { type: "text", text: JSON.stringify(envelope, null, 2) },
          ],
        };
      },
    );

    server.registerTool(
      "chlom_query_blockchain_analytics",
      {
        title: "CHLOM Google Blockchain Analytics",
        description:
          "Runs one bounded, allowlisted Google Blockchain Analytics query template through BigQuery.",
        inputSchema: z.object({
          chain: z.enum(CHAIN_KEYS),
          template: analyticsTemplate,
          transactionHash: z.string().optional(),
          address: z.string().optional(),
          lookbackDays: z.number().int().min(1).max(31).optional(),
          limit: z.number().int().min(1).max(250).optional(),
        }),
      },
      async (input) => {
        const envelope = await runBlockchainAnalytics(input);
        return {
          content: [
            { type: "text", text: JSON.stringify(envelope, null, 2) },
          ],
        };
      },
    );

    server.registerTool(
      "chlom_prepare_evidence_anchor",
      {
        title: "CHLOM Prepare Evidence Anchor",
        description:
          "Creates a deterministic anchor intent for a CHLOM evidence digest. This tool never broadcasts a transaction.",
        inputSchema: z.object({
          evidenceDigest: z.string().regex(/^[0-9a-f]{64}$/),
          targetChain: z.enum(["base", "base-sepolia", "ethereum"]),
        }),
      },
      async ({ evidenceDigest, targetChain }) => ({
        content: [
          {
            type: "text",
            text: JSON.stringify(
              prepareAnchorIntent(evidenceDigest, targetChain),
              null,
              2,
            ),
          },
        ],
      }),
    );
  },
  {
    serverInfo: {
      name: "crownthrive-chlom-chain-evidence-fabric",
      version: "1.0.0",
    },
  },
);

async function authorizedHandler(request: Request): Promise<Response> {
  try {
    requireApiAuthorization(request);
    return handler(request);
  } catch (error) {
    return errorResponse(error);
  }
}

export {
  authorizedHandler as GET,
  authorizedHandler as POST,
  authorizedHandler as DELETE,
};
