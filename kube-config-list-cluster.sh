#!/bin/bash

# Script per elencare cluster, context e utente dal file ~/.kube/config

CONFIG_FILE="$HOME/.kube/config"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Errore: File di configurazione non trovato: $CONFIG_FILE"
    exit 1
fi

echo "Cluster configurati in $CONFIG_FILE"
echo "===================================="
printf "%-30s %-30s %-25s\n" "CLUSTER" "CONTEXT" "UTENTE"
echo "--------------------------------------------------------------------------------"

# Usa yq (versione 4+) per parsare il YAML in modo strutturato
if ! command -v yq &> /dev/null; then
    echo "Errore: 'yq' non è installato. Installalo con: brew install yq (macOS) o scaricalo da https://github.com/mikefarah/yq"
    exit 1
fi

# Estrai tutti i context
yq eval '.contexts[] | [.name, .context.cluster, .context.user] | join("|||")' "$CONFIG_FILE" | \
while IFS="|||" read -r context_name cluster_name user_name; do
    # Risolve i nomi effettivi se sono riferimenti
    cluster_ref=$(yq eval ".contexts[] | select(.name == \"$context_name\") | .context.cluster" "$CONFIG_FILE")
    user_ref=$(yq eval ".contexts[] | select(.name == \"$context_name\") | .context.user" "$CONFIG_FILE")

    # Risolvi il nome reale del cluster
    real_cluster=$(yq eval ".clusters[] | select(.name == \"$cluster_ref\") | .name" "$CONFIG_FILE")

    # Risolvi il nome reale dell'utente
    real_user=$(yq eval ".users[] | select(.name == \"$user_ref\") | .name" "$CONFIG_FILE")

    printf "%-30s %-30s %-25s\n" "$real_cluster" "$context_name" "$real_user"
done

echo "--------------------------------------------------------------------------------"
echo "Totale context: $(yq eval '.contexts | length' "$CONFIG_FILE")"