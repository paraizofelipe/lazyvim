# Protocolo de Validação Manual — OpenRouter Provider (Fase Red)

## Pré-condições

- `OPENROUTER_API_KEY` NÃO definida no ambiente (estado atual)
- `GEMINI_API_KEY` definida (estado atual)
- Plugin no estado atual (sem suporte a OpenRouter)

---

## MANUAL-01 — provider=openrouter sem API key retorna erro correto

**Objetivo:** confirmar que o plugin reporta ausência de `OPENROUTER_API_KEY` (não de `GEMINI_API_KEY`)

**Passos:**
1. Abrir Neovim: `nvim /tmp/test_translator.txt`
2. Inserir qualquer texto e selecionar em visual mode
3. Executar `:lua require('custom.plugins.translator').setup({ provider = 'openrouter' })`
4. Executar `:TranslatePtToEn`

**Resultado esperado (RED — comportamento atual):**
- Notificação de erro menciona `GEMINI_API_KEY` (errado)
- OU: nenhum erro de "provider desconhecido" — o campo `provider` é silenciosamente ignorado

**Resultado esperado (GREEN — após implementação):**
- Notificação: `"API key not found. Set OPENROUTER_API_KEY environment variable."`

---

## MANUAL-02 — provider=openrouter usa endpoint correto

**Objetivo:** confirmar que a requisição vai para `openrouter.ai`, não para `generativelanguage.googleapis.com`

**Passos:**
1. `export OPENROUTER_API_KEY=sk-or-invalid-key-for-test`
2. Abrir Neovim, selecionar texto
3. Executar `:lua require('custom.plugins.translator').setup({ provider = 'openrouter' })`
4. Executar `:TranslatePtToEn`
5. Observar a notificação de erro

**Resultado esperado (RED — comportamento atual):**
- Erro menciona falha na API Gemini (endpoint errado)
- OU: erro de autenticação Gemini (401 com mensagem Gemini)

**Resultado esperado (GREEN — após implementação):**
- Erro de autenticação OpenRouter: `"API Error: ..."` com mensagem do OpenRouter
- OU: resposta válida se a key for real

---

## MANUAL-03 — provider=gemini (default) não é afetado

**Objetivo:** confirmar que o comportamento Gemini existente não regride

**Passos:**
1. Abrir Neovim sem configurar provider
2. Selecionar texto
3. Executar `:TranslatePtToEn`

**Resultado esperado (RED e GREEN — deve passar em ambos):**
- Comportamento idêntico ao atual: usa `GEMINI_API_KEY`, endpoint Gemini

---

## MANUAL-04 — timeout de 45000ms aplicado ao OpenRouter

**Objetivo:** confirmar que o curl usa `-m 45` para OpenRouter (não `-m 30`)

**Passos:**
1. `export OPENROUTER_API_KEY=sk-or-test`
2. Executar no terminal (fora do nvim):
```bash
strace -e trace=execve nvim --headless -c "
lua local M = require('custom.plugins.translator')
M.setup({ provider = 'openrouter' })
" 2>&1 | grep "curl.*-m"
```

**Resultado esperado (RED — comportamento atual):**
- Linha curl com `-m 30` (timeout Gemini)
- OU: nenhuma linha curl com OpenRouter

**Resultado esperado (GREEN — após implementação):**
- Linha curl com `-m 45`

---

## MANUAL-05 — provider inválido retorna erro explícito

**Objetivo:** confirmar que provider desconhecido não falha silenciosamente

**Passos:**
1. Abrir Neovim, selecionar texto
2. Executar `:lua require('custom.plugins.translator').setup({ provider = 'anthropic' })`
3. Executar `:TranslatePtToEn`

**Resultado esperado (RED — comportamento atual):**
- Nenhum erro de "provider inválido" — falha silenciosa ou usa Gemini

**Resultado esperado (GREEN — após implementação):**
- Notificação de erro: `"Unknown provider: anthropic"`

---

## Checklist de Execução

| ID | Descrição | Red confirmado | Green confirmado |
|----|-----------|---------------|-----------------|
| MANUAL-01 | Erro correto sem API key OpenRouter | [ ] | [ ] |
| MANUAL-02 | Endpoint correto para OpenRouter | [ ] | [ ] |
| MANUAL-03 | Gemini default não regride | [ ] | [ ] |
| MANUAL-04 | Timeout 45000ms aplicado | [ ] | [ ] |
| MANUAL-05 | Provider inválido retorna erro | [ ] | [ ] |
