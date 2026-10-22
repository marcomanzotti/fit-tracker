import type { Metadata } from "next";
import Link from "next/link";
import { Suspense } from "react";
import { Loading, PageTitle } from "@/components/ui";
import { listCare } from "@/server/care";
import { requirePage } from "@/server/page";
import { listPrograms } from "@/server/programs";
import { AssignTemplate, NewTemplateButton } from "./template-actions";

export const metadata: Metadata = { title: "Template" };

export default function TemplatesPage() {
  return (
    <>
      <PageTitle aside={<NewTemplateButton />}>Template</PageTitle>
      <Suspense fallback={<Loading />}>
        <TemplatesContent />
      </Suspense>
    </>
  );
}

const updatedFormat = new Intl.DateTimeFormat("it-IT", { day: "numeric", month: "short" });

async function TemplatesContent() {
  const { actor, db } = await requirePage("staff", "admin");
  const [templates, care] = await Promise.all([listPrograms(db, actor, {}), listCare(db, actor)]);
  const clients = care.filter((entry) => entry.status === "active").map((entry) => entry.person);

  if (templates.length === 0) {
    return (
      <p className="max-w-prose text-ash">
        I template sono schede pronte da riusare: scrivila una volta, poi assegnala a più clienti. Ognuno riceve una copia
        da adattare, senza toccare il template.
      </p>
    );
  }

  return (
    <ul className="divide-y divide-seam border-y border-seam">
      {templates.map((template) => (
        <li key={template.id} className="flex flex-wrap items-center justify-between gap-4 py-4">
          <Link href={`/studio/schede/${template.id}`} className="min-w-0 hover:text-signal">
            <span className="block text-lg font-semibold">{template.title}</span>
            <span className="text-sm text-ash">Modificato il {updatedFormat.format(template.updatedAt)}</span>
          </Link>
          <AssignTemplate templateId={template.id} clients={clients} />
        </li>
      ))}
    </ul>
  );
}
