import type { Metadata } from "next";
import Link from "next/link";
import { Suspense } from "react";
import { Loading, PageTitle, Panel } from "@/components/ui";
import { ROLE_LABEL } from "@/lib/labels";
import { disciplinesOf, listCare, listInvitations } from "@/server/care";
import { requirePage } from "@/server/page";
import { InviteForm } from "./invite-form";
import { RevokeInvitation } from "./revoke-invitation";

export const metadata: Metadata = { title: "Clienti" };

export default function ClientsPage() {
  return (
    <>
      <PageTitle>Clienti</PageTitle>
      <Suspense fallback={<Loading />}>
        <ClientsContent />
      </Suspense>
    </>
  );
}

const dateFormat = new Intl.DateTimeFormat("it-IT", { day: "numeric", month: "long" });

async function ClientsContent() {
  const { actor, db } = await requirePage("staff", "admin");
  const [care, invitations, disciplines] = await Promise.all([
    listCare(db, actor),
    listInvitations(db, actor),
    disciplinesOf(db, actor.id),
  ]);
  const pendingClients = invitations.filter((invitation) => invitation.kind === "client");

  return (
    <div className="grid gap-8 xl:grid-cols-[minmax(0,1fr)_22rem]">
      <section aria-label="Clienti seguiti">
        {care.length === 0 ? (
          <p className="max-w-prose text-ash">
            Non segui ancora nessun cliente. Invitane uno con il modulo qui accanto: riceverà una mail per creare
            l&apos;account e dare il consenso.
          </p>
        ) : (
          <ul className="divide-y divide-seam border-y border-seam">
            {care.map((entry) => (
              <li key={entry.id}>
                <Link
                  href={`/studio/clienti/${entry.person.id}`}
                  className="grid grid-cols-[1fr_auto] items-baseline gap-x-6 gap-y-1 px-1 py-4 hover:bg-graphite sm:grid-cols-[1fr_12rem_auto]"
                >
                  <span className="text-lg font-semibold">{entry.person.name}</span>
                  <span className="hidden text-sm text-ash sm:block">{ROLE_LABEL[entry.role] ?? entry.role}</span>
                  <span className={entry.status === "pending" ? "text-sm text-amber" : "text-sm text-ash"}>
                    {entry.status === "pending" ? "In attesa del consenso" : "Attivo"}
                  </span>
                  <span className="col-span-full text-sm text-ash">{entry.person.email}</span>
                </Link>
              </li>
            ))}
          </ul>
        )}
      </section>

      <aside className="flex flex-col gap-6">
        <Panel title="Invita un cliente">
          <InviteForm disciplines={disciplines} />
        </Panel>
        {pendingClients.length > 0 && (
          <Panel title="Inviti in attesa">
            <ul className="flex flex-col gap-3">
              {pendingClients.map((invitation) => (
                <li key={invitation.id} className="flex items-center justify-between gap-3 text-sm">
                  <span className="min-w-0">
                    <span className="block truncate">{invitation.email}</span>
                    <span className="text-ash">Scade il {dateFormat.format(invitation.expiresAt)}</span>
                  </span>
                  <RevokeInvitation id={invitation.id} />
                </li>
              ))}
            </ul>
          </Panel>
        )}
      </aside>
    </div>
  );
}
