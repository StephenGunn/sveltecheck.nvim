-- main module file
local module = require("svelte_check.module")

---@class Config
---@field opt string Your config option
local config = {
	command = "pnpm run check", -- Default command to run
	spinner_frames = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" }, -- Spinner frames for animation
}

---@class MyModule
local M = {}

---@type Config
M.config = config

---@param args Config?
-- you can define your setup function here. Usually configurations can be merged, accepting outside params and
-- you can also put some validation here for those.
M.setup = function(args)
	M.config = vim.tbl_deep_extend("force", M.config, args or {})
end

M.hello = function()
	return module.my_first_function(M.config.opt)
end

return M
