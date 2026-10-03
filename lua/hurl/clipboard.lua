local M = {}

-- hurlfmt does not accept these curl response and terminal flags. Remove them without
-- changing quoted values or request options such as -L.
local ignored_long_options = {
  ['--fail'] = true,
  ['--fail-with-body'] = true,
  ['--silent'] = true,
  ['--show-error'] = true,
  ['--no-progress-meter'] = true,
  ['--progress-bar'] = true,
}

local options_with_values = {
  ['-b'] = true,
  ['-d'] = true,
  ['-H'] = true,
  ['-o'] = true,
  ['-u'] = true,
  ['-X'] = true,
  ['--cookie'] = true,
  ['--data'] = true,
  ['--data-raw'] = true,
  ['--header'] = true,
  ['--max-redirs'] = true,
  ['--output'] = true,
  ['--request'] = true,
  ['--retry'] = true,
  ['--url'] = true,
  ['--user'] = true,
}

local function normalize_curl_options(command)
  local output = {}
  local token = {}
  local quote
  local escaped = false
  local next_is_value = false
  local after_options = false

  local function flush_token()
    if #token == 0 then
      return
    end

    local value = table.concat(token)
    token = {}
    if next_is_value then
      next_is_value = false
    elseif not after_options then
      if value == '--' then
        after_options = true
      elseif ignored_long_options[value] then
        return
      else
        local flags = value:match('^%-([fsSLkv]+)$')
        if flags then
          local kept = flags:gsub('[fsS]', '')
          if kept == '' then
            return
          end
          value = '-' .. kept
        end
        next_is_value = options_with_values[value] or false
      end
    end
    table.insert(output, value)
  end

  for i = 1, #command do
    local char = command:sub(i, i)
    if escaped then
      table.insert(token, char)
      escaped = false
    elseif char == '\\' and quote ~= "'" then
      table.insert(token, char)
      escaped = true
    elseif char == quote then
      table.insert(token, char)
      quote = nil
    elseif (char == "'" or char == '"') and not quote then
      table.insert(token, char)
      quote = char
    elseif char:match('%s') and not quote then
      flush_token()
      table.insert(output, char)
    else
      table.insert(token, char)
    end
  end
  flush_token()

  return table.concat(output)
end

--- Convert a curl command from the system clipboard and insert it below the cursor.
function M.paste_curl()
  local curl = vim.fn.getreg('+')
  if not curl or curl:match('^%s*$') then
    vim.notify('hurl: system clipboard is empty', vim.log.levels.WARN)
    return
  end

  if vim.fn.executable('hurlfmt') ~= 1 then
    vim.notify('hurl: hurlfmt is required to paste curl commands', vim.log.levels.ERROR)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  if not vim.bo[bufnr].modifiable then
    vim.notify('hurl: current buffer is not modifiable', vim.log.levels.WARN)
    return
  end
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local changedtick = vim.api.nvim_buf_get_changedtick(bufnr)

  vim.system({ 'hurlfmt', '--in', 'curl', '--out', 'hurl', '--no-color' }, {
    stdin = normalize_curl_options(curl),
    text = true,
  }, function(result)
    vim.schedule(function()
      if result.code ~= 0 or not result.stdout or result.stdout:match('^%s*$') then
        local detail = (result.stderr or ''):gsub('%s+$', '')
        local message = 'hurl: could not convert clipboard curl command'
        if detail ~= '' then
          message = message .. ': ' .. detail
        end
        vim.notify(message, vim.log.levels.ERROR)
        return
      end

      if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
        return
      end
      if vim.api.nvim_buf_get_changedtick(bufnr) ~= changedtick then
        vim.notify('hurl: buffer changed before curl conversion finished', vim.log.levels.WARN)
        return
      end
      if not vim.bo[bufnr].modifiable then
        vim.notify('hurl: current buffer is not modifiable', vim.log.levels.WARN)
        return
      end

      local lines = vim.split(result.stdout:gsub('[\r\n]+$', ''), '\n', { plain = true })
      local current = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1]
      if row == 1 and current == '' and vim.api.nvim_buf_line_count(bufnr) == 1 then
        vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, lines)
        return
      end

      local next_line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
      if current and current ~= '' then
        table.insert(lines, 1, '')
      end
      if next_line and next_line ~= '' then
        table.insert(lines, '')
      end
      vim.api.nvim_buf_set_lines(bufnr, row, row, false, lines)
    end)
  end)
end

return M
