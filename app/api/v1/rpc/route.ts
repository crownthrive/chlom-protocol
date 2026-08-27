import { requireApiAuthorization, assertWriteAuthority } from "@/lib/chlom/auth";
import { classifyRpcMethod, callGovernedRpc } from "@/lib/chlom/rpc";
import { rpcRequestSchema } from "@/lib/chlom/schemas";
import { errorResponse } from "@/lib/chlom/errors";

export const runtime = "nodejs";
export const maxDuration = 30;

export async function POST(request: Request) {
  try {
    requireApiAuthorization(request);
    const input = rpcRequestSchema.parse(await request.json());
    const mode = classifyRpcMethod(input.method);

    if (mode === "write") {
      assertWriteAuthority(request);
    }

    const envelope = await callGovernedRpc({
      ...input,
      writeAuthorized: mode === "write",
    });
    return Response.json({ ok: true, envelope });
  } catch (error) {
    return errorResponse(error);
  }
}
