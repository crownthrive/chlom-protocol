import { requireApiAuthorization } from "@/lib/chlom/auth";
import { runBlockchainAnalytics } from "@/lib/chlom/bigquery";
import { errorResponse } from "@/lib/chlom/errors";
import { analyticsRequestSchema } from "@/lib/chlom/schemas";

export const runtime = "nodejs";
export const maxDuration = 60;

export async function POST(request: Request) {
  try {
    requireApiAuthorization(request);
    const input = analyticsRequestSchema.parse(await request.json());
    const envelope = await runBlockchainAnalytics(input);
    return Response.json({ ok: true, envelope });
  } catch (error) {
    return errorResponse(error);
  }
}
