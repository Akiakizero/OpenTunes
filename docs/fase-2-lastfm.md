# Fase 2 — Last.fm e ListenBrainz

> **Obiettivo:** scrobbling affidabile da qualsiasi player, profilo Last.fm nell'app e azioni sul brano (love, stelle, aggiungi alla libreria).

## Gate per chiudere la fase

- [ ] Una settimana di ascolto senza scrobble persi o duplicati (confronto con il profilo Last.fm)
- [ ] La coda offline invia correttamente gli scrobble dopo una disconnessione
- [ ] Love su Last.fm e stelle/dislike in Apple Music funzionano dalla menu bar e dalla finestra flottante
- [ ] Release `v0.2`

## 1. Autenticazione

- [ ] Registrare una API key Last.fm per il progetto
- [ ] Flusso di autenticazione desktop di Last.fm (token → approvazione nel browser → session key)
- [ ] Session key salvata nel **Portachiavi** (Keychain), mai in chiaro
- [ ] ListenBrainz: inserimento del token utente nelle impostazioni, salvato nel Portachiavi
- [ ] Possibilità di attivare Last.fm, ListenBrainz o entrambi

> Nota: la API secret di Last.fm in un'app open-source è di fatto pubblica. È una situazione comune a tutti gli scrobbler open-source; documentarla nel README e permettere all'utente di inserire la propria chiave.

## 2. Logica di scrobbling

- [ ] Regole standard Last.fm: il brano dura più di 30 secondi ed è stato ascoltato per metà della durata o per 4 minuti, quello che arriva prima
- [ ] Soglia personalizzabile nelle impostazioni (come NepTunes)
- [ ] La pausa non azzera il conteggio del tempo ascoltato
- [ ] Un brano viene scrobblato una sola volta per sessione di ascolto
- [ ] `updateNowPlaying` inviato a Last.fm all'inizio di ogni brano
- [ ] Filtro per player: scegliere quali app possono fare scrobbling (es. escludere i video di YouTube)

## 3. Coda offline

- [ ] Scrobble salvati in **SwiftData** prima dell'invio
- [ ] Invio a blocchi (Last.fm accetta fino a 50 scrobble per richiesta)
- [ ] Nuovi tentativi con attesa crescente in caso di errore
- [ ] Indicatore nella menu bar quando ci sono scrobble in coda

## 4. Scrobble puliti (funzione Pro di NepTunes)

- [ ] Rimozione di suffissi come "(Remastered 2011)", "- Radio Edit", "[Official Video]", "(feat. …)" opzionale
- [ ] Correzione dell'album artist (compilation, "Various Artists")
- [ ] Regole portate da [web-scrobbler](https://github.com/web-scrobbler/web-scrobbler) (verificare la licenza prima di copiare)
- [ ] Anteprima nell'app: titolo originale → titolo inviato
- [ ] Test con una lista di titoli reali e risultato atteso

## 5. Profilo Last.fm

- [ ] Sezione nel popover o nella finestra: scrobble recenti, brani amati, top artisti
- [ ] Cache locale per non chiamare l'API a ogni apertura

## 6. Azioni sul brano

- [ ] **Love / unlove** su Last.fm (`track.love`, `track.unlove`)
- [ ] **Stelle e dislike in Apple Music** tramite AppleScript
- [ ] **Aggiungi alla libreria** (Apple Music via AppleScript)
- [ ] Pulsante love nella menu bar e nel popover
- [ ] Hotkey: love, aggiungi alla libreria, **cambia player attivo**

## 7. Persistenza dei brani recenti

- [ ] La lista "brani recenti" della fase 1 passa su SwiftData

## Riferimenti open-source

| Progetto | Cosa guardare |
| --- | --- |
| [osx-scrobbler](https://github.com/theli-ua/osx-scrobbler) | Regole di scrobbling, gestione di Last.fm + ListenBrainz da MediaRemote |
| [Audioscrobbler (heyvito)](https://github.com/heyvito/audioscrobbler) | Client Last.fm nativo per Apple Music (MIT) |
| [goscrobble](https://github.com/p-mng/goscrobble) | Logica del demone di scrobbling (MIT) |
| [web-scrobbler](https://github.com/web-scrobbler/web-scrobbler) | Regole di pulizia di titoli e artisti |
| [foo_scrobbler_mac](https://github.com/zfoxer/foo_scrobbler_mac) | Gestione della cache offline e dei duplicati |
| [Sidra](https://github.com/wimpysworld/sidra) | Flusso di connessione a Last.fm dal menu |

## Prompt suggeriti per Claude Code

1. *"Implementa il client Last.fm (auth desktop, session key nel Keychain, updateNowPlaying, scrobble, love/unlove) in MediaCore/Scrobbling con test su risposte di esempio."*
2. *"Implementa ScrobbleEngine con le regole di soglia, la pausa che non azzera il tempo e uno scrobble per sessione. Test con sequenze di eventi simulate."*
3. *"Aggiungi la coda offline in SwiftData con invio a blocchi e retry."*
4. *"Implementa TitleCleaner con regole di pulizia e una suite di test su titoli reali."*

## Rischi di questa fase

- **Scrobble doppi** quando due sorgenti vedono lo stesso brano → deduplicazione per player + titolo + timestamp di inizio.
- **Rate limit di Last.fm** → invio a blocchi e cache del profilo.
- **API key esposta** → documentata, con opzione per la chiave personale.

## Aggiornamenti dall'analisi dei progetti di riferimento (2026-11-12)

- Firma e chiamate Last.fm: `WebService.swift` di Audioscrobbler (MIT) come riferimento.
- Regole: scrobble a 50% o 240 s, brani ≥ 30 s (web-scrobbler, `src/util/util.ts`).
- Coda offline persistente (foo_scrobbler_mac, MIT — non GPL come indicato prima).
- Browser esclusi per default; filtro allow/ignore con prompt per app nuove (osx-scrobbler).
- Gestione dei `ignoredMessage` di `track.scrobble`: Sidra (Blue Oak, solo studio).
