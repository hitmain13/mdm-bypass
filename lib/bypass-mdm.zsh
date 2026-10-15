# shellcheck shell=bash
: "${MDM_BYPASS_HOME:=${HOME}/Documents/Projects/mdm-bypass}"

_bypass_mdm_repo_base='https://raw.githubusercontent.com/assafdori/bypass-mdm/main'
_bypass_mdm_script_v2="${_bypass_mdm_repo_base}/bypass-mdm-v2.sh"
_bypass_mdm_script_v1="${_bypass_mdm_repo_base}/bypass-mdm.sh"

_bypass_mdm_log() {
  local level="$1" msg="$2"
  case "$level" in
    info)  printf '\033[1;34mℹ %s\033[0m\n' "$msg" ;;
    ok)    printf '\033[1;32m✓ %s\033[0m\n' "$msg" ;;
    warn)  printf '\033[1;33m⚠ %s\033[0m\n' "$msg" ;;
    err)   printf '\033[1;31m✗ %s\033[0m\n' "$msg" >&2 ;;
  esac
}

_bypass_mdm_run_elevated() {
  local clear_script="$1"
  if [[ "$(id -u)" -eq 0 ]]; then
    "$clear_script"
    return $?
  fi
  if command -v sudo >/dev/null 2>&1; then
    sudo "$clear_script"
    return $?
  fi
  _bypass_mdm_log err "sudo não encontrado. No Recovery use: bash -s -- recovery-clear (via remote-bootstrap)."
  return 127
}

_bypass_mdm_in_recovery() {
  [[ -d "/Volumes" ]] && [[ "$(id -u)" -eq 0 ]] && [[ ! -f /var/db/.AppleSetupDone ]] && return 0
  [[ "$(id -u)" -eq 0 ]] && [[ ! -d "${HOME}/Library/Application Support" ]] && return 0
  return 1
}

_bypass_mdm_preflight() {
  command -v curl >/dev/null 2>&1 || { _bypass_mdm_log err "curl não encontrado."; return 1; }
  curl -fsSL --connect-timeout 15 --max-time 30 -o /dev/null "${_bypass_mdm_repo_base}/README.md" 2>/dev/null \
    || { _bypass_mdm_log err "Sem acesso ao GitHub."; return 1; }
  _bypass_mdm_log ok "Conexão com GitHub OK."
}

bypass-mdm() {
  local use_legacy=0 work_dir script_url script_path
  local clear_script="${MDM_BYPASS_HOME}/scripts/clear-dep-nag.sh"
  local rec_script="${MDM_BYPASS_HOME}/scripts/clear-dep-nag-recovery.sh"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        cat <<EOF
bypass-mdm — MDM/DEP para macOS

  bypass-mdm                      Recovery: assafdori bypass-mdm-v2
  bypass-mdm --legacy             assafdori v1
  bypass-mdm --clear-nag          macOS instalado (requer sudo se disponível)
  bypass-mdm --clear-nag-recovery Modo de Recuperação (root, sem sudo)
  bypass-mdm --status             Diagnóstico local
  bypass-mdm --help

Docs: https://github.com/hitmain13/mdm-bypass
EOF
        return 0
        ;;
      --legacy|-l) use_legacy=1; shift ;;
      --clear-nag|--fix-settings)
        [[ -x "$clear_script" ]] || { _bypass_mdm_log err "Não encontrado: $clear_script"; return 1; }
        _bypass_mdm_run_elevated "$clear_script"
        return $?
        ;;
      --clear-nag-recovery)
        [[ -f "$rec_script" ]] || { _bypass_mdm_log err "Não encontrado: $rec_script"; return 1; }
        if [[ "$(id -u)" -ne 0 ]]; then
          _bypass_mdm_log err "No Recovery o Terminal já é root. Não use sudo."
          return 1
        fi
        bash "$rec_script"
        return $?
        ;;
      --status)
        _bypass_mdm_log info "Estado de inscrição:"
        profiles status -type enrollment 2>&1
        echo ""
        local found="/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound"
        if [[ -f "$found" ]]; then
          _bypass_mdm_log warn "Cloud Config DEP presente (.cloudConfigRecordFound)."
        else
          _bypass_mdm_log ok "Sem .cloudConfigRecordFound."
        fi
        return 0
        ;;
      *) _bypass_mdm_log err "Opção desconhecida: $1"; return 1 ;;
    esac
  done

  script_url="$([[ "$use_legacy" == 1 ]] && echo "$_bypass_mdm_script_v1" || echo "$_bypass_mdm_script_v2")"
  _bypass_mdm_in_recovery || {
    _bypass_mdm_log warn "Fora do Recovery — fluxo pensado para instalação/MDM no Recovery."
    read -r '?Continuar? [s/N] ' confirm
    case "$confirm" in s|S|sim|Sim|SIM) ;; *) return 1 ;; esac
  }
  _bypass_mdm_preflight || return 1
  work_dir="$(mktemp -d "${TMPDIR:-/tmp}/bypass-mdm.XXXXXX")"
  script_path="${work_dir}/bypass-mdm.sh"
  curl -fsSL --retry 3 "$script_url" -o "$script_path"
  chmod +x "$script_path"
  _bypass_mdm_log info "Menu assafdori: opção 1 — Bypass MDM from Recovery"
  (cd "$work_dir" && "$script_path")
}
