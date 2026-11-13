# Fixture dell'adapter

Righe JSON nel formato di `mediaremote-adapter.pl … stream --micros`, come documentato nel README
dell'adapter (commit `14eed93`). Scritte a mano a partire dal formato documentato: **non** sono
registrazioni reali. `artworkData` è un PNG 1×1 in base64.

- `stream-music-session.jsonl` — Musica: payload completo, diff di posizione, diff con chiave a `null`
  (album sparito), pausa, nuovo brano (payload completo), niente in riproduzione (payload vuoto).
- `stream-browser-youtube.jsonl` — YouTube in Safari: `bundleIdentifier` del processo WebKit e
  `parentApplicationBundleIdentifier` del browser.
- `get-null.json` — output di `get` quando non suona nulla.

# Fixture di Last.fm

Risposte JSON di `ws.audioscrobbler.com/2.0/?format=json` scritte a mano dal formato documentato
dell'API (non registrazioni reali): servono a provare le stranezze di Last.fm (oggetto singolo al posto
di un array, numeri come stringhe, `ignoredMessage`).

- `lastfm-scrobble-mixed.json` — `track.scrobble` con un ascolto accettato, uno ignorato (artista, codice 1)
  e uno oltre il limite giornaliero (codice 5).
- `lastfm-scrobble-single.json` — `track.scrobble` con un solo ascolto (oggetto invece di array).
- `lastfm-error-session.json` — errore 9 (sessione non valida).
- `lastfm-user-info.json`, `lastfm-recent-tracks.json` (con un brano in riproduzione), `lastfm-loved-tracks.json`
  (un solo brano), `lastfm-top-artists.json` — dati del profilo.
- `lastfm-top-albums.json` (un album senza copertina), `lastfm-similar-artists.json`, `lastfm-similar-tracks.json`
  (un solo brano: oggetto invece di array) — dati della finestra «Scopri».

# Fixture di LRCLIB, iTunes e Odesli

Scritte a mano dal formato documentato delle API (non registrazioni reali).

- `lrclib-get.json` — `/api/get` con testo sincronizzato: tag di metadati, due marcatori sulla stessa riga, riga vuota.
- `lrclib-search.json` — `/api/search`: una versione live con durata diversa, una solo testo e una sincronizzata.
- `itunes-search-song.json` — iTunes Search API con `trackViewUrl` (parametro `uo` da togliere).
- `odesli-links.json` — `api.song.link/v1-alpha.1/links` con `pageUrl`.
