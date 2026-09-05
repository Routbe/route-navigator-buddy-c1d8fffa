import { neon, type NeonQueryFunction } from "@neondatabase/serverless";

/**
 * Server-only Neon Postgres client for project ROUT.
 *
 * The client is created lazily on first query so that a missing DATABASE_URL
 * does not crash module evaluation (which would blank the whole app). Only
 * import this in server functions, API route handlers, or other server-only
 * modules — DATABASE_URL is never exposed to the client bundle.
 */
let client: NeonQueryFunction<false, false> | null = null;

function getClient(): NeonQueryFunction<false, false> {
  if (client) return client;
  const connectionString = process.env["DATABASE_URL"];
  if (!connectionString) {
    throw new Error("DATABASE_URL is not configured for the Neon database connection.");
  }
  client = neon(connectionString);
  return client;
}

export const sql = new Proxy(function () {} as unknown as NeonQueryFunction<false, false>, {
  apply: (_target, _thisArg, args) =>
    (getClient() as unknown as (...queryArgs: unknown[]) => unknown)(...args),
  get: (_target, property) => {
    const value = (getClient() as unknown as Record<string | symbol, unknown>)[property];
    return typeof value === "function" ? value.bind(getClient()) : value;
  },
}) as NeonQueryFunction<false, false>;
