# mdm-bypass

Ferramentas para **diagnosticar** e **tratar o nag de inscrição DEP/MDM** no macOS (modal *Registre no Gerenciamento Remoto* nos Ajustes), em conjunto com o fluxo do [assafdori/bypass-mdm](https://github.com/assafdori/bypass-mdm) no **Modo de Recuperação**.

Repositório: https://github.com/hitmain13/mdm-bypass

---

## Por que `sudo: command not found` no Recovery?

No **Modo de Recuperação**, o Terminal costuma rodar como **root** e **não inclui** o comando `sudo`. Qualquer fluxo que chame `sudo` vai falhar.

| Ambiente | Comando correto |
|----------|-----------------|
| **Recovery** | `curl ... \| bash -s -- recovery-clear` (sem sudo) |
| **macOS instalado** | `bypass-mdm --clear-nag` (usa `sudo` **se existir**) |

---

## Sintomas típicos (genérico)

- `profiles status -type enrollment` → **MDM enrollment: No** (ainda sem inscrição completa).
- Arquivos em `/var/db/ConfigurationProfiles/Settings` com flag **`restricted`** (`ls -lO`).
- Com SIP ativo, `rm` nesses arquivos no sistema ligado → **Operation not permitted**.
- Modal nos **Ajustes** pedindo **Gerenciamento remoto**.

**Conclusão usual:** cloud config DEP no disco, sem MDM ativo — no macOS 15+ a remoção dos arquivos `restricted` em geral exige **Recovery**.

---

## Estrutura

```text
mdm-bypass/
├── README.md
├── install.sh
├── remote-bootstrap.sh
├── bin/bypass-mdm
├── lib/bypass-mdm.zsh
├── scripts/
│   ├── clear-dep-nag.sh
│   ├── clear-dep-nag-recovery.sh
│   └── lib/common.sh
└── config/
    └── extra-hosts.example   → copiar para extra-hosts.txt
```

---

## Instalação local

```bash
git clone https://github.com/hitmain13/mdm-bypass.git
cd mdm-bypass
chmod +x install.sh remote-bootstrap.sh bin/bypass-mdm scripts/*.sh scripts/lib/*.sh
./install.sh
source ~/.zshrc
bypass-mdm --status
```

## Instalação remota (macOS normal)

```bash
curl -fsSL https://raw.githubusercontent.com/hitmain13/mdm-bypass/main/remote-bootstrap.sh | bash -s -- install
```

---

## Recovery (recomendado para arquivos `restricted`)

Wi‑Fi → **Utilitários → Terminal** → cole **sem sudo**:

```bash
curl -fsSL https://raw.githubusercontent.com/hitmain13/mdm-bypass/main/remote-bootstrap.sh | bash -s -- recovery-clear
```

Reinicie o Mac e verifique:

```bash
bypass-mdm --status
```

Esperado: **sem** `.cloudConfigRecordFound`.

---

## macOS já instalado

```bash
bypass-mdm --clear-nag
```

Faz backup em `~/Documents/mdm-bypass-backups/`. Se os arquivos forem `restricted`, o script orienta o **recovery-clear**.

---

## Instalação nova / tela MDM (assafdori)

1. [README assafdori](https://github.com/assafdori/bypass-mdm): apagar disco (recomendado), Recovery, Wi‑Fi.
2. No Recovery:

```bash
curl -fsSL https://raw.githubusercontent.com/assafdori/bypass-mdm/main/bypass-mdm-v2.sh -o bypass-mdm.sh && chmod +x bypass-mdm.sh && ./bypass-mdm.sh
```

Opção **1) Bypass MDM from Recovery** · usuário/senha padrão: **Apple** / **1234**.

Ou:

```bash
curl -fsSL https://raw.githubusercontent.com/hitmain13/mdm-bypass/main/remote-bootstrap.sh | bash -s -- recovery-assafdori
```

---

## Domínios bloqueados (padrão)

- `deviceenrollment.apple.com`
- `mdmenrollment.apple.com`
- `iprofiles.apple.com`

Domínios do seu servidor MDM (ex.: `*.jamfcloud.com`): adicione em `config/extra-hosts.txt` (veja `extra-hosts.example`).

---

## CLI

| Comando | Onde |
|---------|------|
| `bypass-mdm` | Recovery → assafdori v2 |
| `bypass-mdm --clear-nag` | macOS instalado (`sudo` se houver) |
| `bypass-mdm --clear-nag-recovery` | Recovery, já como root |
| `bypass-mdm --status` | Diagnóstico |

No Recovery, `bypass-mdm` do shell **não carrega** sozinho — use **remote-bootstrap** ou `sh` no script em disco montado (`ls /Volumes`).

---

## Limitações

- Não remove o serial do **Apple Business Manager** da organização.
- Não clique em **Registrar** nos Ajustes se quiser evitar MDM ativo.
- `curl \| bash` executa código remoto — use apenas se confiar na origem.

---

## Aviso legal

Use somente em dispositivos de sua propriedade ou com **autorização escrita** do responsável pelo parque. Burlar MDM corporativo pode violar políticas internas e leis aplicáveis.

---

## Créditos

- [assafdori/bypass-mdm](https://github.com/assafdori/bypass-mdm) (MIT)
- Revisão de scripts: `docs/REVIEW.md` (Grok 4.7)
