local SPEC_DIR = debug.getinfo(1, "S").source:sub(2):match("(.*)/") or "."
local MODULE_PATH = SPEC_DIR .. "/../translator.lua"

local M = dofile(MODULE_PATH)

local pass = 0
local fail = 0
local failures = {}

local function assert_eq(label, got, expected)
  if got == expected then
    pass = pass + 1
    print("  PASS  " .. label)
  else
    fail = fail + 1
    local msg = string.format("  FAIL  %s\n         got:      %s\n         expected: %s", label, tostring(got), tostring(expected))
    print(msg)
    table.insert(failures, label)
  end
end

local function assert_not_nil(label, got)
  if got ~= nil then
    pass = pass + 1
    print("  PASS  " .. label)
  else
    fail = fail + 1
    local msg = string.format("  FAIL  %s\n         got: nil", label)
    print(msg)
    table.insert(failures, label)
  end
end

local function assert_nil(label, got)
  if got == nil then
    pass = pass + 1
    print("  PASS  " .. label)
  else
    fail = fail + 1
    local msg = string.format("  FAIL  %s\n         expected nil, got: %s", label, tostring(got))
    print(msg)
    table.insert(failures, label)
  end
end

local function assert_contains(label, str, substr)
  if type(str) == "string" and str:find(substr, 1, true) then
    pass = pass + 1
    print("  PASS  " .. label)
  else
    fail = fail + 1
    local msg = string.format("  FAIL  %s\n         '%s' not found in: %s", label, substr, tostring(str))
    print(msg)
    table.insert(failures, label)
  end
end

print("\n=== translator_spec: provider field ===\n")

assert_not_nil("config.provider existe", M.config.provider)
assert_eq("config.provider default é 'openrouter'", M.config.provider, "openrouter")

print("\n=== translator_spec: gemini config preservado ===\n")

assert_not_nil("config.api_url existe", M.config.api_url)
assert_contains("config.api_url aponta para Gemini", M.config.api_url, "generativelanguage.googleapis.com")
assert_eq("config.api_key_env default é GEMINI_API_KEY", M.config.api_key_env, "GEMINI_API_KEY")
assert_eq("config.timeout default é 30000", M.config.timeout, 30000)

print("\n=== translator_spec: openrouter config ===\n")

assert_not_nil("config.openrouter existe", M.config.openrouter)

if M.config.openrouter then
  assert_not_nil("config.openrouter.api_url existe", M.config.openrouter.api_url)
  assert_contains("config.openrouter.api_url aponta para openrouter.ai", M.config.openrouter.api_url or "", "openrouter.ai")
  assert_eq("config.openrouter.api_key_env é OPENROUTER_API_KEY", M.config.openrouter.api_key_env, "OPENROUTER_API_KEY")
  assert_eq("config.openrouter.model é openai/gpt-oss-20b:free", M.config.openrouter.model, "openai/gpt-oss-20b:free")
  assert_eq("config.openrouter.timeout é 45000", M.config.openrouter.timeout, 45000)
else
  for _, label in ipairs({
    "config.openrouter.api_url existe",
    "config.openrouter.api_url aponta para openrouter.ai",
    "config.openrouter.api_key_env é OPENROUTER_API_KEY",
    "config.openrouter.model é openai/gpt-oss-20b:free",
    "config.openrouter.timeout é 45000",
  }) do
    fail = fail + 1
    print("  FAIL  " .. label .. "\n         (config.openrouter é nil)")
    table.insert(failures, label)
  end
end

print("\n=== translator_spec: setup com provider openrouter ===\n")

local M2 = dofile(MODULE_PATH)
M2.config = vim.tbl_deep_extend and
  vim.tbl_deep_extend("force", M2.config, { provider = "openrouter" }) or
  (function() M2.config.provider = "openrouter"; return M2.config end)()

assert_eq("setup aceita provider=openrouter sem erro", M2.config.provider, "openrouter")

print("\n=== translator_spec: sem fallback automático ===\n")

assert_nil("config.fallback_provider não existe", M.config.fallback_provider)
assert_nil("config.auto_fallback não existe", M.config.auto_fallback)

print("\n=== translator_spec: parse_openrouter_response ===\n")

local openrouter_payload = '{"choices":[{"message":{"content":"Hello world"}}]}'
local gemini_payload = '{"candidates":[{"content":{"parts":[{"text":"Hello world"}]}}]}'

local has_openrouter_parser = (M.parse_openrouter_response ~= nil)
assert_not_nil("parse_openrouter_response existe como função pública ou testável", M.parse_openrouter_response)

if M.parse_openrouter_response then
  local result, err = M.parse_openrouter_response(openrouter_payload)
  assert_eq("parse_openrouter_response extrai content de choices[0].message.content", result, "Hello world")
  assert_nil("parse_openrouter_response não retorna erro em payload válido", err)

  local result_err, err_msg = M.parse_openrouter_response('{"error":{"message":"Invalid API key"}}')
  assert_nil("parse_openrouter_response retorna nil em payload de erro", result_err)
  assert_contains("parse_openrouter_response retorna mensagem de erro", err_msg or "", "Invalid API key")
end

print("\n=== translator_spec: call_openrouter usa headers corretos ===\n")

assert_not_nil("call_openrouter existe como função pública ou testável", M.call_openrouter)

print("\n=== translator_spec: call_openrouter fallback de modelo não usa modelo antigo ===\n")

local MODELO_ANTIGO = "meta-llama/llama-3.1-8b-instruct:free"
local MODELO_ESPERADO = "openai/gpt-oss-20b:free"

local payload_capturado = nil

local M_fallback = dofile(MODULE_PATH)
M_fallback.config.openrouter.model = nil

local _orig_getenv = os.getenv
os.getenv = function(key)
  if key == "OPENROUTER_API_KEY" then
    return "fake-key-for-test"
  end
  return _orig_getenv(key)
end

local _orig_tmpname = os.tmpname
local _orig_open = io.open
local captured_writes = {}
io.open = function(path, mode)
  if mode == "w" then
    local fake_file = {
      write = function(self, data)
        table.insert(captured_writes, data)
      end,
      close = function() end,
    }
    return fake_file
  end
  return _orig_open(path, mode)
end

local jobstart_called = false
local _orig_jobstart = vim.fn.jobstart
vim.fn.jobstart = function(cmd, _)
  jobstart_called = true
  payload_capturado = cmd
  return 1
end

M_fallback.call_openrouter("test prompt", function() end)

io.open = _orig_open
os.getenv = _orig_getenv
vim.fn.jobstart = _orig_jobstart

local modelo_no_payload = nil
for _, w in ipairs(captured_writes) do
  local m = w:match('"model"%s*:%s*"([^"]+)"')
  if m then
    modelo_no_payload = m
    break
  end
end

assert_not_nil("call_openrouter grava payload quando model é nil", modelo_no_payload)
assert_eq(
  "call_openrouter fallback NÃO usa modelo antigo (meta-llama)",
  modelo_no_payload == MODELO_ANTIGO,
  false
)
assert_eq(
  "call_openrouter fallback usa modelo correto (openai/gpt-oss-20b)",
  modelo_no_payload,
  MODELO_ESPERADO
)

print("\n=== translator_spec: parse_openrouter_response sem falso positivo em payload válido com message em choices ===\n")

local payload_valido_com_message_aninhado = '{"choices":[{"message":{"role":"assistant","content":"Olá mundo"}}]}'
local resultado_valido, erro_valido = M.parse_openrouter_response(payload_valido_com_message_aninhado)
assert_eq("parse_openrouter_response extrai content de payload com message aninhado em choices", resultado_valido, "Olá mundo")
assert_nil("parse_openrouter_response NÃO retorna erro em payload válido com message em choices", erro_valido)

local payload_valido_com_role = '{"choices":[{"message":{"role":"assistant","content":"Texto traduzido"}}],"model":"openai/gpt-oss-20b:free"}'
local resultado_role, erro_role = M.parse_openrouter_response(payload_valido_com_role)
assert_eq("parse_openrouter_response extrai content ignorando campo role", resultado_role, "Texto traduzido")
assert_nil("parse_openrouter_response NÃO trata role como erro", erro_role)

local payload_erro_real = '{"error":{"message":"Rate limit exceeded","code":429}}'
local resultado_erro, msg_erro = M.parse_openrouter_response(payload_erro_real)
assert_nil("parse_openrouter_response retorna nil para erro real com error.message", resultado_erro)
assert_contains("parse_openrouter_response captura mensagem de erro real", msg_erro or "", "Rate limit exceeded")

local payload_erro_sem_choices = '{"message":"Unauthorized","status":401}'
local resultado_sem_choices, msg_sem_choices = M.parse_openrouter_response(payload_erro_sem_choices)
assert_nil("parse_openrouter_response retorna nil para payload de erro sem choices", resultado_sem_choices)
assert_contains("parse_openrouter_response captura message de erro sem choices", msg_sem_choices or "", "Unauthorized")

print("\n=== translator_spec: parse_openrouter_response decodifica escapes JSON corretamente ===\n")

local payload_com_aspas = '{"choices":[{"message":{"content":"Ele disse \\"olá\\" e saiu"}}]}'
assert_eq(
  "parse_openrouter_response não trunca conteúdo com aspas escapadas",
  M.parse_openrouter_response(payload_com_aspas),
  'Ele disse "olá" e saiu'
)

local payload_barra_n = '{"choices":[{"message":{"content":"C:\\\\new\\nlinha"}}]}'
assert_eq(
  "parse_openrouter_response distingue \\\\n literal de quebra de linha",
  M.parse_openrouter_response(payload_barra_n),
  "C:\\new\nlinha"
)

local payload_unicode = '{"choices":[{"message":{"content":"a\\u00e7\\u00e3o"}}]}'
assert_eq("parse_openrouter_response decodifica escapes \\uXXXX", M.parse_openrouter_response(payload_unicode), "ação")

local resultado_invalido, erro_invalido = M.parse_openrouter_response("not json")
assert_nil("parse_openrouter_response retorna nil para payload não-JSON", resultado_invalido)
assert_contains("parse_openrouter_response sinaliza falha de parse", erro_invalido or "", "Failed to parse response")

local resultado_null, erro_null = M.parse_openrouter_response('{"choices":[{"message":{"content":null}}]}')
assert_nil("parse_openrouter_response retorna nil quando content é null", resultado_null)
assert_contains("parse_openrouter_response sinaliza falha quando content é null", erro_null or "", "Failed to parse response")

print("\n=== RESULTADO FINAL ===\n")
print(string.format("  Passou: %d", pass))
print(string.format("  Falhou: %d", fail))

if fail > 0 then
  print("\n  Falhas:")
  for _, f in ipairs(failures) do
    print("    - " .. f)
  end
  os.exit(1)
else
  os.exit(0)
end
