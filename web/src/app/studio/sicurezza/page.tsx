import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { Suspense } from "react";
import { Loading, Notice, PageTitle } from "@/components/ui";
import { sessionUser } from "@/server/page";
import { TwoFactorSetup } from "./two-factor-setup";

export const metadata: Metadata = { title: "Sicurezza" };

export default function SecurityPage() {
  return (
    <div className="max-w-xl">
      <PageTitle>Sicurezza</PageTitle>
      <Suspense fallback={<Loading />}>
        <SecurityContent />
      </Suspense>
    </div>
  );
}

// Reachable without 2FA on purpose: this is where staff turn it on.
async function SecurityContent() {
  const user = await sessionUser();
  if (!user) redirect("/accedi");
  if (user.twoFactorEnabled) {
    return (
      <Notice tone="success">
        La verifica in due passaggi è attiva. A ogni accesso ti chiederemo il codice della tua app di autenticazione.
      </Notice>
    );
  }
  return <TwoFactorSetup />;
}
