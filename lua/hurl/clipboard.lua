local M = {}

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
    stdin = curl,
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
