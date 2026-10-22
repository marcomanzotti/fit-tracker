import type { Metadata } from "next";
import { Suspense } from "react";
import { Loading, Panel } from "@/components/ui";
import { listItalian, ROLE_LABEL, SCOPE_LABEL } from "@/lib/labels";
import { getMe } from "@/server/account";
import { requirePage } from "@/server/page";
import { CareActions, ConsentToggle, DeleteAccount, SignOut } from "./profile-actions";

export const metadata: Metadata = { title: "Profilo" };

export default function ProfilePage() {
  return (
    <div className="flex flex-col gap-6">
      <h1 className="condensed text-4xl font-bold leading-none">Profilo</h1>
      <Suspense fallback={<Loading />}>
        <ProfileContent />
      </Suspense>
    </div>
  );
}

async function ProfileContent() {
  const { actor, db } = await requirePage("client");
  const me = await getMe(db, actor);

  return (
    <>
      <div>
        <p className="text-lg font-semibold">{me.user.name}</p>
        <p className="text-ash">{me.user.email}</p>
      </div>

      <Panel title="Chi ti segue">
        {me.care.length === 0 ? (
          <p className="text-sm text-ash">Nessun professionista ti segue al momento.</p>
        ) : (
          <ul className="flex flex-col gap-4">
            {me.care.map((entry) => (
              <li key={entry.id} className="flex flex-col gap-1">
                <p>
                  <strong>{entry.person.name}</strong>, {ROLE_LABEL[entry.role] ?? entry.role}
                </p>
                <p className="text-sm text-ash">Vede {listItalian(entry.scopes.map((scope) => SCOPE_LABEL[scope] ?? scope))}.</p>
                <CareActions assignmentId={entry.id} status={entry.status} name={entry.person.name} />
              </li>
            ))}
          </ul>
        )}
      </Panel>

      <Panel title="Privacy">
        <div className="flex flex-col gap-4">
          <ConsentToggle
            purpose="health_processing"
            granted={me.consents.health_processing?.granted ?? false}
            label="Trattamento dei dati di salute"
            hint="Senza questo consenso nessun professionista può più vedere i tuoi dati e non puoi registrare allenamenti."
          />
          <ConsentToggle
            purpose="aggregate_insights"
            granted={me.consents.aggregate_insights?.granted ?? false}
            label="Statistiche anonime"
            hint="I tuoi dati entrano, senza nome, in statistiche su gruppi di almeno 10 persone."
          />
          <a href="/api/v1/me/export" className="text-sm text-chalk underline underline-offset-4">
            Scarica tutti i tuoi dati (JSON)
          </a>
        </div>
      </Panel>

      <div className="flex flex-col gap-3">
        <SignOut />
        <DeleteAccount />
      </div>
    </>
  );
}
