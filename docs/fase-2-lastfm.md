# Fase 2 — Last.fm e ListenBrainz

> **Obiettivo:** scrobbling affidabile da qualsiasi player, profilo Last.fm nell'app e azioni sul brano (love, stelle, aggiungi alla libreria).

## Gate per chiudere la fase

- [ ] Una settimana di ascolto senza scrobble persi o duplicati (confronto con il profilo Last.fm)
- [ ] La coda offline invia correttamente gli scrobble dopo una disconnessione (coperto dai test `ScrobblerTests`; manca la prova sul campo)
- [ ] Love su Last.fm e stelle/dislike in Apple Music funzionano dalla menu bar e dalla finestra flottante
- [ ] Release `v0.2`

## 1. Autenticazione

- [ ] Registrare una API key Last.fm per il progetto — da fare a mano: poi segreti `LASTFM_API_KEY` e `LASTFM_API_SECRET` nel repository (li usa il workflow di release). Senza, l'utente inserisce la propria chiave
- [x] Flusso di autenticazione desktop di Last.fm (token → approvazione nel browser → session key)
- [x] Session key salvata nel **Portachiavi** (Keychain), mai in chiaro
- [x] ListenBrainz: inserimento del token utente nelle impostazioni, salvato nel Portachiavi
- [x] Possibilità di attivare Last.fm, ListenBrainz o entrambi

> Nota: la API secret di Last.fm in un'app open-source è di fatto pubblica. È una situazione comune a tutti gli scrobbler open-source; documentarla nel README e permettere all'utente di inserire la propria chiave.

## 2. Logica di scrobbling

- [x] Regole standard Last.fm: il brano dura più di 30 secondi ed è stato ascoltato per metà della durata o per 4 minuti, quello che arriva prima
- [x] Soglia personalizzabile nelle impostazioni (come NepTunes)
- [x] La pausa non azzera il conteggio del tempo ascoltato
- [x] Un brano viene scrobblato una sola volta per sessione di ascolto
- [x] `updateNowPlaying` inviato a Last.fm all'inizio di ogni brano
- [x] Filtro per player: scegliere quali app possono fare scrobbling (es. escludere i video di YouTube)

## 3. Coda offline

- [x] Scrobble salvati in **SwiftData** prima dell'invio
- [x] Invio a blocchi (Last.fm accetta fino a 50 scrobble per richiesta)
- [x] Nuovi tentativi con attesa crescente in caso di errore
- [x] Indicatore nella menu bar quando ci sono scrobble in coda

## 4. Scrobble puliti (funzione Pro di NepTunes)

- [x] Rimozione di suffissi come "(Remastered 2011)", "- Radio Edit", "[Official Video]", "(feat. …)" opzionale
- [x] Correzione dell'album artist (compilation, "Various Artists")
- [x] Regole scritte da zero ispirate a [web-scrobbler](https://github.com/web-scrobbler/web-scrobbler) (MIT; nessun codice copiato)
- [x] Anteprima nell'app: titolo originale → titolo inviato
- [x] Test con una lista di titoli reali e risultato atteso

## 5. Profilo Last.fm

- [x] Sezione nel popover o nella finestra: scrobble recenti, brani amati, top artisti
- [x] Cache locale per non chiamare l'API a ogni apertura

## 6. Azioni sul brano

- [x] **Love / unlove** su Last.fm (`track.love`, `track.unlove`)
- [x] **Stelle e dislike in Apple Music** tramite AppleScript
- [x] **Aggiungi alla libreria** (Apple Music via AppleScript)
- [x] Pulsante love nella menu bar e nel popover
- [x] Hotkey: love, aggiungi alla libreria, **cambia player attivo**

## 7. Persistenza dei brani recenti

- [x] La lista "brani recenti" della fase 1 passa su SwiftData

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

## Stato dell'implementazione (2026-11-12)

- `Sources/MediaCore/Scrobbling/`: `ScrobbleRules`, `ScrobbleEngine` (macchina a stati pura), `TitleCleaner`,
  `LastFMClient`, `ListenBrainzClient`, `KeychainStore`, `Scrobbler` (coordinatore osservabile).
- `Sources/MediaCore/Storage/`: database SwiftData (`~/Library/Application Support/OpenTunes/OpenTunes.store`)
  con `ScrobbleQueue` (coda offline, blocchi da 50, attesa 30 s → 1 h, deduplicazione ±30 s) e `TrackHistory`.
- Love: su Last.fm e, se attivo, anche come preferito in Musica. Stelle, dislike e libreria solo per Musica
  (AppleScript `favorited`/`loved`, `disliked`, `rating`, `duplicate … to source 1`): **da verificare a mano**
  con un brano di Apple Music, in particolare l'aggiunta alla libreria dei brani in streaming.
- «Cambia player attivo»: mette in pausa il player corrente e avvia l'altro tra Musica e Spotify.
- Il profilo Last.fm sta in cache per 10 minuti (`~/Library/Caches/OpenTunes/lastfm-profile.json`).
- Restano i punti del gate che richiedono uso reale (settimana di ascolto, prova offline sul campo) e la release `v0.2`.
