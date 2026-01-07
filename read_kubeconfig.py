#!/usr/bin/env python3
"""
Script per leggere e visualizzare i cluster e i context dal file kubeconfig
"""
import yaml
import os
from pathlib import Path
from collections import defaultdict

def load_kubeconfig(config_path=None):
    """Carica il file kubeconfig"""
    if config_path is None:
        config_path = os.path.expanduser("~/.kube/config")

    with open(config_path, 'r') as f:
        return yaml.safe_load(f)

def format_server_url(url):
    """Formatta l'URL del server per una migliore visualizzazione"""
    return url.replace("https://", "")

def print_separator(char="=", length=80):
    """Stampa una linea separatrice"""
    print(char * length)

def print_cluster_info(config):
    """Stampa informazioni dettagliate su cluster e context"""

    clusters = {c['name']: c['cluster'] for c in config.get('clusters', [])}
    contexts = config.get('contexts', [])
    users = {u['name']: u['user'] for u in config.get('users', [])}
    current_context = config.get('current-context', 'N/A')

    # Raggruppa i context per cluster
    cluster_contexts = defaultdict(list)
    for ctx in contexts:
        cluster_name = ctx['context'].get('cluster')
        cluster_contexts[cluster_name].append(ctx)

    print_separator("=")
    print(f"KUBECONFIG SUMMARY")
    print_separator("=")
    print(f"Total Clusters: {len(clusters)}")
    print(f"Total Contexts: {len(contexts)}")
    print(f"Current Context: {current_context}")
    print_separator("=")
    print()

    # Stampa ogni cluster con i suoi context
    for idx, (cluster_name, cluster_info) in enumerate(clusters.items(), 1):
        print_separator("-")
        print(f"CLUSTER #{idx}: {cluster_name}")
        print_separator("-")

        # Informazioni del cluster
        print(f"\n  Server: {cluster_info.get('server', 'N/A')}")

        if 'certificate-authority' in cluster_info:
            print(f"  Certificate Authority: {cluster_info['certificate-authority']}")
        elif 'certificate-authority-data' in cluster_info:
            print(f"  Certificate Authority: <embedded data>")

        if 'extensions' in cluster_info:
            print(f"  Extensions:")
            for ext in cluster_info['extensions']:
                ext_data = ext.get('extension', {})
                print(f"    - Name: {ext.get('name')}")
                for key, value in ext_data.items():
                    print(f"      {key}: {value}")

        # Context associati a questo cluster
        related_contexts = cluster_contexts.get(cluster_name, [])
        print(f"\n  Associated Contexts ({len(related_contexts)}):")

        if not related_contexts:
            print(f"    (No contexts found for this cluster)")
        else:
            for ctx in related_contexts:
                ctx_name = ctx['name']
                ctx_info = ctx['context']
                is_current = " [CURRENT]" if ctx_name == current_context else ""

                print(f"\n    Context: {ctx_name}{is_current}")
                print(f"      User: {ctx_info.get('user', 'N/A')}")

                if 'namespace' in ctx_info:
                    print(f"      Namespace: {ctx_info['namespace']}")

                # Informazioni aggiuntive sull'utente
                user_name = ctx_info.get('user')
                if user_name and user_name in users:
                    user_info = users[user_name]
                    print(f"      User Auth Method:", end="")

                    auth_methods = []
                    if 'client-certificate' in user_info or 'client-certificate-data' in user_info:
                        auth_methods.append("client-cert")
                    if 'token' in user_info:
                        auth_methods.append("token")
                    if 'exec' in user_info:
                        auth_methods.append(f"exec ({user_info['exec'].get('command', 'N/A')})")

                    if auth_methods:
                        print(f" {', '.join(auth_methods)}")
                    else:
                        print(" N/A")

        print()

    print_separator("=")
    print(f"END OF KUBECONFIG SUMMARY")
    print_separator("=")

def main():
    """Funzione principale"""
    try:
        config_path = os.path.expanduser("~/.kube/config")

        if not os.path.exists(config_path):
            print(f"Errore: File kubeconfig non trovato in {config_path}")
            return 1

        print(f"Lettura kubeconfig da: {config_path}\n")
        config = load_kubeconfig(config_path)
        print_cluster_info(config)

        return 0

    except Exception as e:
        print(f"Errore durante la lettura del kubeconfig: {e}")
        import traceback
        traceback.print_exc()
        return 1

if __name__ == "__main__":
    exit(main())
