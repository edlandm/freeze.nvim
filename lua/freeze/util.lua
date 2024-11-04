---perform `f` over visually selected range
---@param f fun(range:visualRange)
---@param _opts visualOpts?
local function visual(f, _opts)
  local opts = _opts or {}

  -- leave visual mode so that '< and '> get set
  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes('<esc>', true, false, true),
    'itx',
    false)

  local selection_type
  local visual_mode = vim.fn.visualmode(1)
  if visual_mode == 'V' then
    selection_type = 'line'
  elseif visual_mode == 'v' then
    selection_type = 'char'
  else
    selection_type = 'block'
  end

  local origin = vim.fn.getcurpos(0)

  local top = vim.api.nvim_buf_get_mark(0, '<')
  local bottom = vim.api.nvim_buf_get_mark(0, '>')
  assert(top[1] > 0, '< mark not set')
  assert(bottom[1] > 0, '> mark not set')

  local range = {
    top = top,
    bottom = bottom,
    selection_type = selection_type,
  }

  f(range)

  if opts.resume_visual then
    vim.cmd('normal gv')
    return
  end

  if opts.jump == 'top' then
    vim.api.nvim_win_set_cursor(0, top)
  elseif opts.jump == 'bottom' then
    vim.api.nvim_win_set_cursor(0, bottom)
  else
    vim.fn.setpos('.', origin)
  end
end

---turn a function into one that works as an operator
---@param callback fun(positions:operatorPositions)
---@param _opts operatorOpts?
local function operator(callback, _opts)
  local opts = _opts or {}

  local cursor = vim.fn.getcurpos()
  _G.op_fn = function ()
    local positions = {
      top = vim.fn.line("'["),
      bottom = vim.fn.line("']"),
      start = vim.fn.line("'["),
      ['end'] = vim.fn.line("']"),
    }

    if cursor[2] == positions.bottom then
      positions['start'] = positions.bottom
      positions['end']   = positions.top
    end

    callback(positions)

    if opts.jump then
      local jump = opts.jump
      if jump == 'start' then
        -- jump to start of line where the motion was initiated
        cursor[2] = positions[jump]
        cursor[3] = vim.fn.indent(cursor[2]) + 1
      elseif jump == 'top' then
        -- jump to start of line at the top of the range
        cursor[2] = positions[jump]
        cursor[3] = vim.fn.indent(cursor[2]) + 1
      elseif jump == 'end' then
        -- jump to the start of the line at the end of the range
        cursor[2] = positions[jump]
        cursor[3] = vim.fn.indent(cursor[2]) + 1
      elseif jump == 'bottom' then
        -- jump to the end of the line at the bottom of the range
        cursor[2] = positions[jump]
        cursor[3] = vim.v.maxcol
      --[[
      elseif jump == 'origin' then
        jump to position where cursor was before the operation
        only necessary if the operatorfunc moved the cursor
      --]]
      end
      vim.api.nvim_win_set_cursor(0, {cursor[2], cursor[3]})
    end
  end

  vim.go.operatorfunc = 'v:lua.op_fn'
  vim.api.nvim_feedkeys("g@", "i", false)
end

---prompt for input then call `callback` on the response
---@param _prompt string | { prompt: string, cancelreturn: string }
---@param callback fun(response: string)
local function prompt(_prompt, callback)
  assert(_prompt, "prompt required")
  assert(callback, "callback required")

  local opts
  if type(_prompt) == 'string' then
    opts = { prompt = _prompt, cancelreturn = '<CANCELRETURN>' }
  else
    opts = _prompt
  end

  local response = vim.fn.input(opts)
  if response == '<CANCELRETURN>' then return end
  callback(response)
end

return {
  visual   = visual,
  operator = operator,
  prompt   = prompt,
}
