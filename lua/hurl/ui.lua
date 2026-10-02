--- Minimal window helpers built on the native nvim API
local M = {}

local SPLIT_DIRECTIONS = { right = 'right', left = 'left', top = 'above', bottom = 'below' }

--- Resolve an absolute size or a percentage string like '50%'
---@param value number|string
---@param total number
---@return number
local function resolve(value, total)
  if type(value) == 'string' then
    local pct = value:match('^(%d+)%%$')
    return pct and math.floor(total * tonumber(pct) / 100) or tonumber(value)
  end
  return value
end

---@param filetype? string
---@return integer bufnr
M.new_buf = function(filetype)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'
  if filetype then
    vim.bo[buf].filetype = filetype
  end
  return buf
end

---@param buf integer
---@param lines string[]
M.set_lines = function(buf, lines)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

---@param buf integer
---@param mode string|string[]
---@param lhs string
---@param fn function
M.map = function(buf, mode, lhs, fn)
  vim.keymap.set(mode, lhs, fn, { buffer = buf })
end

---@param win integer|nil
---@return boolean
M.is_open = function(win)
  return win ~= nil and vim.api.nvim_win_is_valid(win)
end

---@param win integer|nil
M.close = function(win)
  if M.is_open(win) then
    vim.api.nvim_win_close(win, true)
  end
end

--- Row/col/size (border included) of a float placed in the editor
---@param width number|string
---@param height number|string
---@param position? string|number percent of the free space, '50%' centers
---@return integer row, integer col, integer width, integer height
M.place = function(width, height, position)
  local cols, rows = vim.o.columns, vim.o.lines - vim.o.cmdheight
  local w, h = math.min(resolve(width, cols), cols), math.min(resolve(height, rows), rows)
  local pct = tonumber(tostring(position or '50%'):match('^(%d+)%%?$')) or 50
  return math.floor((rows - h) * pct / 100), math.floor((cols - w) * pct / 100), w, h
end

--- Open an editor-wide split showing `buf` and focus it
---@param buf integer
---@param position string 'right' | 'left' | 'top' | 'bottom'
---@param size number|string
---@return integer winid
M.open_split = function(buf, position, size)
  local direction = SPLIT_DIRECTIONS[position] or 'right'
  local config = { split = direction, win = -1 }
  if direction == 'right' or direction == 'left' then
    config.width = resolve(size, vim.o.columns)
  else
    config.height = resolve(size, vim.o.lines)
  end
  return vim.api.nvim_open_win(buf, true, config)
end

return M
