#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSHRC="${HOME}/.zshrc"
MARKER="# mdm-bypass (github.com/hitmain13/mdm-bypass)"

chmod +x "${REPO_ROOT}/bin/bypass-mdm" \
  "${REPO_ROOT}/scripts/clear-dep-nag.sh" \
  "${REPO_ROOT}/scripts/clear-dep-nag-recovery.sh" \
  "${REPO_ROOT}/remote-bootstrap.sh" 2>/dev/null || true

mkdir -p "${HOME}/.local/bin"
ln -sf "${REPO_ROOT}/bin/bypass-mdm" "${HOME}/.local/bin/bypass-mdm"
ln -sf "${REPO_ROOT}/scripts/clear-dep-nag.sh" "${HOME}/.local/bin/bypass-mdm-clear-dep-nag.sh"
ln -sf "${REPO_ROOT}/scripts/clear-dep-nag-recovery.sh" "${HOME}/.local/bin/bypass-mdm-clear-dep-nag-recovery.sh"

block="
${MARKER}
export MDM_BYPASS_HOME=\"${REPO_ROOT}\"
export PATH=\"\${MDM_BYPASS_HOME}/bin:\${HOME}/.local/bin:\${PATH}\"
if [[ -f \"\${MDM_BYPASS_HOME}/lib/bypass-mdm.zsh\" ]]; then
  source \"\${MDM_BYPASS_HOME}/lib/bypass-mdm.zsh\"
fi
"

if [[ -f "$ZSHRC" ]] && grep -q "$MARKER" "$ZSHRC" 2>/dev/null; then
  echo "Shell já configurado (${ZSHRC})."
else
  printf '%s\n' "$block" >>"$ZSHRC"
  echo "Atualizado ${ZSHRC}"
fi

echo "OK. Rode: source ${ZSHRC} && bypass-mdm --status"
