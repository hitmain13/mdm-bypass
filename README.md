# mdm-bypass

Ferramentas e documentação para **diagnosticar** e **reduzir o nag de inscrição DEP/MDM** no macOS (modal *“Registre no Gerenciamento Remoto”* nos Ajustes), complementando o fluxo do [assafdori/bypass-mdm](https://github.com/assafdori/bypass-mdm) no **Modo de Recuperação**.

Repositório: **https://github.com/hitmain13/mdm-bypass**

---

## Diagnóstico verificado (ambiente de referência)

Valores coletados em **14 out. 2026** no Mac usado no desenvolvimento deste projeto:

| Item | Valor verificado |
|------|------------------|
| macOS | **15.7.4** (build **24G517**) |
| SIP | **enabled** (`csrutil status`) |
| `profiles status -type enrollment` | **Enrolled via DEP: No** · **MDM enrollment: No** |
| Sintoma | Modal nos Ajustes pedindo registro remoto |
| Organização (cloud config) | **Experian** |
| URL de inscrição | `https://experian.jamfcloud.com/cloudenroll` |
| Inscrição obrigatória no perfil | **true** (`IsMandatory`) |
| Diretório crítico | `/var/db/ConfigurationProfiles/Settings` |
| Flag dos arquivos | **`restricted`** (`ls -lO`) |
| Efeito da flag | `sudo rm` → **Operation not permitted** com o sistema ligado |
| `/etc/hosts` (bloqueios MDM) | Nenhuma entrada até rodar `--clear-nag` com sucesso na etapa de hosts |
| Backup gerado pelo script | `~/Documents/mdm-bypass-backups/Settings-20261014-210617/` |

Arquivos presentes em `Settings` no momento da verificação:

- `.cloudConfigHasActivationRecord`
- `.cloudConfigRecordFound` (contém o perfil Jamf/Experian)
- `.cloudConfigTimerCheck`
- `.deviceConfigurationBits`
- `com.apple.mdm.depnag.plist` (histórico do nag nos Ajustes)
- `com.apple.mdm.prelogin.plist`

**Conclusão:** o Mac **não está inscrito no MDM**, mas o **DEP cloud config** ainda está no disco; o sistema exibe o aviso até esses arquivos serem removidos — no **macOS 15+ com SIP**, isso exige em geral o **Modo de Recuperação**.

---

## Estrutura do repositório

```text
mdm-bypass/
├── README.md
├── install.sh                 # instalação local + ~/.zshrc
├── remote-bootstrap.sh        # instalação/execução remota (curl | bash)
├── bin/
│   └── bypass-mdm             # CLI (zsh)
├── lib/
│   └── bypass-mdm.zsh         # função bypass-mdm
├── scripts/
│   ├── clear-dep-nag.sh       # macOS instalado (sudo)
│   └── clear-dep-nag-recovery.sh  # só Recovery
└── config/
    └── extra-hosts.example    # domínios extras → extra-hosts.txt
```

Após `install.sh`, links simbólicos em `~/.local/bin/` apontam para `scripts/` e `bin/`.

---

## Instalação local

```bash
cd ~/Documents/Projects/mdm-bypass
chmod +x install.sh remote-bootstrap.sh bin/bypass-mdm scripts/*.sh
./install.sh
source ~/.zshrc
bypass-mdm --status
```

---

## Execução remota (estilo assafdori)

Sem clonar o repositório — útil no **Recovery** (Wi‑Fi + Terminal):

```bash
# Instalar no home e configurar shell
curl -fsSL https://raw.githubusercontent.com/hitmain13/mdm-bypass/main/remote-bootstrap.sh | bash

# Diagnóstico
curl -fsSL https://raw.githubusercontent.com/hitmain13/mdm-bypass/main/remote-bootstrap.sh | bash -s -- status

# Limpar nag com macOS instalado (sudo; pode não remover arquivos restricted)
curl -fsSL https://raw.githubusercontent.com/hitmain13/mdm-bypass/main/remote-bootstrap.sh | bash -s -- clear-nag

# Limpar DEP no Recovery (recomendado no macOS 15+)
curl -fsSL https://raw.githubusercontent.com/hitmain13/mdm-bypass/main/remote-bootstrap.sh | bash -s -- recovery-clear

# Fluxo completo assafdori v2 (usuário temporário + bypass na instalação)
curl -fsSL https://raw.githubusercontent.com/hitmain13/mdm-bypass/main/remote-bootstrap.sh | bash -s -- recovery-assafdori
```

Equivalente direto ao upstream (só Recovery / tela MDM na instalação):

```bash
curl -fsSL https://raw.githubusercontent.com/assafdori/bypass-mdm/main/bypass-mdm-v2.sh -o bypass-mdm.sh && chmod +x bypass-mdm.sh && ./bypass-mdm.sh
```

No menu assafdori: **1) Bypass MDM from Recovery** · usuário/senha padrão: **Apple** / **1234**.

---

## Fluxo recomendado (ordem)

### A. Instalação nova ou tela de MDM no assistente

Siga o [README do assafdori](https://github.com/assafdori/bypass-mdm) como etapas prévias:

1. Apagar o disco (recomendado) e reinstalar macOS se possível.
2. Na tela de **inscrição MDM**, desligar o Mac.
3. **Modo de Recuperação** → Wi‑Fi → **Utilitários → Terminal**.
4. Executar **bypass-mdm-v2** (comando acima ou `bypass-mdm` após bootstrap).
5. Reiniciar, entrar com usuário temporário, criar conta admin, remover usuário temporário.

### B. macOS já instalado — aviso nos Ajustes (caso Experian verificado)

1. `bypass-mdm --clear-nag`  
   - Faz backup em `~/Documents/mdm-bypass-backups/`.  
   - No **15.7.4 + restricted**, a remoção dos arquivos em `Settings` **é ignorada**; hosts e serviços ainda podem ser atualizados.
2. Se `--status` ainda mostrar `.cloudConfigRecordFound` → **Recovery obrigatório**:

```bash
# No Terminal do Recovery (ajuste o caminho após ls /Volumes)
sh "/Volumes/Data - Data/Users/SEU_USUARIO/Documents/Projects/mdm-bypass/scripts/clear-dep-nag-recovery.sh"
```

Neste hardware, `diskutil list` mostra volumes APFS **Data** e **Data - Data**; no Recovery os nomes em `/Volumes` podem diferir — use `ls /Volumes` antes de colar o caminho.

3. Reiniciar e confirmar:

```bash
bypass-mdm --status
```

Esperado: **sem** `.cloudConfigRecordFound` e **MDM enrollment: No**.

---

## Comandos da CLI

| Comando | Onde | Função |
|---------|------|--------|
| `bypass-mdm` | Recovery (ideal) | Baixa e executa **assafdori v2** |
| `bypass-mdm --legacy` | Recovery | assafdori v1 |
| `bypass-mdm --clear-nag` | macOS instalado | Backup + hosts + limpeza se não `restricted` |
| `bypass-mdm --clear-nag-recovery` | Recovery | `clear-dep-nag-recovery.sh` |
| `bypass-mdm --status` | Qualquer | `profiles` + cloud config local |

---

## Domínios bloqueados em `/etc/hosts`

Padrão nos scripts:

- `deviceenrollment.apple.com`
- `mdmenrollment.apple.com`
- `iprofiles.apple.com`
- `experian.jamfcloud.com`

Copie `config/extra-hosts.example` → `config/extra-hosts.txt` para adicionar domínios (ex.: outro tenant Jamf).

---

## Limitações (verificadas)

- O **serial** pode continuar listado no **Apple Business Manager** da organização; estes scripts atuam no **estado local** e na **tentativa de inscrição**.
- **Não clique em “Registrar”** nos Ajustes se o objetivo é evitar MDM ativo (lock/wipe/políticas remotas).
- Após **atualizações major** do macOS, rode `bypass-mdm --status` de novo; o cloud config pode ser recriado.
- Restaurar backup manual (se necessário): arquivos em `~/Documents/mdm-bypass-backups/Settings-*`.

---

## Aviso legal

Use apenas em equipamentos que você possui ou com autorização explícita. O bypass impede a configuração local do MDM; não remove o aparelho do inventário corporativo. Consulte as políticas da sua organização.

---

## Créditos

- Bypass na instalação: [assafdori/bypass-mdm](https://github.com/assafdori/bypass-mdm) (MIT).
- Este repositório: scripts de diagnóstico, limpeza DEP nos Ajustes, Recovery e bootstrap remoto.
