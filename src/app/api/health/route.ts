import { NextResponse } from "next/server";
import { httpRequestsTotal, httpRequestDurationSeconds } from "@/lib/metrics";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET() {
  const start = process.hrtime();
  const status = "200";
  const route = "/api/health";
  const method = "GET";

  try {
    const response = NextResponse.json({
      status: "ok",
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
    });

    return response;
  } finally {
    const diff = process.hrtime(start);
    const durationSeconds = diff[0] + diff[1] / 1e9;

    httpRequestsTotal.inc({ method, route, status });
    httpRequestDurationSeconds.observe({ method, route, status }, durationSeconds);
  }
}
