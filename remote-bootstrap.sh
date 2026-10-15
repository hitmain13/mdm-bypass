#!/usr/bin/env bash
# Execução remota (curl | bash). Recovery: não usa sudo.

set -euo pipefail

REPO_SLUG="${MDM_BYPASS_REPO:-hitmain13/mdm-bypass}"
BRANCH="${MDM_BYPASS_BRANCH:-main}"
RAW="https://raw.githubusercontent.com/${REPO_SLUG}/${BRANCH}"

ACTION="${1:-}"
if [[ -z "$ACTION" ]]; then
  echo "Uso: curl -fsSL .../remote-bootstrap.sh | bash -s -- <install|status|clear-nag|recovery-clear|recovery-assafdori>" >&2
  echo "No Recovery use: bash -s -- recovery-clear  (sem sudo)" >&2
  exit 1
fi

fetch() {
  curl -fsSL "${RAW}/$1" -o "$2"
}

run_clear_nag() {
  local work
  work="$(mktemp -d)"
  mkdir -p "${work}/scripts/lib"
  fetch scripts/clear-dep-nag.sh "${work}/scripts/clear-dep-nag.sh"
  fetch scripts/lib/common.sh "${work}/scripts/lib/common.sh"
  chmod +x "${work}/scripts/clear-dep-nag.sh"
  if [[ "$(id -u)" -eq 0 ]]; then
    bash "${work}/scripts/clear-dep-nag.sh"
  elif command -v sudo >/dev/null 2>&1; then
    sudo bash "${work}/scripts/clear-dep-nag.sh"
  else
    echo "Erro: precisa de root ou sudo (no Recovery use: bash -s -- recovery-clear)" >&2
    rm -rf "$work"
    exit 127
  fi
  rm -rf "$work"
}

case "$ACTION" in
  install)
    INSTALL_DIR="${MDM_BYPASS_INSTALL_DIR:-${HOME}/Documents/Projects/mdm-bypass}"
    mkdir -p "${INSTALL_DIR}/scripts/lib" "${INSTALL_DIR}/lib" "${INSTALL_DIR}/bin" "${INSTALL_DIR}/config"
    fetch scripts/clear-dep-nag.sh "${INSTALL_DIR}/scripts/clear-dep-nag.sh"
    fetch scripts/clear-dep-nag-recovery.sh "${INSTALL_DIR}/scripts/clear-dep-nag-recovery.sh"
    fetch scripts/lib/common.sh "${INSTALL_DIR}/scripts/lib/common.sh"
    fetch lib/bypass-mdm.zsh "${INSTALL_DIR}/lib/bypass-mdm.zsh"
    fetch bin/bypass-mdm "${INSTALL_DIR}/bin/bypass-mdm"
    fetch install.sh "${INSTALL_DIR}/install.sh"
    fetch config/extra-hosts.example "${INSTALL_DIR}/config/extra-hosts.example"
    chmod +x "${INSTALL_DIR}/scripts/"*.sh "${INSTALL_DIR}/scripts/lib/"*.sh "${INSTALL_DIR}/bin/bypass-mdm" "${INSTALL_DIR}/install.sh"
    bash "${INSTALL_DIR}/install.sh"
    ;;
  status)
    echo "=== profiles status -type enrollment ==="
    profiles status -type enrollment 2>&1 || true
    found="/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound"
    if [[ -f "$found" ]]; then
      echo "Cloud Config DEP: presente (.cloudConfigRecordFound)"
    else
      echo "Cloud Config DEP: ausente"
    fi
    ;;
  clear-nag)
    run_clear_nag
    ;;
  recovery-clear)
    tmp="$(mktemp)"
    fetch scripts/clear-dep-nag-recovery.sh "$tmp"
    fetch scripts/lib/common.sh "${tmp}.common"
    # recovery script sources lib relative to scripts/ — patch: run from temp dir layout
    work="$(mktemp -d)"
    mkdir -p "${work}/scripts/lib"
    mv "$tmp" "${work}/scripts/clear-dep-nag-recovery.sh"
    mv "${tmp}.common" "${work}/scripts/lib/common.sh"
    chmod +x "${work}/scripts/clear-dep-nag-recovery.sh"
    if [[ "$(id -u)" -ne 0 ]]; then
      echo "Erro: recovery-clear exige root (Terminal do Recovery). Não use sudo." >&2
      rm -rf "$work"
      exit 1
    fi
    bash "${work}/scripts/clear-dep-nag-recovery.sh"
    rm -rf "$work"
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
