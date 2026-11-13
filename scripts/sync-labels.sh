#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Crea o aggiorna le etichette di .github/labels.yml nel repository GitHub corrente (richiede `gh auth login`).
set -euo pipefail
cd "$(dirname "$0")/.."
name="" color="" description=""
flush() {
  [ -n "$name" ] || return 0
  gh label create "$name" --color "$color" --description "$description" --force
  name="" color="" description=""
}
while IFS= read -r line; do
  case "$line" in
    "- name: "*) flush; name="${line#- name: }" ;;
    "  color: "*) color="${line#  color: }"; color="${color//\"/}" ;;
    "  description: "*) description="${line#  description: }" ;;
  esac
done < .github/labels.yml
flush
