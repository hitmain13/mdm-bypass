#!/bin/bash
# Funções compartilhadas (source, não executar diretamente).

mdm_bypass_apple_hosts=(
  deviceenrollment.apple.com
  mdmenrollment.apple.com
  iprofiles.apple.com
)

mdm_bypass_load_block_domains() {
  local repo_root="${1:-}"
  BLOCK_DOMAINS=("${mdm_bypass_apple_hosts[@]}")
  local extra="${repo_root}/config/extra-hosts.txt"
  [[ -n "$repo_root" && -f "$extra" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="$(echo "$line" | xargs 2>/dev/null || true)"
    [[ -n "$line" ]] && BLOCK_DOMAINS+=("$line")
  done <"$extra"
}

# Volume de dados do macOS instalado (não Recovery/Preboot/Update).
mdm_bypass_skip_volume() {
  local base
  base="$(basename "$1")"
  case "$base" in
    *Recovery*|*Preboot*|*Update*|VM|Hardware|xarts|iSCPreboot) return 0 ;;
  esac
  return 1
}

# Settings + hosts do MESMO volume (private/etc/hosts).
mdm_bypass_hosts_for_settings() {
  local settings="$1" vol
  vol="${settings%/var/db/ConfigurationProfiles/Settings}"
  vol="${vol%/private}"
  if [[ -f "${vol}/private/etc/hosts" ]]; then
    echo "${vol}/private/etc/hosts"
  elif [[ -f "${vol}/etc/hosts" ]]; then
    echo "${vol}/etc/hosts"
  fi
}

mdm_bypass_block_domain() {
  local file="$1" domain="$2"
  grep -Fqx "0.0.0.0 ${domain}" "$file" 2>/dev/null && return 0
  echo "0.0.0.0 ${domain}" >>"$file"
}

# Recovery: já é root e não há sudo. macOS normal: sudo se existir.
mdm_bypass_run_elevated() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
    return $?
  fi
  if command -v sudo >/dev/null 2>&1; then
    sudo "$@"
    return $?
  fi
  printf '\033[1;31m✗\033[0m Privilégios de administrador necessários.\n' >&2
  printf 'No Recovery: use apenas recovery-clear (sem sudo).\n' >&2
  printf 'No macOS: instale as ferramentas de linha de comando ou execute como root.\n' >&2
  return 127
}
