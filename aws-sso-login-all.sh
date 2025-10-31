#!/bin/bash
# File: ~/aws-sso-login-all.sh
# Descrizione: Esegue aws sso login per tutti i profili SSO nel file ~/.aws/config

set -euo pipefail

CONFIG_FILE="$HOME/.aws/config"
CACHE_DIR="$HOME/.aws/sso/cache"

echo "Ricerca profili SSO in $CONFIG_FILE..."

# Estrae i nomi dei profili che usano sso_session
PROFILES=$(grep -E '^\[profile ' "$CONFIG_FILE" | cut -d' ' -f2 | tr -d ']')
SSO_PROFILES=()

for PROFILE in $PROFILES; do
    if grep -A5 "^\[profile $PROFILE\]" "$CONFIG_FILE" | grep -q "sso_session"; then
        SSO_PROFILES+=("$PROFILE")
    fi
done

if [ ${#SSO_PROFILES[@]} -eq 0 ]; then
    echo "Nessun profilo SSO trovato."
    exit 0
fi

echo "Trovati ${#SSO_PROFILES[@]} profili SSO:"
printf ' - %s\n' "${SSO_PROFILES[@]}"
echo

# Esegui login per ogni sessione SSO (una sola volta per sso_session)
declare -A LOGGED_SESSIONS

for PROFILE in "${SSO_PROFILES[@]}"; do
    SSO_SESSION=$(grep -A3 "^\[profile $PROFILE\]" "$CONFIG_FILE" | grep "sso_session" | awk -F'= ' '{print $2}' | xargs)

    if [[ -z "$SSO_SESSION" ]]; then
        echo "Errore: sso_session non trovato per $PROFILE"
        continue
    fi

    if [[ -n "${LOGGED_SESSIONS[$SSO_SESSION]:-}" ]]; then
        echo "Sessione SSO '$SSO_SESSION' già autenticata (riutilizzata per $PROFILE)"
        continue
    fi

    echo "Autenticazione SSO per sessione: $SSO_SESSION (profilo: $PROFILE)"
    if aws sso login --profile "$PROFILE"; then
        LOGGED_SESSIONS["$SSO_SESSION"]=1
        echo "Login completato per $SSO_SESSION"
    else
        echo "Fallito login per $PROFILE (sessione $SSO_SESSION)"
    fi
    echo
done

echo "Tutti i login SSO completati."
echo "Credenziali salvate in: $CACHE_DIR"
