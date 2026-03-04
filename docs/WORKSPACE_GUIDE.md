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
- `codex-jira`: opcional/redundante (wrapper que só encaminha para `jira_bootstrap.sh`).

Conclusão atual:
- manter 3 scripts como base (`jira_bootstrap.sh`, `jira_get_issue.sh`, `jira_configure_credentials.sh`);
- considerar remoção do `codex-jira` se não houver uso real no time.
