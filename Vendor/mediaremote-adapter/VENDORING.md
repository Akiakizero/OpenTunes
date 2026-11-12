# mediaremote-adapter — copia vendorizzata

- Upstream: https://github.com/ungive/mediaremote-adapter
- Commit: `14eed9389241d06e29f7326c19e9ebc6ec8a5f36` (2026-11-11)
- Data della copia: 2026-11-12
- Licenza: BSD 3-Clause (vedi `LICENSE`), Copyright (c) 2025 Jonas van den Berg and contributors
- File copiati: `bin/`, `include/`, `src/`, `LICENSE`, `README.md`, `CMakeLists.txt` — **senza modifiche**

Il framework e il test client si compilano con `scripts/build-mediaremote-adapter.sh`
(stessi flag di `CMakeLists.txt`, senza bisogno di CMake). Il risultato va in
`Resources/MediaRemoteAdapter/` (ignorato da git) e viene copiato nel bundle dall'app.
Il framework **non** va linkato: lo carica `/usr/bin/perl`.

Per aggiornare: sostituire le cartelle con quelle del nuovo commit, aggiornare questo file e CREDITS.md.
