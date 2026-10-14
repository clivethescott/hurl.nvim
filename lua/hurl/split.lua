local ui = require('hurl.ui')
local utils = require('hurl.utils')

local M = {}

local splits = {}

local function current()
  local tab = vim.api.nvim_get_current_tabpage()
  splits[tab] = splits[tab] or {}
  return splits[tab]
end

--- Replace the split's content; the buffer is read-only otherwise
local function set_lines(split, lines)
  vim.bo[split.bufnr].modifiable = true
  ui.set_lines(split.bufnr, lines)
  vim.bo[split.bufnr].modifiable = false
end

local function open()
  local split = current()
  if ui.is_open(split.winid) then
    return split
  end
  local config = _HURL_GLOBAL_CONFIG
  split.bufnr = ui.new_buf('markdown')
  vim.bo[split.bufnr].modifiable = false
  split.winid = ui.open_split(split.bufnr, config.split_position, config.split_size)

  local function quit()
    ui.close(split.winid)
  end

  ui.map(split.bufnr, 'n', config.mappings.close, quit)
  if config.auto_close then
    vim.api.nvim_create_autocmd('BufLeave', {
      buffer = split.bufnr,
      once = true,
      callback = function()
        vim.schedule(quit)
      end,
    })
  end
  return split
end

-- Show content in a split
---@param data table
---   - body string
---   - headers table
---@param type 'json' | 'html' | 'xml' | 'text' | 'markdown'
M.show = function(data, type)
  local split = open()

  local output_lines = {}

  if type == 'markdown' then
    -- For markdown, we just use the body as-is
    output_lines = vim.split(data.body, '\n')
  else
    -- Add body
    table.insert(output_lines, '# Body')
    table.insert(output_lines, '')
    table.insert(output_lines, '```' .. type)
    local content = utils.format(data.body, type)
    if content then
      for _, line in ipairs(content) do
        table.insert(output_lines, line)
      end
    else
      table.insert(output_lines, 'No content')
    end
    table.insert(output_lines, '```')
    table.insert(output_lines, '')

    -- Add headers
    table.insert(output_lines, '# Headers')
    table.insert(output_lines, '')
    if data.headers then
      for key, value in pairs(data.headers) do
        table.insert(output_lines, string.format('- **%s**: %s', key, value))
      end
    else
      table.insert(output_lines, 'No headers available')
    end

    -- Add status and response time
    table.insert(output_lines, '')
    local response_time = tonumber(data.response_time) or 0
    table.insert(output_lines, string.format('**Status**: %s', data.status or 'N/A'))
    table.insert(output_lines, string.format('**Response Time**: %.2f ms', response_time))
    table.insert(output_lines, '')

    -- Add curl command
    table.insert(output_lines, '# Curl Command')
    table.insert(output_lines, '')
    table.insert(output_lines, '```bash')
    table.insert(output_lines, data.curl_command or 'N/A')
    table.insert(output_lines, '```')
  end

  -- Set content
  set_lines(split, output_lines)
end

M.clear = function()
  local split = current()
  -- Check if split is open
  if not ui.is_open(split.winid) then
    return
  end

  -- Clear the buffer and add `Processing...` message with the current Hurl command
  set_lines(split, {
    'Processing...',
    '',
    '# Hurl Command',
    '',
    '```sh',
    _HURL_GLOBAL_CONFIG.last_hurl_command or 'N/A',
    '```',
  })
end

return M
