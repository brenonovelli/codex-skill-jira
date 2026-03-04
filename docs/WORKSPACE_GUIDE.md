# Guia da Skill Jira

## Visão Geral

Este repositório fornece uma skill global do Codex chamada `$jira`.
Use-a para transformar uma chave ou URL de issue do Jira em documentos de planejamento técnico.

## Instalação Global

### Método padrão (recomendado)

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

Por que essas flags:
- `--skip-git-repo-check`: permite instalação global fora de um diretório Git confiável.
- `-s workspace-write`: evita falhas do sandbox `read-only` durante a instalação.
- `--add-dir "$HOME/.codex"` e `--add-dir /tmp`: libera acesso de escrita no destino e em diretórios temporários.

Se o acesso ao `github.com` estiver bloqueado, sincronize a partir de um clone local:

```bash
mkdir -p ~/.codex/skills/jira
rsync -a --delete --exclude '.git' '/path/to/codex-skill-jira/' ~/.codex/skills/jira/
```

Se aparecer:

```text
Not inside a trusted directory and --skip-git-repo-check was not specified.
```

use:

```bash
codex exec --skip-git-repo-check -s workspace-write --add-dir "$HOME/.codex" --add-dir /tmp 'Use $skill-installer to install https://github.com/brenonovelli/codex-skill-jira as jira'
```

Por que isso acontece: o `codex exec` verifica se você está em um diretório confiável (tipicamente um repositório Git). Como a instalação da skill é global, ignorar essa checagem aqui é normal.

Se o Codex pedir para rodar `list-skills.py` (lista curada), recuse e rode o fallback seguro:

```bash
python3 ~/.codex/skills/.system/skill-installer/scripts/install-skill-from-github.py --url https://github.com/brenonovelli/codex-skill-jira --path . --name jira
```

Após a instalação, reinicie o Codex.

## Configuração do Projeto

Peça ao Codex para configurar as credenciais globalmente:

```text
Configure Jira credentials for $jira
```

O Codex deve coletar:
- `JIRA_BASE_URL`
- `JIRA_EMAIL`
- `JIRA_API_TOKEN`

E salvá-las em:

```text
~/.codex/skills/jira/.env.local
```

Comportamento das credenciais:
- Se as credenciais Jira estiverem ausentes, o fluxo para com erro explícito.
- O modo offline com fixture é suportado quando a skill recebe um JSON local do Jira.

## Uso

Chame a skill diretamente:

```text
$jira VA-1234
```

Comportamento padrão:
- usa defaults (`mode=plan`, `workspace=feature-folder`, `clone=auto`);
- com `clone=auto`, clona os repositórios detectados em `repos/` no modo `plan` e no `run`;
- no `mode=plan`, consolida contexto de issue + repos e deixa o handoff pronto para `/plan`;
- executa sem confirmação interativa.

Confirmação sob demanda:
- se o usuário pedir confirmação antes de executar, use `--confirm ask` no `jira_bootstrap.sh`.

Você também pode mencionar issues de forma natural na conversa:
- `Vamos trabalhar na VA-1234`
- `Me ajuda com a VA-1234`
- `Planeje https://company.atlassian.net/browse/VA-1234`

## Arquivos Gerados

Para cada issue:
- `docs/<ISSUE>-spec.md`
- `docs/<ISSUE>-implementation-plan.md`
- `docs/<ISSUE>-checklist.md`
- `docs/<ISSUE>-jira-summary.md`

Quando houver links de repositório e clone habilitado:
- `repos/<repo-name>`

## Modo Offline (Fixture)

Objetivo:
- validar o pipeline sem depender de Jira real;
- reproduzir bugs com entrada fixa;
- habilitar teste em CI sem credenciais.

Como funciona:
- `jira_bootstrap.sh --issue-json <arquivo>` desvia a chamada de rede;
- `jira_get_issue.sh --input-file <arquivo>` normaliza o JSON local;
- o restante da geração de artefatos é idêntico ao modo online.

Fixture de referência:
- `fixtures/jira/VA-1564.raw.json`

Smoke test:
- `tests/offline_smoke.sh`

CI:
- `.github/workflows/offline-smoke.yml`

## Aprendizados Acumulados

Use esta seção para registrar melhorias contínuas da skill:
- ajustes de prompts/instruções;
- problemas reais encontrados em produção;
- padrões de troubleshooting;
- decisões de simplificação/remoção de escopo e seus impactos.

### 2026-03-04 - Checagem de necessidade dos scripts

- `jira_bootstrap.sh`: essencial (entrypoint e contrato principal da skill).
- `jira_get_issue.sh`: essencial (normalização dos dados Jira + suporte offline com `--input-file`).
- `jira_configure_credentials.sh`: útil, mas opcional (conveniência de onboarding).

Conclusão atual:
- manter 3 scripts como base (`jira_bootstrap.sh`, `jira_get_issue.sh`, `jira_configure_credentials.sh`).

### 2026-03-04 - Segurança e UX de execução

- `jira_bootstrap.sh` passou a suportar `--confirm ask|off` (default `off`).
- `jira_bootstrap.sh` chama `jira_get_issue.sh` via `bash`, reduzindo risco de falha por bit de execução em instalação.
- `jira_configure_credentials.sh` deixou de aceitar `--token` por argumento de CLI.
  - token agora deve vir por prompt silencioso (preferido) ou variável de ambiente `JIRA_API_TOKEN` em modo não interativo.

### 2026-03-04 - Workspace completo por padrão

- `jira_bootstrap.sh` passou a usar `clone=auto` por default.
- a etapa de clone não depende mais de `mode=run` (também executa em `plan`).
- os artefatos de plano e resumo agora incluem uma seção `Repository Workspace` com resultado da materialização de repositórios.

### 2026-03-04 - Handoff determinístico para `/plan`

- ordem do fluxo em `mode=plan`: clonar (quando houver repos) -> consolidar contexto -> handoff para `/plan`.
- os artefatos incluem contexto consolidado para reduzir retrabalho e aumentar precisão do planejamento.

### 2026-03-04 - Fricção observada na instalação conversacional

Fluxo observado em teste real:
- tentativa inicial sem `--path` falha para URL de repo raiz;
- tentativa com `--path jira` falha (a skill está na raiz, não em subpasta `jira`);
- sucesso com `--path . --name jira`.

Ação adotada:
- adicionar prompt conversacional recomendado para reduzir tentativas exploratórias.
