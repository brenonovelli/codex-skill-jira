# Jira Codex Skill (`$jira`)

Gere documentos estruturados de planejamento técnico a partir de uma chave ou URL de issue no Jira.

A skill pode ser instalada globalmente e utilizada em qualquer projeto via comando `$jira`.

---

## Índice

- [Antes de Instalar](#antes-de-instalar)
- [Instalação Global](#instalação-global)
- [Configuração das Credenciais](#configuração-das-credenciais)
- [Uso](#uso)
- [Arquivos Gerados](#arquivos-gerados)
- [Modo Offline (Fixture)](#modo-offline-fixture)
- [Documentação Viva](#documentação-viva)
- [Problemas comuns](#problemas-comuns)

---

# Antes de Instalar

Antes de começar, tenha em mãos:

- A URL base do seu Jira (ex: `https://suaempresa.atlassian.net`)
- O e-mail da sua conta Atlassian
- Um API Token válido
  - Se você ainda não tem um API Token, pode gerar [aqui](https://id.atlassian.com/manage-profile/security/api-tokens).

Você precisará dessas informações logo após a instalação para configurar a skill.

---

# Instalação Global

## Método padrão (recomendado)

No Codex interativo:

```text
Use $skill-installer to install https://github.com/brenonovelli/codex-skill-jira as jira
```

Prompt conversacional recomendado (mais direto):

```text
Use $skill-installer to install https://github.com/brenonovelli/codex-skill-jira as jira using path "." directly, without listing curated skills first.
```

### Via Codex CLI (opcional)

```bash
codex exec --skip-git-repo-check -s workspace-write --add-dir "$HOME/.codex" --add-dir /tmp 'Use $skill-installer to install https://github.com/brenonovelli/codex-skill-jira as jira'
```

### Fallback seguro (mais determinístico)

Se quiser evitar o fluxo agêntico e chamar o backend de instalação diretamente:

```bash
python3 ~/.codex/skills/.system/skill-installer/scripts/install-skill-from-github.py --url https://github.com/brenonovelli/codex-skill-jira --path . --name jira
```

Ou, se estiver no clone deste repositório:

```bash
scripts/install_global_skill.sh
```

---

#### Por que essas flags?

- `--skip-git-repo-check`  
  Permite instalar a skill fora de um diretório Git confiável (instalação global).

- `-s workspace-write`  
  Evita falhas relacionadas ao sandbox `read-only`.

- `--add-dir "$HOME/.codex"` e `--add-dir /tmp`  
  Libera permissão de escrita nos diretórios necessários para instalação.

---

Após a instalação, reinicie o Codex.

---

# Configuração das Credenciais

Após instalar, peça ao Codex para configurar as credenciais da integração com o Jira:

```text
Configure Jira credentials for $jira
```

O Codex irá solicitar:

- A URL do seu Jira
- Seu e-mail Atlassian
- Seu API Token

Observação de segurança:
- o token é coletado por prompt silencioso;
- em modo não interativo, use variável de ambiente `JIRA_API_TOKEN`.

Essas informações são armazenadas automaticamente no arquivo global da skill:

```
~/.codex/skills/jira/.env.local
```

Após configurar, reinicie o Codex para garantir que as credenciais sejam carregadas corretamente.

---

# Uso

Dentro de qualquer projeto:

```text
$jira VA-1234
```

Comportamento padrão:
- execução direta com defaults (`plan`, `feature-folder`, `ask`) sem confirmação intermediária.
- se quiser confirmação antes de executar, peça explicitamente no prompt (modo sob demanda).

Ou mencione a issue naturalmente:

- `Vamos trabalhar na VA-1234`
- `Planeje https://company.atlassian.net/browse/VA-1234`

---

# Arquivos Gerados

Para cada issue processada, são criados:

- `docs/<ISSUE>-spec.md`
- `docs/<ISSUE>-implementation-plan.md`
- `docs/<ISSUE>-checklist.md`
- `docs/<ISSUE>-jira-summary.md`

---

# Modo Offline (Fixture)

O modo offline existe para permitir testes determinísticos do fluxo sem depender da API do Jira,
credenciais ou conectividade de rede.

Fixture atual versionado:

- `fixtures/jira/VA-1564.raw.json`

Smoke test local:

```bash
tests/offline_smoke.sh
```

CI:

- Workflow: `.github/workflows/offline-smoke.yml`
- O workflow executa o smoke test offline em `push` e `pull_request`.

---

# Documentação Viva

Use o [WORKSPACE_GUIDE](docs/WORKSPACE_GUIDE.md) como fonte de aprendizado contínuo da skill
(decisões, trade-offs, padrões e ajustes de operação ao longo do tempo).

---

## Problemas comuns

### Erro de diretório confiável

Se aparecer:

```text
Not inside a trusted directory and --skip-git-repo-check was not specified.
```

Execute novamente com:

```bash
codex exec --skip-git-repo-check -s workspace-write --add-dir "$HOME/.codex" --add-dir /tmp 'Use $skill-installer to install https://github.com/brenonovelli/codex-skill-jira as jira'
```

Esse erro ocorre porque o `codex exec` exige que o comando seja executado dentro de um diretório Git confiável. Como a instalação da skill é global, ignorar essa verificação é esperado nesse cenário.

---

### Prompt de lista curada (`list-skills.py`)

Se o Codex perguntar se pode rodar `list-skills.py` para consultar skills curadas:
- escolha `No`;
- execute o fallback seguro:

```bash
python3 ~/.codex/skills/.system/skill-installer/scripts/install-skill-from-github.py --url https://github.com/brenonovelli/codex-skill-jira --path . --name jira
```

---

### Acesso ao GitHub bloqueado

Instale a partir de um clone local:

```bash
mkdir -p ~/.codex/skills/jira
rsync -a --delete --exclude '.git' '/path/to/codex-skill-jira/' ~/.codex/skills/jira/
```
