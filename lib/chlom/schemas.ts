import { z } from "zod";
import { CHAIN_KEYS } from "./chains";

export const rpcRequestSchema = z.object({
  chain: z.enum(CHAIN_KEYS),
  method: z.string().min(1).max(128),
  params: z.array(z.unknown()).max(64).default([]),
});

export const analyticsRequestSchema = z.object({
  chain: z.enum(CHAIN_KEYS),
  template: z.enum([
    "latest_block",
    "transaction_evidence",
    "address_activity",
    "contract_logs",
  ]),
  transactionHash: z.string().optional(),
  address: z.string().optional(),
  lookbackDays: z.number().int().min(1).max(31).optional(),
  limit: z.number().int().min(1).max(250).optional(),
});

export const anchorRequestSchema = z.object({
  evidenceDigest: z.string().regex(/^[0-9a-f]{64}$/),
  targetChain: z.enum(["base", "base-sepolia", "ethereum"]),
});
