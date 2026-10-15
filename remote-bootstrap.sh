#!/usr/bin/env bash
# Execução remota (sem clone), no estilo assafdori/bypass-mdm.
#
#   curl -fsSL https://raw.githubusercontent.com/hitmain13/mdm-bypass/main/remote-bootstrap.sh | bash
#   curl -fsSL .../remote-bootstrap.sh | bash -s -- status
#   curl -fsSL .../remote-bootstrap.sh | bash -s -- clear-nag
#   curl -fsSL .../remote-bootstrap.sh | bash -s -- recovery-clear

set -euo pipefail

REPO_SLUG="${MDM_BYPASS_REPO:-hitmain13/mdm-bypass}"
BRANCH="${MDM_BYPASS_BRANCH:-main}"
RAW="https://raw.githubusercontent.com/${REPO_SLUG}/${BRANCH}"

ACTION="${1:-install}"

fetch() {
  curl -fsSL "${RAW}/$1" -o "$2"
}

case "$ACTION" in
  install)
    INSTALL_DIR="${MDM_BYPASS_INSTALL_DIR:-${HOME}/Documents/Projects/mdm-bypass}"
    mkdir -p "${INSTALL_DIR}/scripts" "${INSTALL_DIR}/lib" "${INSTALL_DIR}/bin" "${INSTALL_DIR}/config"
    fetch scripts/clear-dep-nag.sh "${INSTALL_DIR}/scripts/clear-dep-nag.sh"
    fetch scripts/clear-dep-nag-recovery.sh "${INSTALL_DIR}/scripts/clear-dep-nag-recovery.sh"
    fetch lib/bypass-mdm.zsh "${INSTALL_DIR}/lib/bypass-mdm.zsh"
    fetch bin/bypass-mdm "${INSTALL_DIR}/bin/bypass-mdm"
    fetch install.sh "${INSTALL_DIR}/install.sh"
    chmod +x "${INSTALL_DIR}/scripts/"*.sh "${INSTALL_DIR}/bin/bypass-mdm" "${INSTALL_DIR}/install.sh"
    bash "${INSTALL_DIR}/install.sh"
    ;;
  status)
    echo "=== profiles status -type enrollment ==="
    profiles status -type enrollment 2>&1 || true
    found="/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound"
    if [[ -f "$found" ]]; then
      echo "Cloud Config DEP: presente"
      plutil -extract CloudConfigProfile.OrganizationName raw "$found" 2>/dev/null && true
    else
      echo "Cloud Config DEP: ausente (.cloudConfigRecordFound)"
    fi
    ;;
  clear-nag)
    tmp="$(mktemp)"
    fetch scripts/clear-dep-nag.sh "$tmp" && chmod +x "$tmp" && sudo "$tmp"
    rm -f "$tmp"
    ;;
  recovery-clear)
    tmp="$(mktemp)"
    fetch scripts/clear-dep-nag-recovery.sh "$tmp" && chmod +x "$tmp" && sh "$tmp"
    rm -f "$tmp"
    ;;
  recovery-assafdori)
    curl -fsSL https://raw.githubusercontent.com/assafdori/bypass-mdm/main/bypass-mdm-v2.sh -o /tmp/bypass-mdm-assaf.sh
    chmod +x /tmp/bypass-mdm-assaf.sh
    sh /tmp/bypass-mdm-assaf.sh
    ;;
  *)
    echo "Uso: install | status | clear-nag | recovery-clear | recovery-assafdori"
    exit 1
    ;;
esac
