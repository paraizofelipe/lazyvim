local M = {}

-- Configuration
M.config = {
  -- Google Gemini API Configuration
  api_url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent",
  api_key_env = "GEMINI_API_KEY", -- Environment variable name for API key
  timeout = 30000, -- 30 seconds timeout
}

-- Prompts for different operations
local prompts = {
  pt_to_en = [[You are a professional translator. Translate the following Portuguese text to English.
Only output the translation, nothing else. Preserve the original formatting and line breaks.

Text to translate:
%s]],

  en_to_pt = [[You are a professional translator. Translate the following English text to Brazilian Portuguese.
Only output the translation, nothing else. Preserve the original formatting and line breaks.

Text to translate:
%s]],

  fix_pt = [[You are a professional Portuguese language editor. Review and improve the following Brazilian Portuguese text.
Fix any spelling, grammar, and punctuation errors. Improve clarity and fluency while maintaining the original meaning and tone.
Only output the corrected text, nothing else. Preserve the original formatting and line breaks.

Text to review:
%s]],
}

-- Function to get visual selection
local function get_visual_selection()
  -- Exit visual mode to update '< and '> marks
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "\22" then
    -- Press Escape to exit visual mode and update marks
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
  end

  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  local start_row = start_pos[2]
  local start_col = start_pos[3]
  local end_row = end_pos[2]
  local end_col = end_pos[3]

  -- Check if marks are valid
  if start_row == 0 or end_row == 0 then
    return "", nil, nil
  end

  local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)

  if #lines == 0 then
    return "", nil, nil
  end

  -- Handle single line selection
  if #lines == 1 then
    lines[1] = string.sub(lines[1], start_col, end_col)
  else
    -- Handle multi-line selection
    lines[1] = string.sub(lines[1], start_col)
    lines[#lines] = string.sub(lines[#lines], 1, end_col)
  end

  return table.concat(lines, "\n"), start_pos, end_pos
end

-- Function to escape string for JSON
local function json_escape(str)
  if str then
    str = str:gsub("\\", "\\\\")
    str = str:gsub('"', '\\"')
    str = str:gsub("\n", "\\n")
    str = str:gsub("\r", "\\r")
    str = str:gsub("\t", "\\t")
  end
  return str
end

-- Function to parse JSON response from Gemini API
local function parse_gemini_response(json_str)
  -- Gemini API returns: {"candidates":[{"content":{"parts":[{"text":"..."}]}}]}
  local content = json_str:match('"text"%s*:%s*"(.-)"')
  if content then
    -- Unescape JSON strings
    content = content:gsub("\\n", "\n")
    content = content:gsub('\\"', '"')
    content = content:gsub("\\\\", "\\")
    content = content:gsub("\\/", "/")
    content = content:gsub("\\t", "\t")
    content = content:gsub("\\r", "\r")
    return content
  end

  -- Check for error message
  local error_msg = json_str:match('"message"%s*:%s*"([^"]*)"')
  if error_msg then
    return nil, "API Error: " .. error_msg
  end

  return nil, "Failed to parse response"
end

-- Function to call Gemini API
local function call_gemini(prompt, callback)
  local api_key = os.getenv(M.config.api_key_env)

  if not api_key or api_key == "" then
    callback(nil, "API key not found. Set " .. M.config.api_key_env .. " environment variable.")
    return
  end

  -- Build JSON payload for Gemini API format
  local payload = string.format('{"contents":[{"parts":[{"text":"%s"}]}]}', json_escape(prompt))

  -- Create temp file for payload (to handle special characters properly)
  local tmp_file = os.tmpname()
  local f = io.open(tmp_file, "w")
  if f then
    f:write(payload)
    f:close()
  else
    callback(nil, "Failed to create temporary file")
    return
  end

  -- Build URL with API key
  local url = string.format("%s?key=%s", M.config.api_url, api_key)

  -- Use curl to make the API request
  local curl_cmd = string.format(
    'curl -s -m %d -X POST "%s" -H "Content-Type: application/json" -d @%s',
    math.floor(M.config.timeout / 1000),
    url,
    tmp_file
  )

  -- Track if callback was already called
  local callback_called = false
  local stdout_data = {}

  vim.fn.jobstart(curl_cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            table.insert(stdout_data, line)
          end
        end
      end
    end,
    on_stderr = function(_, data)
      -- Ignore stderr for curl (progress info, etc.)
    end,
    on_exit = function(_, exit_code)
      -- Clean up temp file
      os.remove(tmp_file)

      -- Only call callback once
      if callback_called then
        return
      end
      callback_called = true

      if exit_code ~= 0 and #stdout_data == 0 then
        callback(nil, "Request failed with code: " .. exit_code)
        return
      end

      if #stdout_data > 0 then
        local response = table.concat(stdout_data, "")
        local result, err = parse_gemini_response(response)
        if result then
          callback(result, nil)
        else
          callback(nil, err or "Failed to parse response")
        end
      else
        callback(nil, "Empty response from API")
      end
    end,
  })
end

-- Function to show result in floating window
local function show_result(result, title, original_buf, start_pos, end_pos)
  -- Split result into lines
  local lines = vim.split(result, "\n", { plain = true })

  -- Add help text at the bottom
  table.insert(lines, "")
  table.insert(lines, "─────────────────────────────────────")
  table.insert(lines, "y: Replace original | c/q/Esc: Close")

  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })

  -- Calculate window size
  local max_width = 0
  for _, line in ipairs(lines) do
    max_width = math.max(max_width, vim.fn.strdisplaywidth(line))
  end

  local width = math.min(max_width + 4, math.floor(vim.o.columns * 0.8))
  local height = math.min(#lines + 2, math.floor(vim.o.lines * 0.8))

  -- Calculate position (center of screen)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Window options
  local opts = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " " .. title .. " ",
    title_pos = "center",
  }

  -- Create window
  local win = vim.api.nvim_open_win(buf, true, opts)

  -- Set window options
  vim.api.nvim_set_option_value("wrap", true, { win = win })
  vim.api.nvim_set_option_value("linebreak", true, { win = win })
  vim.api.nvim_set_option_value("winhl", "Normal:Normal,FloatBorder:FloatBorder", { win = win })

  -- Function to replace original text with result
  local function replace_with_result()
    -- Get only the result lines (exclude help text)
    local result_lines = {}
    for i = 1, #lines - 3 do -- Exclude the 3 help lines at the end
      table.insert(result_lines, lines[i])
    end

    -- Close the floating window
    vim.api.nvim_win_close(win, true)

    -- Switch to the original buffer
    vim.api.nvim_set_current_buf(original_buf)

    -- Extract position information from getpos() result
    local start_row = start_pos[2] - 1
    local start_col = start_pos[3] - 1
    local end_row = end_pos[2] - 1
    local end_col = end_pos[3]

    -- Get the actual line to validate end_col
    local end_line = vim.api.nvim_buf_get_lines(original_buf, end_row, end_row + 1, false)[1] or ""
    local line_len = #end_line

    -- Clamp end_col to actual line length
    if end_col > line_len then
      end_col = line_len
    end

    -- Replace the selected text with result
    vim.api.nvim_buf_set_text(original_buf, start_row, start_col, end_row, end_col, result_lines)

    vim.notify("Text replaced", vim.log.levels.INFO)
  end

  -- Close window on q, c, <Esc>, or <C-c>
  local close_keys = { "q", "c", "<Esc>", "<C-c>" }
  for _, key in ipairs(close_keys) do
    vim.api.nvim_buf_set_keymap(buf, "n", key, "", {
      noremap = true,
      silent = true,
      callback = function()
        vim.api.nvim_win_close(win, true)
      end,
    })
  end

  -- Replace text on y
  vim.api.nvim_buf_set_keymap(buf, "n", "y", "", {
    noremap = true,
    silent = true,
    callback = replace_with_result,
  })
end

-- Process text with Gemini
local function process_text(operation, title)
  -- Store the original buffer before getting selection
  local original_buf = vim.api.nvim_get_current_buf()

  local text, start_pos, end_pos = get_visual_selection()

  if text == "" or text == nil then
    vim.notify("No text selected", vim.log.levels.WARN)
    return
  end

  local prompt_template = prompts[operation]
  if not prompt_template then
    vim.notify("Unknown operation: " .. operation, vim.log.levels.ERROR)
    return
  end

  local prompt = string.format(prompt_template, text)

  vim.notify("Processing...", vim.log.levels.INFO)

  call_gemini(prompt, function(result, error)
    vim.schedule(function()
      if error then
        vim.notify("Error: " .. error, vim.log.levels.ERROR)
      else
        show_result(result, title, original_buf, start_pos, end_pos)
      end
    end)
  end)
end

-- Public functions for each operation
function M.translate_pt_to_en()
  process_text("pt_to_en", "PT → EN")
end

function M.translate_en_to_pt()
  process_text("en_to_pt", "EN → PT")
end

function M.fix_portuguese()
  process_text("fix_pt", "Correção PT")
end

-- Setup function
function M.setup(opts)
  -- Merge user config with defaults
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  -- Create commands
  vim.api.nvim_create_user_command("TranslatePtToEn", function()
    M.translate_pt_to_en()
  end, { range = true })

  vim.api.nvim_create_user_command("TranslateEnToPt", function()
    M.translate_en_to_pt()
  end, { range = true })

  vim.api.nvim_create_user_command("FixPortuguese", function()
    M.fix_portuguese()
  end, { range = true })

  -- Keep backward compatibility
  vim.api.nvim_create_user_command("TranslateSelection", function()
    M.translate_pt_to_en()
  end, { range = true })
end

return M
