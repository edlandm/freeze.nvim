local M = {}

function M.check()
  local opts = require("freeze").opts

  if 1 == vim.fn.executable(opts.executeable) then
    vim.health.ok('Freeze executable found')
  else
    vim.health.error('freeze executeable not found in $PATH',
      'please either add it somewhere in your PATH or specify the full path to the executable in opts.executeable')
  end

  local dir_stat = vim.uv.fs_stat(opts.dir)
  if dir_stat then
    if dir_stat.type == 'directory' then
      vim.health.ok('opts.dir found')
    else
      vim.health.error('opts.dir is not a directory')
    end
  else
    vim.health.error('opts.dir not found',
      'make sure that it exists and is a directory')
  end
end

return M
