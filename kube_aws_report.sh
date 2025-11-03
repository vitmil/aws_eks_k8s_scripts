#!/bin/bash

KUBE_CONFIG="$HOME/.kube/config"
AWS_CONFIG="$HOME/.aws/config"

echo "=== Analisi Configurazioni Kubernetes & AWS ==="
echo

# Profili AWS
aws_profiles=$(grep -c '^\[.*\]' "$AWS_CONFIG" 2>/dev/null || echo 0)
echo "Profili AWS (in ~/.aws/config): $aws_profiles"

# Cluster totali
total_clusters=$(yq eval '.clusters | length' "$KUBE_CONFIG" 2>/dev/null || echo 0)
echo "Cluster totali (in kubeconfig): $total_clusters"

# Cluster EKS
eks_clusters=$(yq eval '.clusters[].name' "$KUBE_CONFIG" 2>/dev/null | grep -c '^arn:aws:eks:' || echo 0)
echo "  → di cui EKS:                 $eks_clusters"

# Cluster NON EKS
non_eks_clusters=$((total_clusters - eks_clusters))
echo "  → di cui NON EKS:             $non_eks_clusters"

# Context totali
total_contexts=$(yq eval '.contexts | length' "$KUBE_CONFIG" 2>/dev/null || echo 0)
echo "Context totali:                 $total_contexts"

# Context corrente
current_context=$(yq eval '.["current-context"]' "$KUBE_CONFIG" 2>/dev/null || echo "nessuno")
echo "Context corrente:               $current_context"

echo
echo "=== Riepilogo ==="
if (( eks_clusters > 0 )); then
    echo "Hai $eks_clusters cluster EKS → serve almeno 1 profilo AWS con permessi 'eks:DescribeCluster'"
fi
if (( non_eks_clusters > 0 )); then
    echo "Hai $non_eks_clusters cluster non EKS → non richiedono AWS CLI"
fi