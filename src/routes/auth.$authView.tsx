import { createFileRoute } from "@tanstack/react-router";
import { AuthView } from "@neondatabase/neon-js/auth/react/ui";

/**
 * Neon Auth views: /auth/sign-in, /auth/sign-up, /auth/magic-link,
 * /auth/forgot-password, /auth/reset-password, …
 */
export const Route = createFileRoute("/auth/$authView")({
  head: () => ({
    meta: [
      { title: "Inloggen of aanmelden bij ROUT" },
      {
        name: "description",
        content: "Meld je aan of maak een account om je QR-codes en korte links te beheren.",
      },
      { property: "og:title", content: "Inloggen of aanmelden bij ROUT" },
      {
        property: "og:description",
        content: "Meld je aan of maak een account om je QR-codes en korte links te beheren.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: NeonAuthPage,
});

function NeonAuthPage() {
  const { authView } = Route.useParams();

  return (
    <div className="flex min-h-screen items-center justify-center bg-background px-4 py-12">
      <AuthView path={authView} />
    </div>
  );
}
