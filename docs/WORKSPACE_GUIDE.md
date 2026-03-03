# Guia da Skill Jira

## Visão Geral

Este repositório fornece uma skill global do Codex chamada `$jira`.
Use-a para transformar uma chave ou URL de issue do Jira em documentos de planejamento técnico.

## Instalação Global

### Codex Interativo (recomendado)

```text
Use $skill-installer to install https://github.com/brenonovelli/codex-skill-jira as jira
```

### Terminal com Codex

```bash
codex exec --skip-git-repo-check -s workspace-write --add-dir "$HOME/.codex" --add-dir /tmp 'Use $skill-installer to install https://github.com/brenonovelli/codex-skill-jira as jira'
```

Nota: use aspas simples para o shell não expandir `$skill-installer`.

Por que essas flags:
- `--skip-git-repo-check`: permite instalação global fora de um diretório Git confiável.
- `-s workspace-write`: evita falhas do sandbox `read-only` durante a instalação.
- `--add-dir "$HOME/.codex"` e `--add-dir /tmp`: libera acesso de escrita no destino e em diretórios temporários.

Se as restrições de escrita persistirem, use:

```bash
codex exec --skip-git-repo-check -s danger-full-access 'Use $skill-installer to install https://github.com/brenonovelli/codex-skill-jira as jira'
```

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
