# Fixture dell'adapter

Righe JSON nel formato di `mediaremote-adapter.pl … stream --micros`, come documentato nel README
dell'adapter (commit `14eed93`). Scritte a mano a partire dal formato documentato: **non** sono
registrazioni reali. `artworkData` è un PNG 1×1 in base64.

- `stream-music-session.jsonl` — Musica: payload completo, diff di posizione, diff con chiave a `null`
  (album sparito), pausa, nuovo brano (payload completo), niente in riproduzione (payload vuoto).
- `stream-browser-youtube.jsonl` — YouTube in Safari: `bundleIdentifier` del processo WebKit e
  `parentApplicationBundleIdentifier` del browser.
- `get-null.json` — output di `get` quando non suona nulla.
