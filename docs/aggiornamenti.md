# Aggiornamenti automatici (Sparkle)

OpenTunes usa [Sparkle 2](https://sparkle-project.org) (MIT). L'app legge il feed
`https://github.com/Akiakizero/OpenTunes/releases/latest/download/appcast.xml`, cioè l'`appcast.xml`
allegato all'ultima release di GitHub. Ogni aggiornamento è firmato con una chiave EdDSA.

## Chiavi (una volta sola)

1. Compila una volta il progetto (serve il pacchetto Sparkle risolto), poi genera le chiavi:
   ```sh
   "$(find ~/Library/Developer/Xcode/DerivedData -path '*artifacts/sparkle/Sparkle/bin/generate_keys' | head -1)"
   ```
   La chiave privata finisce nel Portachiavi del Mac; il comando stampa la chiave pubblica.
2. Esporta la privata (`generate_keys -x chiave-privata.txt`), mettila nel secret `SPARKLE_PRIVATE_KEY` del
   repository e **cancella il file**. La privata non va mai committata.
3. Metti la chiave pubblica nella variabile del repository `SPARKLE_PUBLIC_KEY` (Settings › Secrets and variables ›
   Actions › Variables).

## Release

Il workflow `release.yml` passa `SPARKLE_PUBLIC_KEY` alla build (→ `SUPublicEDKey` nell'Info.plist) e, se la
variabile c'è, esegue `scripts/make-appcast.sh <tag>`, che firma il `.dmg` e crea `dist/appcast.xml`; il file viene
allegato alla release insieme al `.dmg`.

Senza chiave pubblica (build locali, fork) l'updater non parte e le impostazioni dicono di aggiornare da GitHub o
con Homebrew. Con la firma ad-hoc Sparkle verifica comunque la firma EdDSA dell'archivio.
