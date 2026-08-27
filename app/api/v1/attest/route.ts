import { requireApiAuthorization } from "@/lib/chlom/auth";
import { errorResponse } from "@/lib/chlom/errors";
import { prepareAnchorIntent } from "@/lib/chlom/evidence";
import { anchorRequestSchema } from "@/lib/chlom/schemas";

export const runtime = "nodejs";

export async function POST(request: Request) {
  try {
    requireApiAuthorization(request);
    const input = anchorRequestSchema.parse(await request.json());
    return Response.json({
      ok: true,
      anchorIntent: prepareAnchorIntent(
        input.evidenceDigest,
        input.targetChain,
      ),
    });
  } catch (error) {
    return errorResponse(error);
  }
}
