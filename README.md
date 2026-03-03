# Jira Codex Skill (`$jira`)

Gere documentos de planejamento técnico a partir de uma chave ou URL de issue no Jira.

## Instalação Global (Codex-first)

No Codex interativo:

```text
Use $skill-installer to install https://github.com/brenonovelli/codex-skill-jira as jira
```

Ou pelo terminal com Codex:

```bash
codex exec --skip-git-repo-check -s workspace-write --add-dir "$HOME/.codex" --add-dir /tmp 'Use $skill-installer to install https://github.com/brenonovelli/codex-skill-jira as jira'
```

Nota: use aspas simples no `codex exec` para o shell não expandir `$skill-installer`.

Por que essas flags:
- `--skip-git-repo-check`: permite instalação global fora de um diretório Git confiável.
- `-s workspace-write`: evita falhas do sandbox `read-only` durante a instalação.
- `--add-dir "$HOME/.codex"` e `--add-dir /tmp`: libera escrita no destino e em diretórios temporários.

Se seu ambiente ainda bloquear escrita, use:

```bash
codex exec --skip-git-repo-check -s danger-full-access 'Use $skill-installer to install https://github.com/brenonovelli/codex-skill-jira as jira'
```

Se seu ambiente bloquear acesso ao `github.com`, instale a partir de um clone local:

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

Por que isso acontece: o `codex exec` exige verificação de diretório confiável (geralmente um repositório Git) antes de rodar comandos. Como a instalação da skill é global, pular essa verificação nesse caso é esperado.

Depois da instalação, reinicie o Codex.

## Configuração do Projeto

Peça ao Codex para configurar as credenciais globais do `$jira`:

```text
Configure Jira credentials for $jira
```

O Codex vai pedir:
- `JIRA_BASE_URL`
- `JIRA_EMAIL`
- `JIRA_API_TOKEN`

As credenciais são salvas no arquivo global da skill:

```text
~/.codex/skills/jira/.env.local
```

## Uso

Dentro de qualquer projeto:

```text
$jira VA-1234
```

Ou mencione a issue de forma natural:
- `Vamos trabalhar na VA-1234`
- `Planeje https://company.atlassian.net/browse/VA-1234`

## Arquivos Gerados

- `docs/<ISSUE>-spec.md`
- `docs/<ISSUE>-implementation-plan.md`
- `docs/<ISSUE>-checklist.md`
- `docs/<ISSUE>-jira-summary.md`

## Mais Detalhes

Veja `docs/WORKSPACE_GUIDE.md`.
