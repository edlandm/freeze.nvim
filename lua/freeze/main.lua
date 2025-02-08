local mod_name = "freeze"

---@diagnostic disable
package.loaded[mod_name] = {}
local M = package.loaded[mod_name]

local util = require('freeze.util')

---@type Freeze.opts
M.default_opts = {
  -- style gallery: https://xyproto.github.io/splash/docs/index.html
  theme_light = 'catppuccin-latte',
  theme_dark = 'catppuccin-frappe',
  default_theme = 'dark',
  dir = '.',
  executeable = 'freeze',
  filename = '{timestamp}-{filename}-{start_line}-{end_line}.png',
  never_prompt = false,
  default_callback = function(target)
    -- copy/yank target filepath to unnamed (default) register
    vim.fn.setreg('', target)
  end,
  log_level = vim.log.levels.INFO,
}

local log = vim.schedule_wrap(function(message, log_level)
  if log_level < M.opts.log_level then
    return
  end
  vim.notify(vim.inspect(message), log_level, { title = 'Freeze' })
end)

---take screenshots using dark theme
function M:set_theme_dark()
  M.theme = self.opts.theme_dark
  vim.notify('Freeze: Dark Mode', vim.log.levels.INFO, { title = 'Freeze' })
end

---take screenshots using light theme
function M:set_theme_light()
  M.theme = self.opts.theme_light
  vim.notify('Freeze: Light Mode', vim.log.levels.INFO, { title = 'Freeze' })
end

---toggle theme from dark/light
function M:toggle_theme()
  if self.theme == self.opts.theme_dark then
    self:set_theme_light()
  else
    self:set_theme_dark()
  end
end

---take screenshot of the given buffer[+range] using `freeze` command
---@param opts freeze.opts
function M:freeze(opts)
  log({ fn = 'freeze()', _opts = opts }, vim.log.levels.DEBUG)
  local _opts = opts or {}
  local top, bottom
  if _opts.range then
    top = _opts.range.top - 1
    bottom = _opts.range.bottom
  else
    top = 0
    bottom = vim.api.nvim_buf_line_count(0)
  end

  local target = _opts.target
  if not target then
    assert(self.opts.dir, 'opts.dir must be defined')
    assert(self.opts.filename, 'opts.filename must be defined')
    target = self.opts.dir .. '/' .. self.opts.filename
  end

  local timestamp = os.date("%Y.%m.%d-%H.%M.%S")
  local filename = vim.fn.fnamemodify(vim.fn.expand('%'), ':t')

  if filename == nil or filename == '' then
    filename = 'SCRATCH'
  end

  target = target:gsub("{timestamp}", timestamp)
  target = target:gsub("{filename}", filename)
  target = target:gsub("{start_line}", top)
  target = target:gsub("{end_line}", bottom)

  local buf = vim.api.nvim_get_current_buf()
  local language = vim.api.nvim_get_option_value("filetype", { buf = buf })
  if language == '' then
    language = 'text'
  end


  local args = { "--output", target }

  if language then
    table.insert(args, '--language')
    table.insert(args, language)
  end

  if M.theme then
    table.insert(args, '--theme')
    table.insert(args, M.theme)
  end

  local uv = vim.uv
  local stdin = uv.new_pipe()
  local stdout = uv.new_pipe()
  local stderr = uv.new_pipe()

  local handle, _ = uv.spawn(M.opts.executeable,
    { args = args, stdio = { stdin, stdout, stderr } },
    function(code, signal)
      if code > 0 then
        log(
          {
            message = 'freeze exited unexpectedly',
            code = code,
            signal = signal,
          },
          vim.log.levels.ERROR)
        return
      end

      log('Froze: ' .. target, vim.log.levels.INFO)

      local callback = _opts.callback or M.opts.default_callback
      if callback then
        vim.schedule(function()
          callback(target)
        end)
      end
    end)

  if not handle then
    vim.notify("Failed to spawn freeze",
      vim.log.levels.ERROR,
      { title = "Freeze" })
  end

  vim.cmd('echohl Constant | echo "Freezing..." | echohl None')

  if stdout then
    uv.read_start(stdout, function(err, data)
      assert(not err, err)
      if data then
        print(data)
      end
    end)
  end

  if stderr then
    uv.read_start(stderr, function(err, data)
      assert(not err, err)
      if data then
        print(data)
      end
    end)
  end

  local lines = vim.api.nvim_buf_get_lines(buf, top, bottom, true)
  uv.write(stdin, table.concat(lines, '\n'))

  uv.shutdown(stdin, function(err)
    if err and handle then
      uv.close(handle)
    end
  end)
end

---prompt for target filepath to save screenshot, then call `freeze()`.
---if an empty response is given, default to `<opts.dir>/<opts.filename>`
---@param opts freeze.opts.prompt
function M:freeze_prompt(opts)
  log({ fn = 'freeze_prompt()', _opts = opts }, vim.log.levels.DEBUG)
  local _opts = vim.tbl_deep_extend('keep', { target = nil }, opts or {})
  util.prompt('Freeze to: ', function(input)
    if input == '' then
      return self:freeze(_opts)
    end

    local target
    if input:match('^%./') then
      target = input
    elseif input:match('^/') then
      target = input
    elseif input:match('^~') then
      target = vim.fn.expand(input)
    else
      target = vim.fs.joinpath(self.opts.dir, input)
    end

    local ext = vim.fn.fnamemodify(target, ':e')
    if ext == '' then
      target = target .. '.png'
    end

    _opts.target = target
    self:freeze(_opts)
  end)
end

---freeze the visual selection, then call `freeze_prompt()`
---(or `freeze()` if opts.never_prompt == true)
---@param opts freeze.opts.visual
function M:freeze_visual(opts)
  log({ fn = 'freeze_visual()', _opts = opts }, vim.log.levels.DEBUG)
  local _opts = opts or {}
  util.visual(function(_range)
    local range = { top = _range.top[1], bottom = _range.bottom[1] }
    if M.opts.never_prompt then
      self:freeze(vim.tbl_deep_extend('keep', { range = range }, _opts))
    else
      self:freeze_prompt(vim.tbl_deep_extend('keep', { range = range }, _opts))
    end
  end, { jump = 'origin' })
end

---freeze the lines in <motion>, then call `freeze_prompt()`
---(or `freeze()` if opts.never_prompt == true)
---@param opts freeze.opts.operator
function M:freeze_operator(opts)
  log({ fn = 'freeze_operator()', _opts = opts }, vim.log.levels.DEBUG)
  local _opts = opts or {}
  util.operator(function(positions)
    local range = { top = positions.top, bottom = positions.bottom }
    if M.opts.never_prompt then
      self:freeze(vim.tbl_deep_extend('keep', { range = range }, _opts))
    else
      self:freeze_prompt(vim.tbl_deep_extend('keep', { range = range }, _opts))
    end
  end, { jump = 'origin' })
end

local commands = {
  ['Freeze'] = {
    opts = {
      desc = 'Take a screenshot using `freeze` of <range>|buffer and save to <arg1>|<default>',
      range = true,
    },
    fn = function(cmd_opts)
      local freeze_opts = {}
      if cmd_opts.range > 0 then
        freeze_opts.range = {
          top = cmd_opts.line1,
          bottom = cmd_opts.line2 or cmd_opts.line1,
        }
      end

      if #(cmd_opts.fargs) > 0 and cmd_opts.fargs[1] ~= '' then
        freeze_opts.target = cmd_opts.fargs[1]
      end

      if freeze_opts.target or M.opts.never_prompt then
        M:freeze(freeze_opts)
      else
        M:freeze_prompt(freeze_opts)
      end
    end
  },
  ['FreezeSetDark'] = {
    opts = { desc = 'Set Freeze theme to Dark' },
    fn = function() M:set_theme_dark() end
  },
  ['FreezeSetLight'] = {
    opts = { desc = 'Set Freeze theme to Light' },
    fn = function() M:set_theme_light() end
  },
  ['FreezeToggleTheme'] = {
    opts = { desc = 'Toggle Freeze theme between Light and Dark' },
    fn = function() M:toggle_theme() end
  },
}

---initialize the plugin and create user commands
---@param opts Freeze.opts
function M.setup(opts)
  local _opts = vim.tbl_deep_extend('keep', opts or {}, M.default_opts)
  M.theme = _opts.default_theme == 'dark' and _opts.theme_dark or _opts.theme_light
  M.opts = _opts

  for name, cmd in pairs(commands) do
    vim.api.nvim_create_user_command(name, cmd.fn, cmd.opts)
  end
end

---@type Freeze
return M
