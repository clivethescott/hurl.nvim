local M = {}

--- Get the git root directory of the current buffer
---@return string|nil The git root directory
local function get_git_root()
  return vim.fs.root(0, '.git')
end

--- Check if the current buffer is inside a git repo
---@return boolean
local function is_git_repo()
  return get_git_root() ~= nil
end

local function split_path(path)
  local parts = {}
  for part in string.gmatch(path, '[^/]+') do
    table.insert(parts, part)
  end
  return parts
end

M.is_git_repo = is_git_repo
M.get_git_root = get_git_root
M.split_path = split_path

return M
