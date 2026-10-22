"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { api } from "@/lib/api";

// Stops a pending invitation (for example sent to a mistyped address).
export function RevokeInvitation({ id }: { id: string }) {
  const router = useRouter();
  const [state, setState] = useState<"idle" | "busy" | "failed">("idle");

  async function revoke() {
    setState("busy");
    try {
      await api(`/api/v1/invitations/${id}/revoke`, { body: {} });
      router.refresh();
    } catch {
      setState("failed");
    }
  }

  return (
    <button
      type="button"
      onClick={revoke}
      disabled={state === "busy"}
      className="shrink-0 rounded-[var(--radius-control)] px-2 py-1 text-ash hover:text-alert disabled:opacity-50"
    >
      {state === "failed" ? "Riprova" : "Annulla"}
    </button>
  );
}
