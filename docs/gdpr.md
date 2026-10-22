# Protezione dei dati: registro dei trattamenti e bozza DPIA

> **Bozza tecnica** scritta durante lo sviluppo (fase F0, 22/10/2026).
> Non è un parere legale: va rivista da un consulente privacy/DPO prima di aprire il servizio ai clienti.
> Le scelte tecniche sono descritte in [ADR-0005](adr/0005-data-protection.md).

## 1. Ruoli (da confermare col consulente)

- **Titolare:** lo studio, che offre il servizio ai propri clienti.
- **Responsabili (art. 28):**
  - chi sviluppa e gestisce la piattaforma
  - Hetzner (hosting e backup, UE)
  - il fornitore di email transazionali (da scegliere in UE)
- **Interessati:** clienti dello studio (anche persone che si registrano da sole) e professionisti dello staff.

## 2. Registro dei trattamenti

| Trattamento | Finalità | Base giuridica | Dati | Conservazione |
|---|---|---|---|---|
| Account | Accesso al servizio | Contratto (art. 6.1.b) | Nome, email, password (hash), ruolo | Fino alla cancellazione dell'account |
| Sessioni | Tenere l'utente collegato, sicurezza | Contratto + art. 32 | IP e user agent per sessione; i log del server possono contenere l'email nei tentativi di registrazione | Scadenza della sessione (7 giorni); log da limitare a 30 giorni (da confermare) |
| Dati di salute e allenamento | Erogare il coaching: schede, monitoraggio, metriche | Consenso esplicito (art. 9.2.a) + contratto | Allenamenti, sonno, FC, HRV, peso, composizione, alimentazione, misure, dati da Health Connect | Fino alla cancellazione o alla revoca del consenso |
| Condivisione con lo staff | Permettere al professionista assegnato di seguire il cliente | Consenso esplicito per professionista | Solo gli scope dell'assegnazione | Finché l'assegnazione è attiva; poi nessun nuovo accesso |
| Registro accessi | Sicurezza e responsabilità | Obbligo e legittimo interesse (art. 32) | Chi ha letto o modificato quali dati, quando, da quale IP | 12 mesi (da confermare) |
| Statistiche aggregate | Insight anonimi sul servizio e per partner | Consenso facoltativo separato | Solo aggregati su gruppi di almeno 10 persone | Gli aggregati anonimi non sono dati personali |
| Ricerca | Dataset per studi con partner | Consenso facoltativo per singolo studio + accordo col partner | Dati pseudonimizzati con id diverso per ogni studio | Secondo il protocollo dello studio |
| Backup | Continuità del servizio | Legittimo interesse / art. 32 | Copia cifrata del database | 30 giorni, poi sovrascritti |

## 3. Misure tecniche e organizzative

- **Infrastruttura:** hosting in UE; HTTPS ovunque; backup cifrati con prova di ripristino mensile.
- **Account:** password sotto hash (Better Auth); verifica dell'email; rate limit su login e API; 2FA obbligatoria per lo staff.
- **Accessi dello staff:** scope per ruolo; ogni lettura passa dalla guardia `withClientAccess` e finisce nel registro accessi.
- **Minimizzazione:** si raccoglie un tipo di dato solo se una funzione lo mostra; permessi Health Connect chiesti quando servono.
- **Diritti degli interessati:** export completo dei dati (art. 20) e cancellazione dell'account (art. 17) da app e web; la revoca di un consenso ferma il trattamento corrispondente.
- **Esclusioni:** nessuna vendita di dati individuali, nessun uso pubblicitario (anche per la policy Health Connect).

## 4. DPIA: rischi principali (bozza)

| Rischio | Impatto | Misure |
|---|---|---|
| Un professionista vede dati non necessari | Medio | Scope per assegnazione, test di permesso per ogni ruolo, registro accessi |
| Furto di credenziali dello staff | Alto | 2FA obbligatoria, sessioni revocabili, rate limit |
| Violazione del server o dei backup | Alto | Aggiornamenti, firewall, accesso SSH solo con chiave, backup cifrati, piano di notifica entro 72 ore |
| Re-identificazione da statistiche o dataset di ricerca | Alto | Soglia di almeno 10 persone per gruppo, pseudonimi diversi per studio, nessun campo identificativo nei dataset |
| Trasferimento fuori UE (email, notifiche push FCM) | Medio | Fornitori UE dove possibile; per FCM nessun dato di salute nel contenuto delle notifiche |
| Indicazioni sbagliate da metriche errate | Medio | Formule validate e testate, avvisi "non è un consiglio medico", il professionista resta nel processo |

## 5. Domande aperte per il consulente

1. Chi è titolare e chi responsabile tra lo studio e chi sviluppa la piattaforma?
2. I clienti che si registrano da soli, senza uno studio, che ruolo hanno?
3. Per quanto conservare il registro accessi?
4. Qual è la base giuridica corretta per le statistiche aggregate anonime, e serve un consenso?
5. I dataset di ricerca richiedono un comitato etico? La policy Health Connect lo può richiedere.
6. Che testi servono per informativa e consensi, e in quali lingue (it/en)?
