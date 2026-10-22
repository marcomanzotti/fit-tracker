import type { Metadata } from "next";
import Link from "next/link";
import { APP, PRIVACY_POLICY_VERSION } from "@/config";

export const metadata: Metadata = { title: "Informativa privacy" };

// Draft notice (docs/gdpr.md): to be reviewed by the privacy consultant before
// launch. Bump PRIVACY_POLICY_VERSION whenever this text changes.
export default function PrivacyPage() {
  return (
    <main className="mx-auto w-full max-w-2xl px-5 py-12 leading-relaxed">
      <Link href="/" className="text-sm text-ash hover:text-chalk">
        {APP.name}
      </Link>
      <h1 className="condensed mt-6 mb-2 text-4xl font-bold leading-none">Informativa privacy</h1>
      <p className="mb-10 text-sm text-ash">Versione {PRIVACY_POLICY_VERSION} (bozza in revisione)</p>

      <div className="flex flex-col gap-8 [&_h2]:mb-2 [&_h2]:text-xl [&_h2]:font-semibold [&_p]:text-chalk/90">
        <section>
          <h2>Quali dati trattiamo</h2>
          <p>
            Il tuo account (nome, email), i dati che registri o che arrivano dalle app di salute (allenamenti, peso e misure,
            sonno, frequenza cardiaca e HRV, alimentazione) e le schede preparate dai professionisti dello studio. I dati di
            salute sono una categoria particolare: li trattiamo solo con il tuo consenso esplicito.
          </p>
        </section>
        <section>
          <h2>Perché</h2>
          <p>
            Per darti il servizio: le schede, i suggerimenti di carico, il monitoraggio dei progressi. Ogni professionista
            che ti segue vede solo i dati legati al suo ruolo, e solo dopo che hai acconsentito. Ogni accesso ai tuoi dati
            viene registrato e puoi vederlo nell&apos;export.
          </p>
        </section>
        <section>
          <h2>Cosa non facciamo</h2>
          <p>Non vendiamo i tuoi dati e non li usiamo per pubblicità.</p>
        </section>
        <section>
          <h2>Statistiche e ricerca (facoltativo)</h2>
          <p>
            Con un consenso separato, che puoi negare o revocare senza conseguenze sul servizio, i tuoi dati possono entrare
            senza nome in statistiche su gruppi di almeno 10 persone. Per eventuali studi di ricerca ti chiederemo ogni volta
            un consenso specifico.
          </p>
        </section>
        <section>
          <h2>Dove e per quanto</h2>
          <p>
            Su server nell&apos;Unione Europea, finché hai un account. Le copie di sicurezza sono cifrate e vengono
            sovrascritte entro 30 giorni.
          </p>
        </section>
        <section>
          <h2>I tuoi diritti</h2>
          <p>
            Dal tuo profilo puoi scaricare tutti i tuoi dati, revocare i consensi, smettere di condividere i dati con un
            professionista e cancellare l&apos;account con tutti i dati.
          </p>
        </section>
      </div>
    </main>
  );
}
