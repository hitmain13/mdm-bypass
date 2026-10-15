# Revisão técnica — mdm-bypass

**Revisor:** Grok 4.7 (revisão estática; scripts não executados nesta sessão).

## Resumo

- `recovery-clear` **não usa `sudo`** — adequado ao Terminal do Recovery (root, sem binário `sudo`).
- O bootstrap monta `scripts/lib/common.sh` no layout esperado pelos scripts.
- Pendências: `hosts` no volume errado no Recovery, sucesso sem pós-condição (parcialmente corrigido no repo), `curl | bash` sem pin de commit, `clear-nag`/`status` no Recovery leem o sistema de Recovery e não o volume instalado.

## P0 (prioridade alta)

1. No Recovery, `clear-nag` e `status` usam `/var/db/...` e `/etc/hosts` do **ambiente de Recovery**, não do macOS instalado. Use apenas **`recovery-clear`**.
2. `find_hosts_file` pode gravar em volume inadequado; validar com `ls /Volumes` e preferir `private/etc/hosts` do **mesmo** volume onde `Settings` foi limpo.
3. Recovery deve falhar se `.cloudConfigRecordFound` permanecer (verificação adicionada em `clear-dep-nag-recovery.sh`).
4. `curl | bash` como root: sem checksum/commit pinado; exigir subcomando explícito (`bash -s -- recovery-clear`).
5. `rm` com `set -e` no macOS instalado: tratar falha e orientar `recovery-clear` (ajustado em `clear-dep-nag.sh`).

## P1

- `read -p` no zsh → usar `read '?prompt' ` (ajustado).
- `recovery-assafdori` usa `sh` e script de terceiros (pode chamar `sudo`).
- `extra-hosts.txt` não vai no fluxo remoto (só local).
- Backup no Recovery ainda ausente; múltiplos volumes podem ser processados.

## Recovery — checklist

- [ ] `id -u` = 0, comando **sem** `sudo` na frente
- [ ] `curl ... | bash -s -- recovery-clear`
- [ ] `ls /Volumes` antes de confiar em caminhos locais
- [ ] Reiniciar e `bypass-mdm --status` no macOS instalado

## macOS instalado — checklist

- [ ] `bypass-mdm --clear-nag` (com `sudo` se existir)
- [ ] Se `restricted` ou falha no `rm` → Recovery + `recovery-clear`

## Segurança

Prefira baixar scripts, revisar e executar com commit fixo. Evite `curl | bash` sem subcomando. Não use `install` no Recovery.

---

Relatório completo da sessão de revisão Grok 4.7: ver histórico do agente ou solicitar nova revisão após mudanças.
