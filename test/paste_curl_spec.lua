local clipboard = require('hurl.clipboard')

describe('Paste curl from clipboard', function()
  local original_getreg
  local original_executable
  local original_system
  local curl
  local result
  local command
  local input

  before_each(function()
    original_getreg = vim.fn.getreg
    original_executable = vim.fn.executable
    original_system = vim.system
    curl = 'curl https://example.com'
    result = { code = 0, stdout = 'GET https://example.com\n', stderr = '' }
    command = nil
    input = nil
    vim.cmd('enew!')

    vim.fn.getreg = function(register)
      assert.are.equal('+', register)
      return curl
    end
    vim.fn.executable = function(program)
      assert.are.equal('hurlfmt', program)
      return 1
    end
    vim.system = function(args, options, callback)
      command = args
      input = options.stdin
      callback(result)
      return {}
    end
  end)

  after_each(function()
    vim.fn.getreg = original_getreg
    vim.fn.executable = original_executable
    vim.system = original_system
  end)

  it('inserts converted Hurl between existing entries', function()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {
      'GET https://before.example',
      'GET https://after.example',
    })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })

    clipboard.paste_curl()
    assert.is_true(vim.wait(100, function()
      return vim.api.nvim_buf_line_count(0) == 5
    end))

    assert.are.same({ 'hurlfmt', '--in', 'curl', '--out', 'hurl', '--no-color' }, command)
    assert.are.equal(curl, input)
    assert.are.same({
      'GET https://before.example',
      '',
      'GET https://example.com',
      '',
      'GET https://after.example',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('replaces the empty buffer', function()
    clipboard.paste_curl()
    assert.is_true(vim.wait(100, function()
      return vim.api.nvim_get_current_line() == 'GET https://example.com'
    end))
    assert.are.same({ 'GET https://example.com' }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('leaves the buffer alone when conversion fails', function()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'GET https://original.example' })
    result = { code = 1, stdout = '', stderr = 'invalid curl' }

    clipboard.paste_curl()
    vim.wait(100)

    assert.are.same(
      { 'GET https://original.example' },
      vim.api.nvim_buf_get_lines(0, 0, -1, false)
    )
  end)
end)
