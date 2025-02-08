---@meta

---@class Freeze
---@field opts Freeze.opts user configuration
---@field default_opts Freeze.opts default configuration
---@field theme freeze.theme.value current theme (dark or light) to use for screenshots
---@field set_theme_dark fun(self:Freeze) method to set freeze.theme to dark
---@field set_theme_light fun(self:Freeze) method to set freeze.theme to light
---@field toggle_theme fun(self:Freeze) method to toggle freeze.theme between light and dark
---@field freeze fun(self:Freeze, opts?:freeze.opts) the main function that calls the freeze executeable to create the screenshot
---@field freeze_prompt fun(self:Freeze, opts?:freeze.opts.prompt) prompt for target filepath to save screenshot, then call `self:freeze()`
---@field freeze_visual fun(self:Freeze, opts?:freeze.opts.visual) freeze the visual selection, then call `freeze_prompt()`
---@field freeze_operator fun(self:Freeze, opts?:freeze.opts.operator) freeze the lines in <motion>, then call `freeze_prompt()`
---@field setup fun(opts:Freeze.opts) initialize the plugin and create user commands

---@class Freeze.opts
---@field theme_light string theme to use if freeze.theme is set to 'light'
---@field theme_dark string theme to use if freeze.theme is set to 'light'
---@field default_theme freeze.theme.value starting value for freeze.theme
---@field dir path directory into which screenshots will be saved
---@field executeable path path to freeze executeable (only necessary to set if freeze is not in your PATH)
---@field filename format_str string denoting the naming schema for scheenshot files
---@field never_prompt boolean if true, visual and operator functions will always use dir and filename to create screenshots
---@field default_callback fun(target:path) function to call after screenshot is created (function is passed the absolute path to the file)
---@field log_level integer one of vim.log.levels

---@class freeze.opts
---@field range? freezeRange
---@field target? string
---@field callback? fun(target:path)

---@class freeze.opts.prompt
---@field range? freezeRange
---@field callback? fun(target:path)

---@class freeze.opts.visual
---@field callback? fun(target:path)

---@class freeze.opts.operator
---@field callback? fun(target:path)

---@alias jumpDest 'start' | 'end' | 'top' | 'bottom' | 'origin'
---@alias operatorOpts { jump:jumpDest? }
---@alias operatorPositions { top:integer, bottom:integer, start:integer, end:integer }
---@alias visualOpts { jump:'top'|'bottom'|'origin'?, resume_visual:boolean? }
---@alias position [integer, integer]
---@alias selectionType 'char' | 'line' | 'block
---@alias visualRange { top:position, bottom:position, selection_type:selectionType }
---@alias freezeRange {top:integer, bottom:integer}


---@alias freeze.theme.value 'light' | 'dark'
---@alias path string
---@alias format_str string

