import { neon as neonSql, type NeonQueryFunction } from "@neondatabase/serverless";
import { createClient } from "@neondatabase/neon-js";
import { BetterAuthReactAdapter } from "@neondatabase/neon-js/auth/react/adapters";

/**
 * Neon-clients voor project ROUT.
 *
 * `neon`  — Neon Auth (Better Auth) client voor de browser: sign-up, sign-in
 *           en sessiebeheer via de Neon Auth service. Veilig voor de client
 *           bundle; de URL is publiek (VITE_NEON_AUTH_URL).
 *
 * `sql`   — Server-only Neon Postgres client. De driver wordt lazy aangemaakt
 *           zodat een ontbrekende DATABASE_URL de module-evaluatie niet laat
 *           crashen. Alleen gebruiken in server functions of route handlers;
 *           DATABASE_URL komt nooit in de client bundle terecht.
 */

const NEON_AUTH_URL =
  import.meta.env.VITE_NEON_AUTH_URL ??
  "https://ep-autumn-salad-b1wk95js.neonauth.c-5.eu-central-1.aws.neon.tech/neondb/auth";

export const neon = createClient({
  auth: {
    url: NEON_AUTH_URL,
    adapter: BetterAuthReactAdapter(),
  },
});

let client: NeonQueryFunction<false, false> | null = null;

function getClient(): NeonQueryFunction<false, false> {
  if (client) return client;
  const connectionString = process.env["DATABASE_URL"];
  if (!connectionString) {
    throw new Error("DATABASE_URL is not configured for the Neon database connection.");
  }
  client = neonSql(connectionString);
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
