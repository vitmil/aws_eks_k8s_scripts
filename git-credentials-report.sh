#!/bin/bash

# ==============================================
# GIT CREDENTIALS & CONFIGURATION REPORT SCRIPT (v2)
# ==============================================

REPORT_FILE="git-credentials-report.txt"
echo "Generazione report in corso... Salvataggio in: $REPORT_FILE"
> "$REPORT_FILE"

log() {
    echo -e "$1" | tee -a "$REPORT_FILE"
}

log "=========================================="
log "     REPORT CONFIGURAZIONI GIT & CREDENZIALI (v2)"
log "     Data: $(date)"
log "     Utente: $(whoami)"
log "     Host: $(hostname)"
log "==========================================\n"

# --- 1. Configurazione globale Git ---
log "1. CONFIGURAZIONE GIT GLOBALE (~/.gitconfig)"
log "------------------------------------------------"

if [ -f "$HOME/.gitconfig" ]; then
    log "File ~/.gitconfig trovato.\n"
    git config --global --list 2>/dev/null | sed 's/^/    /' >> "$REPORT_FILE"
else
    log "Nessun file ~/.gitconfig trovato."
fi
log ""

# --- 2. Metodo di storage delle credenziali ---
log "2. METODO DI STORAGE DELLE CREDZIALI"
log "------------------------------------------------"

CREDENTIAL_HELPER=$(git config --global credential.helper)

case "$CREDENTIAL_HELPER" in
    "" | "!"*)
        log "Nessun credential helper configurato globalmente."
        log "   Le credenziali vengono inserite manualmente ogni volta."
        ;;
    "cache"*)
        TIMEOUT=$(git config --global credential.cache.timeout 2>/dev/null || echo "900 (default)")
        log "Metodo: cache (in memoria)"
        log "   Timeout: $TIMEOUT secondi"
        ;;
    "store"*)
        log "Metodo: store (file plaintext)"
        log "   Credenziali salvate in: $HOME/.git-credentials"
        ;;
    "osxkeychain"*)   log "Metodo: osxkeychain (macOS Keychain)" ;;
    "wincred"*)       log "Metodo: wincred (Windows Credential Manager)" ;;
    "libsecret"*)     log "Metodo: libsecret (GNOME Keyring)" ;;
    "secretservice"*) log "Metodo: secretservice (freedesktop Secret Service)" ;;
    *)                log "Metodo personalizzato: $CREDENTIAL_HELPER" ;;
esac
log ""

# --- 3. Analisi dettagliata di .git-credentials (solo se esiste o se è 'store') ---
CRED_FILE="$HOME/.git-credentials"

if [[ "$CREDENTIAL_HELPER" == "store"* ]] || [ -f "$CRED_FILE" ]; then
    log "3. ANALISI FILE $CRED_FILE"
    log "------------------------------------------------"

    if [ ! -f "$CRED_FILE" ]; then
        log "File NON trovato (anche se 'store' è attivo, non è stato ancora creato)."
        log ""
        log "4. METODI DISPONIBILI..." # salta al prossimo
    else
        log "File trovato: $CRED_FILE"
        log "Permessi: $(ls -l "$CRED_FILE" | awk '{print $1, $3":"$4}')"
        log "Dimensione: $(du -h "$CRED_FILE" | cut -f1)"
        log ""

        # --- Conta righe totali, vuote, commenti, valide ---
        TOTAL_LINES=$(wc -l < "$CRED_FILE")
        EMPTY_LINES=$(grep -c '^$' "$CRED_FILE")
        COMMENT_LINES=$(grep -c '^\s*#' "$CRED_FILE")
        VALID_LINES=$(grep -c '^[a-zA-Z]*://' "$CRED_FILE")  # inizia con protocollo://

        log "Statistiche file:"
        log "   • Righe totali: $TOTAL_LINES"
        log "   • Righe vuote: $EMPTY_LINES"
        log "   • Commenti (#): $COMMENT_LINES"
        log "   • Righe credenziali valide: $VALID_LINES"
        log ""

        if [ "$VALID_LINES" -eq 0 ]; then
            log "Nessun account valido trovato (solo commenti o righe vuote)."
        else
            log "Account trovati ($VALID_LINES):"
            log ""

            # Estrai host e utente (senza password)
            while IFS= read -r line; do
                # Salta commenti e righe vuote
                [[ "$line" =~ ^\s*$ ]] || [[ "$line" =~ ^\s*# ]] && continue

                if [[ "$line" =~ ^([a-zA-Z]+://)([^:]+):[^@]*@(.+)$ ]]; then
                    PROTOCOL="${BASH_REMATCH[1]}"
                    USER="${BASH_REMATCH[2]}"
                    HOST="${BASH_REMATCH[3]}"
                    echo "    • $HOST (utente: $USER, protocollo: ${PROTOCOL%://})" >> "$REPORT_FILE"
                else
                    echo "    • $line (formato non valido)" >> "$REPORT_FILE"
                fi
            done < "$CRED_FILE"

            # --- Account più usato (default) ---
            MOST_USED_HOST=$(grep -oP '(?<=@)[^/]+' "$CRED_FILE" 2>/dev/null | grep -v '^$' | sort | uniq -c | sort -nr | head -n1 | awk '{print $2}')
            if [ -n "$MOST_USED_HOST" ]; then
                log "\nHost più frequente (possibile default): $MOST_USED_HOST"
            fi

            # --- Contenuto oscurato ---
            log "\nContenuto (password oscurate):"
            grep '^[a-zA-Z]*://' "$CRED_FILE" | sed -E 's/:[^@]+@/:***@/' | sed 's/^/    /' >> "$REPORT_FILE"
            log ""
        fi

        # --- Mostra commenti (opzionale) ---
        if [ "$COMMENT_LINES" -gt 0 ]; then
            log "Commenti presenti nel file:"
            grep '^\s*#' "$CRED_FILE" | sed 's/^/    # /' >> "$REPORT_FILE"
            log ""
        fi
    fi
else
    log "3. File .git-credentials NON utilizzato."
    log "   Il metodo non è 'store' o il file non esiste."
fi
log ""

# --- 4. Metodi disponibili ---
log "4. METODI DI STORAGE CREDENZIALI DISPONIBILI"
log "------------------------------------------------"
log "Configura con: git config --global credential.helper <metodo>\n"
log "• store          → ~/.git-credentials (plaintext)"
log "• cache          → RAM temporanea"
log "• osxkeychain    → macOS Keychain"
log "• wincred        → Windows Credential Manager"
log "• manager        → Git Credential Manager (GCM)"
log "• libsecret      → GNOME Keyring"
log ""

log "Esempi:"
log "   git config --global credential.helper store"
log "   git config --global credential.helper 'cache --timeout=3600'"
log ""

log "=========================================="
log "           FINE REPORT"
log "=========================================="

echo
echo "Report completato! Salvato in: $REPORT_FILE"
echo "Apri con: cat $REPORT_FILE"