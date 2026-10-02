local ui = require('hurl.ui')
local utils = require('hurl.utils')

local M = {}

local BORDER = 'single'
local INFO_RATIO = 0.3

local popups = { info = nil, body = nil } -- { bufnr, winid }
local augroup = vim.api.nvim_create_augroup('HurlPopup', { clear = true })

local function is_open()
  return popups.body ~= nil and ui.is_open(popups.body.winid)
end

--- Window configs of the info (top) and body (bottom) popups, stacked as one column
local function layout()
  local size = _HURL_GLOBAL_CONFIG.popup_size
  local row, col, width, height = ui.place(size.width, size.height, _HURL_GLOBAL_CONFIG.popup_position)
  local info_height = math.floor(height * INFO_RATIO)
  local border = 2
  return {
    info = { relative = 'editor', row = row, col = col, width = width - border, height = math.max(info_height - border, 1) },
    body = {
      relative = 'editor',
      row = row + info_height,
      col = col,
      width = width - border,
      height = math.max(height - info_height - border, 1),
    },
  }
end

local function close()
  vim.api.nvim_clear_autocmds({ group = augroup })
  for _, popup in pairs(popups) do
    ui.close(popup.winid)
  end
end

local function open()
  if is_open() then
    return
  end
  local config = _HURL_GLOBAL_CONFIG
  local geometry = layout()
  for name, win_config in pairs(geometry) do
    local bufnr = ui.new_buf('markdown')
    win_config.style = 'minimal'
    win_config.border = BORDER
    popups[name] = { bufnr = bufnr, winid = vim.api.nvim_open_win(bufnr, name == 'body', win_config) }
  end

  local function focus(name)
    return function()
      vim.api.nvim_set_current_win(popups[name].winid)
    end
  end
  for name, popup in pairs(popups) do
    local other = name == 'body' and 'info' or 'body'
    ui.map(popup.bufnr, 'n', config.mappings.close, close)
    ui.map(popup.bufnr, 'n', config.mappings.next_panel, focus(other))
    ui.map(popup.bufnr, 'n', config.mappings.prev_panel, focus(other))
  end

  -- keep the column in place when the editor is resized
  vim.api.nvim_create_autocmd('VimResized', {
    group = augroup,
    callback = function()
      if not is_open() then
        return
      end
      for name, win_config in pairs(layout()) do
        vim.api.nvim_win_set_config(popups[name].winid, win_config)
      end
    end,
  })

  -- close both popups once focus leaves them
  if config.auto_close then
    for _, popup in pairs(popups) do
      vim.api.nvim_create_autocmd('BufLeave', {
        group = augroup,
        buffer = popup.bufnr,
        callback = function()
          vim.schedule(function()
            local current = vim.api.nvim_get_current_buf()
            for _, p in pairs(popups) do
              if p.bufnr == current then
                return
              end
            end
            close()
          end)
        end,
      })
    end
  end
end

-- Show content in a popup
---@param data table
---   - body string
---   - headers table
---@param type 'json' | 'html' | 'xml' | 'text'
M.show = function(data, type)
  open()

  local info_lines = {}

  -- Add request information
  table.insert(info_lines, '# Request')
  table.insert(info_lines, '')
  table.insert(info_lines, string.format('**Method**: %s', data.method))
  table.insert(info_lines, string.format('**URL**: %s', data.url))
  table.insert(info_lines, string.format('**Status**: %s', data.status))
  table.insert(info_lines, '')

  -- Add curl command
  table.insert(info_lines, '# Curl Command')
  table.insert(info_lines, '')
  table.insert(info_lines, '```bash')
  table.insert(info_lines, data.curl_command or 'N/A')
  table.insert(info_lines, '```')
  table.insert(info_lines, '')

  -- Add headers
  table.insert(info_lines, '# Headers')
  table.insert(info_lines, '')
  for key, value in pairs(data.headers) do
    table.insert(info_lines, string.format('- **%s**: %s', key, value))
  end

  -- Add response time
  table.insert(info_lines, '')
  table.insert(info_lines, string.format('**Response Time**: %.2f ms', data.response_time))

  ui.set_lines(popups.info.bufnr, info_lines)

  local body_lines = {}

  -- Add body
  table.insert(body_lines, '# Body')
  table.insert(body_lines, '')
  table.insert(body_lines, '```' .. type)
  local content = utils.format(data.body, type)
  if content then
    for _, line in ipairs(content) do
      table.insert(body_lines, line)
    end
  else
    table.insert(body_lines, 'No content')
  end
  table.insert(body_lines, '```')

  ui.set_lines(popups.body.bufnr, body_lines)

  vim.api.nvim_set_current_win(popups.body.winid)
end

M.clear = function()
  if not is_open() then
    return
  end
  -- Clear the buffers and add `Processing...` message with the Hurl command
  for _, popup in pairs(popups) do
    ui.set_lines(popup.bufnr, {
      'Processing... ',
      _HURL_GLOBAL_CONFIG.last_hurl_command or 'N/A',
    })
  end
end

--- Show text in a large centered float
---@param title string
---@param lines table
---@param bottom? string
---@return table popup with a `map(mode, lhs, fn)` method for buffer-local mappings
M.show_text = function(title, lines, bottom)
  local row, col, width, height = ui.place('90%', '90%', '50%')
  local bufnr = ui.new_buf()
  ui.set_lines(bufnr, lines)

  local winid = vim.api.nvim_open_win(bufnr, true, {
    relative = 'editor',
    row = row,
    col = col,
    width = width - 2,
    height = height - 2,
    style = 'minimal',
    border = 'rounded',
    title = title,
    title_pos = 'center',
    footer = bottom or 'Press `q` to close',
    footer_pos = 'left',
  })

  local function quit()
    ui.close(winid)
  end
  vim.api.nvim_create_autocmd('BufLeave', {
    buffer = bufnr,
    once = true,
    callback = function()
      vim.schedule(quit)
    end,
  })
  ui.map(bufnr, 'n', 'q', quit)

  return {
    bufnr = bufnr,
    winid = winid,
    map = function(_, mode, lhs, fn)
      ui.map(bufnr, mode, lhs, fn)
    end,
  }
end

return M
