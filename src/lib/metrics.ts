import { Registry, collectDefaultMetrics, Counter, Histogram } from "prom-client";

// Global singleton to avoid duplicate metric registrations during Next.js hot-reloading
const globalForMetrics = globalThis as unknown as {
  onyxRegister?: Registry;
  httpRequestsCounter?: Counter<"method" | "route" | "status">;
  httpRequestDuration?: Histogram<"method" | "route" | "status">;
};

export const register = globalForMetrics.onyxRegister ?? new Registry();

if (!globalForMetrics.onyxRegister) {
  // Collect Node.js engine vitals (Heap memory, Event Loop, Garbage Collection)
  collectDefaultMetrics({ register, prefix: "onyx_" });
  globalForMetrics.onyxRegister = register;
}

export const httpRequestsTotal =
  globalForMetrics.httpRequestsCounter ??
  new Counter({
    name: "onyx_http_requests_total",
    help: "Total number of HTTP requests processed by OnYx",
    labelNames: ["method", "route", "status"],
    registers: [register],
  });

export const httpRequestDurationSeconds =
  globalForMetrics.httpRequestDuration ??
  new Histogram({
    name: "onyx_http_request_duration_seconds",
    help: "HTTP request latency in seconds across buckets",
    labelNames: ["method", "route", "status"],
    buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5],
    registers: [register],
  });

if (!globalForMetrics.httpRequestsCounter) {
  globalForMetrics.httpRequestsCounter = httpRequestsTotal;
  globalForMetrics.httpRequestDuration = httpRequestDurationSeconds;
}
