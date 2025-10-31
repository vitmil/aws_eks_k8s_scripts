#!/bin/bash
# File: ~/list-eks-clusters-per-profile.sh
# Descrizione: Elenca i cluster EKS per ogni profilo AWS in ~/.aws/config
# Requisiti: aws cli v2, jq (opzionale per output JSON pulito)

set -euo pipefail

# === CHECK: jq installato? ===
if ! command -v jq >/dev/null 2>&1; then
    echo -e "\033[0;31mERRORE: 'jq' non è installato.\033[0m"
    echo
    echo "Installalo con uno dei seguenti comandi:"
    echo
    echo "   # Ubuntu/Debian"
    echo "   sudo apt update && sudo apt install -y jq"
    echo
    echo "   # Amazon Linux / CentOS / RHEL"
    echo "   sudo yum install -y jq  # oppure: dnf install -y jq"
    echo
    echo "   # macOS (Homebrew)"
    echo "   brew install jq"
    echo
    echo "   # Alpine"
    echo "   apk add jq"
    echo
    exit 1
fi
echo -e "\033[0;32mjq è installato. Proseguo...\033[0m"
echo


# File di configurazione AWS
CONFIG_FILE="$HOME/.aws/config"

# Colori per output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Ricerca profili AWS in $CONFIG_FILE...${NC}"
echo

# Estrae tutti i profili (anche [default] se presente)
PROFILES=$(grep -E '^\[profile ' "$CONFIG_FILE" | sed 's/\[profile //g' | sed 's/\]//g' || true)
if [ -z "$PROFILES" ]; then
    PROFILES=$(grep -E '^\[default\]' "$CONFIG_FILE" | sed 's/\[//g' | sed 's/\]//g' || true)
fi

if [ -z "$PROFILES" ]; then
    echo -e "${RED}Nessun profilo trovato in $CONFIG_FILE${NC}"
    exit 1
fi

TOTAL=$(echo "$PROFILES" | wc -w)
COUNT=0

for PROFILE in $PROFILES; do
    COUNT=$((COUNT + 1))
    echo -e "${YELLOW}[$COUNT/$TOTAL] Profilo: $PROFILE${NC}"

    # Estrai regione dal profilo
    REGION=$(grep -A5 "^\[profile $PROFILE\]" "$CONFIG_FILE" | grep '^region' | head -1 | awk -F'= ' '{print $2}' | xargs)
    if [ -z "$REGION" ]; then
        REGION=$(aws configure get region --profile "$PROFILE" 2>/dev/null || echo "unknown")
    fi
    if [ -z "$REGION" ] || [ "$REGION" = "unknown" ]; then
        echo "   Regione: non specificata"
        echo "   Cluster EKS: impossibile determinare"
        echo
        continue
    fi

    echo "   Regione: $REGION"

    # Verifica se il profilo è SSO e se serve login
    if grep -A5 "^\[profile $PROFILE\]" "$CONFIG_FILE" | grep -q "sso_session"; then
        # Controlla se le credenziali SSO sono valide
        if ! aws sts get-caller-identity --profile "$PROFILE" >/dev/null 2>&1; then
            echo -e "   ${RED}SSO non autenticato. Eseguo login...${NC}"
            if ! aws sso login --profile "$PROFILE"; then
                echo -e "   ${RED}Login fallito per $PROFILE. Salto.${NC}"
                echo
                continue
            fi
        fi
    fi

    # Elenca i cluster EKS
    echo "   Cluster EKS:"
    CLUSTERS=$(aws eks list-clusters --region "$REGION" --profile "$PROFILE" --output json 2>/dev/null | jq -r '.clusters[]?' 2>/dev/null || echo "")

    if [ -z "$CLUSTERS" ] || [ "$CLUSTERS" = "null" ]; then
        echo "      (nessun cluster trovato in questa regione o accesso negato)"
    else
        while IFS= read -r cluster; do
            if [ -n "$cluster" ]; then
                echo "      - $cluster"
            fi
        done <<< "$CLUSTERS"
    fi
    echo
done

echo -e "${GREEN}Completato! Elencati cluster per $TOTAL profili.${NC}"