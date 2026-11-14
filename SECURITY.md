<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
# Sicurezza

## Versioni supportate

Si correggono i problemi di sicurezza solo nell'ultima versione pubblicata (oggi la **0.5.x**). Gli aggiornamenti
arrivano con Sparkle (firmati EdDSA) o dalla [pagina delle release](https://github.com/Akiakizero/OpenTunes/releases).

## Segnalare una vulnerabilità

**Non aprire una issue pubblica.** Usa la segnalazione privata di GitHub:
[Security › Report a vulnerability](https://github.com/Akiakizero/OpenTunes/security/advisories/new).

Indica la versione di OpenTunes e di macOS, i passi per riprodurre il problema e cosa può ottenere chi lo sfrutta.
Rispondo di solito entro 7 giorni; una correzione per i problemi confermati esce entro 30 giorni quando possibile, e
chi segnala viene citato nell'avviso (se lo desidera). Si possono scrivere in italiano o in inglese.

## Cosa conta

- Esecuzione di codice o comandi tramite l'adapter MediaRemote (`/usr/bin/perl`), gli AppleScript, lo schema URL
  `opentunes://`, la riga di comando `opentunes` o il socket di Discord.
- Fuga di segreti: session key di Last.fm, token di ListenBrainz, secret personale (sono nel Portachiavi) o dati
  del brano inviati a servizi non dichiarati.
- Il widget di macOS che legge oltre la cartella condivisa, aggiornamenti Sparkle accettati senza firma valida.
- Problemi nei workflow di GitHub Actions (segreti esposti alle PR, permessi eccessivi).

## Cosa non conta

- La API key e la *shared secret* di Last.fm del progetto incluse nell'app: in un'app open source non possono restare
  segrete (vedi il README). Danno accesso solo alle API pubbliche di Last.fm, non agli account.
- L'app non è notarizzata e la firma è ad-hoc: è una scelta nota (vedi «Installazione» nel README). Verifica il file
  scaricato con il `.sha256` della release.
- I comandi `opentunes://` cambiano solo la riproduzione (play, salto, volume…): un sito può proporli con un link, ma
  macOS chiede conferma prima di aprire l'app. Si possono spegnere in Impostazioni › Funzioni.

## Come è protetto il progetto

- Niente segreti nel codice: Last.fm, Sparkle e Discord arrivano dalle variabili della CI solo nel workflow di release,
  che parte dai tag; le PR (anche da fork) non vedono segreti.
- Workflow con permessi minimi, azioni fissate per SHA e aggiornate da Dependabot; CodeQL su Swift e sui workflow;
  secret scanning e push protection attivi sul repository; `main` protetto (niente force push, CI obbligatoria).
- L'app usa l'Hardened Runtime; il widget è in sandbox e può leggere solo la propria cartella condivisa.
- Dipendenze (Sparkle, KeyboardShortcuts, mediaremote-adapter in `Vendor/`) riviste a ogni release.
