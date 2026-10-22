# ADR-0003: Scheda come documento versionato e risolto dal server

**Data**: 2026-10-22
**Stato**: accettato (si implementa nella fase F2)
**Decisori**: Marco Manzotti, Claude

## Contesto

I PT scrivono le schede in Excel: settimane in colonna, esercizi in riga, carichi in kg, %1RM o RPE. Il prodotto deve fare lo stesso in modo strutturato:
- il PT modifica la scheda del cliente;
- il cliente la segue dall'app;
- ogni allenamento si confronta con la prescrizione che il cliente aveva davanti in quel momento.

## Decisione

**Tabelle e documento**
- `program`: cliente o template, con la bozza in `jsonb`.
- `program_version`: un documento immutabile per ogni pubblicazione.
- Il documento è validato da zod. Struttura: fasi/settimane → giorni → blocchi (singolo, superserie, circuito) → esercizi, con prescrizioni per settimana e regole di progressione.
- Gli id delle prescrizioni restano stabili tra le versioni.

**Risoluzione**
- La funzione `resolve(contenuto, settimana, massimali)` produce target concreti in kg.
- Web e Android ricevono la scheda già risolta.
- Ogni sessione salva versione, giorno, settimana e un'istantanea del target.

**Editor**
- Griglia tipo foglio di calcolo, con celle in forma abbreviata: `4x8-10@RIR2`, `3x5@75%`.
- Incolla da Excel e esporta in PDF.

## Alternative considerate

### Tabelle normalizzate per ogni livello (giorni, blocchi, prescrizioni)
- **Pro**: query SQL dirette su ogni prescrizione.
- **Contro**: per salvare, pubblicare e copiare una scheda servono decine di righe da aggiornare.
- **Perché no**: le analisi si fanno sulle sessioni registrate, che restano tabelle normali; la scheda si legge e scrive sempre intera.

### Logica delle prescrizioni anche in Kotlin
- **Pro**: l'app calcola i target da sola, anche offline.
- **Contro**: due implementazioni da tenere allineate.
- **Perché no**: il server invia le settimane già risolte, e l'app le conserva in cache per l'uso offline.

## Conseguenze

### Positive
- Versionare significa solo copiare un documento.
- Il confronto "previsto vs fatto" è esatto anche dopo modifiche alla scheda.

### Negative
- Cercare "tutti i clienti con lo squat in scheda" richiede query su `jsonb`, cioè con operatori dedicati invece che su colonne normali.

### Rischi
- Il formato del documento cambierà nel tempo. Mitigazione: un campo `schemaVersion` nel documento e migrazioni del contenuto testate.
