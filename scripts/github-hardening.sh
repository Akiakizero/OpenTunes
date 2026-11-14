#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Impostazioni di sicurezza del repository GitHub (idempotente: si può rilanciare quando si vuole).
# Serve `gh` con accesso da amministratore. Alcune protezioni esistono solo sui repository pubblici (piano gratuito):
# rilanciarlo subito dopo aver reso pubblico il repository.
#
#   scripts/github-hardening.sh                 # repository di origin
#   scripts/github-hardening.sh owner/nome

set -u
REPO="${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
ok() { print -P "%F{green}✔%f $1" }
ko() { print -P "%F{yellow}•%f $1 — $2" }
try() {
  local label="$1"; shift
  local out
  if out=$("$@" 2>&1); then ok "$label"; else ko "$label" "${out//$'\n'/ }"; fi
}

echo "Repository: $REPO"

# Informazioni pubbliche.
try "descrizione, sito e funzioni" gh repo edit "$REPO" \
  --description "Il brano in riproduzione ovunque sul tuo Mac: menu bar, notch, finestra flottante e widget. Libero (GPL-3.0), senza account." \
  --homepage "https://akiakizero.github.io/OpenTunes/" \
  --enable-wiki=false --enable-projects=false --delete-branch-on-merge
try "argomenti" gh repo edit "$REPO" \
  --add-topic macos --add-topic swift --add-topic swiftui --add-topic menu-bar --add-topic now-playing \
  --add-topic lastfm --add-topic scrobbler --add-topic listenbrainz --add-topic notch --add-topic widgetkit

# Dipendenze vulnerabili: avvisi e PR automatiche di Dependabot.
try "avvisi Dependabot" gh api -X PUT "repos/$REPO/vulnerability-alerts"
try "correzioni automatiche Dependabot" gh api -X PUT "repos/$REPO/automated-security-fixes"

# GitHub Actions: token in sola lettura di default, nessuna approvazione di PR dai workflow,
# solo azioni di GitHub (i workflow usano solo actions/* e github/*).
try "token dei workflow in sola lettura" gh api -X PUT "repos/$REPO/actions/permissions/workflow" \
  -f default_workflow_permissions=read -F can_approve_pull_request_reviews=false
try "solo azioni di GitHub" gh api -X PUT "repos/$REPO/actions/permissions" -F enabled=true -f allowed_actions=selected
try "elenco delle azioni consentite" gh api -X PUT "repos/$REPO/actions/permissions/selected-actions" \
  -F github_owned_allowed=true -F verified_allowed=false
try "approvazione per i workflow delle PR esterne" gh api -X PUT "repos/$REPO/actions/permissions/fork-pr-contributor-approval" \
  -f approval_policy=all_external_contributors

# Environment «release»: i segreti di release solo dai tag v*.
try "environment release (solo tag v*)" gh api -X PUT "repos/$REPO/environments/release" \
  --input - <<'JSON'
{ "deployment_branch_policy": { "protected_branches": false, "custom_branch_policies": true } }
JSON
try "regola dei tag v* per l'environment release" gh api -X POST "repos/$REPO/environments/release/deployment-branch-policies" \
  -f name='v*' -f type=tag

# Solo sui repository pubblici (o con GitHub Advanced Security).
try "secret scanning e push protection" gh api -X PATCH "repos/$REPO" --input - <<'JSON'
{ "security_and_analysis": {
    "secret_scanning": { "status": "enabled" },
    "secret_scanning_push_protection": { "status": "enabled" },
    "secret_scanning_non_provider_patterns": { "status": "enabled" },
    "secret_scanning_validity_checks": { "status": "enabled" } } }
JSON
try "segnalazione privata delle vulnerabilità" gh api -X PUT "repos/$REPO/private-vulnerability-reporting"

# main: niente force push né cancellazione, PR con CI verde, storia lineare. Il proprietario può forzare in emergenza.
if ! gh api "repos/$REPO/rulesets" --jq '.[].name' 2>/dev/null | grep -qx "Proteggi main"; then
  try "regole su main" gh api -X POST "repos/$REPO/rulesets" --input - <<'JSON'
{
  "name": "Proteggi main",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "bypass_actors": [ { "actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always" } ],
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "required_linear_history" },
    { "type": "pull_request", "parameters": {
        "required_approving_review_count": 0, "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": false, "require_last_push_approval": false,
        "required_review_thread_resolution": true } },
    { "type": "required_status_checks", "parameters": {
        "strict_required_status_checks_policy": false,
        "required_status_checks": [ { "context": "build-and-test" } ] } }
  ]
}
JSON
else
  ok "regole su main (già presenti)"
fi
if ! gh api "repos/$REPO/rulesets" --jq '.[].name' 2>/dev/null | grep -qx "Proteggi i tag di release"; then
  try "regole sui tag v*" gh api -X POST "repos/$REPO/rulesets" --input - <<'JSON'
{
  "name": "Proteggi i tag di release",
  "target": "tag",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["refs/tags/v*"], "exclude": [] } },
  "bypass_actors": [ { "actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always" } ],
  "rules": [ { "type": "deletion" }, { "type": "non_fast_forward" }, { "type": "update" } ]
}
JSON
else
  ok "regole sui tag v* (già presenti)"
fi

# Sito: GitHub Pages pubblicato dal workflow (gratis solo sui repository pubblici).
if gh api "repos/$REPO/pages" >/dev/null 2>&1; then
  try "GitHub Pages dal workflow" gh api -X PUT "repos/$REPO/pages" -f build_type=workflow
else
  try "GitHub Pages dal workflow" gh api -X POST "repos/$REPO/pages" -f build_type=workflow
fi
try "HTTPS obbligatorio sul sito" gh api -X PUT "repos/$REPO/pages" -F https_enforced=true
