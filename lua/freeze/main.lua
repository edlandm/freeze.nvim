local mod_name = "freeze"
local M

package.loaded[mod_name] = {}
M = package.loaded[mod_name]

local api = vim.api
local util = require('freeze.util')

local default_opts = {
  -- style gallery: https://xyproto.github.io/splash/docs/index.html
  theme_light = 'catppuccin-latte',
  theme_dark = 'catppuccin-frappe',
  default_theme = 'dark',
  dir = '.',
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
local function set_theme_dark()
  M.theme = M.opts.theme_dark
  vim.notify('Freeze: Dark Mode', vim.log.levels.INFO, { title = 'Freeze' })
end

---take screenshots using light theme
local function set_theme_light()
  M.theme = M.opts.theme_light
  vim.notify('Freeze: Light Mode', vim.log.levels.INFO, { title = 'Freeze' })
end

---toggle theme from dark/light
local function toggle_theme()
  if M.opts.theme == M.opts.theme_dark then
    set_theme_light()
  else
    set_theme_dark()
  end
end

---@alias freezeRange {top:integer, bottom:integer}

---take screenshot of the given buffer[+range] using `freeze` command
---@param _opts {range?:freezeRange, target?:string, callback?: fun(target: string) }?
local function freeze(_opts)
  log({ fn = 'freeze()', _opts = _opts }, vim.log.levels.DEBUG)
  local opts = _opts or {}
  local top, bottom
  if opts.range then
    top = opts.range.top - 1
    bottom = opts.range.bottom
  else
    top = 0
    bottom = vim.api.nvim_buf_line_count(0)
  end

  local target = opts.target
  if not target then
    assert(M.opts.dir, 'opts.dir must be defined')
    assert(M.opts.filename, 'opts.filename must be defined')
    target = M.opts.dir .. '/' .. M.opts.filename
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

  local buf = api.nvim_get_current_buf()
  local language = api.nvim_get_option_value("filetype", { buf = buf })

  local args = {
      "--output", target,
  }

  if language then
    table.insert(args, '--language')
    table.insert(args, language)
  end

  if M.opts.theme then
    table.insert(args, '--theme')
    table.insert(args, M.opts.theme)
  end

  local uv = vim.uv
  local stdin = uv.new_pipe()
  local stdout = uv.new_pipe()
  local stderr = uv.new_pipe()

  local handle, _ = uv.spawn('freeze',
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

      local callback = opts.callback or M.opts.default_callback
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

  local lines = api.nvim_buf_get_lines(buf, top, bottom, true)
  uv.write(stdin, table.concat(lines, '\n'))

  uv.shutdown(stdin, function(err)
    if err and handle then
      uv.close(handle)
    end
  end)
end

---prompt for target filepath to save screenshot, then call `freeze()`.
---if an empty response is given, default to `<opts.dir>/<opts.filename>`
---@param _opts { range?:freezeRange, callback?: fun(target: string) }?
local function freeze_prompt(_opts)
  log({ fn = 'freeze_prompt()', _opts = _opts }, vim.log.levels.DEBUG)
  local opts = vim.tbl_deep_extend('keep', { target = nil }, _opts or {})
  util.prompt('Freeze to: ', function(target)
    if target == '' then
      return freeze(opts)
    end

    local dir = M.opts.dir
    local filename = M.opts.filename

    if target:find('/') then
      dir = vim.fn.fnamemodify(target, ':p:h')
    end

    if vim.fn.fnamemodify(target, ':e') ~= '' then
      filename = vim.fn.fnamemodify(target, ':t')
    end

    assert(dir, 'dir not expected to be nil')
    assert(filename, 'filename not expected to be nil')

    opts.target = dir .. '/' .. filename

    freeze(opts)
  end)
end

---freeze the visual selection, then call `freeze_prompt()`
---(or `freeze()` if opts.never_prompt == true)
---@param _opts { callback?: fun(target: string) }?
local function freeze_visual(_opts)
  log({ fn = 'freeze_visual()', _opts = _opts }, vim.log.levels.DEBUG)
  local opts = _opts or {}
  util.visual(function(_range)
    local range = { top = _range.top[1], bottom = _range.bottom[1] }
    if M.opts.never_prompt then
      freeze(vim.tbl_deep_extend('keep', { range = range }, opts))
    else
      freeze_prompt(vim.tbl_deep_extend('keep', { range = range }, opts))
    end
  end, { jump = 'origin' })
end

---freeze the lines in <motion>, then call `freeze_prompt()`
---(or `freeze()` if opts.never_prompt == true)
---@param _opts { callback?: fun(target: string) }?
local function freeze_operator(_opts)
  log({ fn = 'freeze_operator()', _opts = _opts }, vim.log.levels.DEBUG)
  local opts = _opts or {}
  util.operator(function(positions)
    local range = { top = positions.top, bottom = positions.bottom }
    if M.opts.never_prompt then
      freeze(vim.tbl_deep_extend('keep', { range = range }, opts))
    else
      freeze_prompt(vim.tbl_deep_extend('keep', { range = range }, opts))
    end
  end, { jump = 'origin' })
end

local function setup(context)
  local opts = context.opts or default_opts
  if opts.default_theme == 'dark' then
    opts.theme = opts.theme_dark
  else
    opts.theme = opts.theme_light
  end

  M.opts = vim.tbl_deep_extend('keep', opts, default_opts)

  api.nvim_create_user_command('FreezeSetDark', set_theme_dark, {})
  api.nvim_create_user_command('FreezeSetLight',set_theme_light, {})

  vim.api.nvim_create_user_command("Freeze", function(_opts)
    local freeze_opts = {}
    if _opts.range > 0 then
      freeze_opts.range = {
        top = _opts.line1,
        bottom = _opts.line2 or _opts.line1,
      }
    end

    if #(_opts.fargs) > 0 and _opts.fargs[1] ~= '' then
      freeze_opts.target = _opts.fargs[1]
    end

    if freeze_opts.target or opts.never_prompt then
      freeze(freeze_opts)
    else
      freeze_prompt(freeze_opts)
    end
  end, {
      desc = 'Take a screenshot using `freeze` of <range>|buffer and save to <arg1>|<default>',
      range = true,
    })
end

M.set_theme_dark = set_theme_dark
M.set_theme_light = set_theme_light
M.toggle_theme = toggle_theme
M.freeze = freeze
M.freeze_prompt = freeze_prompt
M.freeze_visual = freeze_visual
M.freeze_operator = freeze_operator
M.setup = setup

return M
