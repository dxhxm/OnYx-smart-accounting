import { register } from "@/lib/metrics";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET() {
  const metrics = await register.metrics();
  return new Response(metrics, {
    status: 200,
    headers: {
      "Content-Type": register.contentType,
      "Cache-Control": "no-store, no-cache, must-revalidate",
    },
  });
}
