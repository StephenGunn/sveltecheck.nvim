-- lua/plugins/svelte_check.lua

-- Ensure we are running inside Neovim's Lua environment
if vim.api == nil then
	error("This script must be run inside Neovim!")
end

-- Debugging: Print a message indicating the script is loaded
print("SvelteCheck plugin loaded successfully.")

-- Configuration settings
local config = {
	command = "pnpm run check",
	spinner_frames = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" },
}

-- Variables for spinner animation
local spinner_index = 1
local spinner_timer = nil

-- Function to start the spinner animation
local function start_spinner()
	spinner_timer = vim.loop.new_timer()
	spinner_timer:start(
		0,
		100,
		vim.schedule_wrap(function()
			vim.o.statusline = "Checking... " .. config.spinner_frames[spinner_index]
			spinner_index = (spinner_index % #config.spinner_frames) + 1
			vim.cmd("redrawstatus")
		end)
	)
	-- Debugging: Print a message indicating spinner has started
	print("Spinner started.")
end

-- Function to stop the spinner animation
local function stop_spinner()
	if spinner_timer then
		spinner_timer:stop()
		spinner_timer:close()
		spinner_timer = nil
		-- Debugging: Print a message indicating spinner has stopped
		print("Spinner stopped.")
	end
	vim.o.statusline = ""
	vim.cmd("redrawstatus")
end

-- Function to run the check and populate the quickfix list
local function run_check_and_populate_quickfix()
	start_spinner()

	local function on_output(_, data, event)
		if event == "stdout" or event == "stderr" then
			local result = table.concat(data, "\n")
			local pattern = "(/[%w%./_%-]+:%d+:%d+)"
			local quickfix_list = {}

			for filepath in string.gmatch(result, pattern) do
				local file, line, col = filepath:match("(.+):(%d+):(%d+)")
				table.insert(quickfix_list, {
					filename = file,
					lnum = tonumber(line),
					col = tonumber(col),
					text = "Error found here",
				})
			end

			if #quickfix_list > 0 then
				vim.fn.setqflist({}, "r", { title = config.command .. " output", items = quickfix_list })
				vim.cmd("copen")
			else
				print("No matches found in the output.")
			end
		end
	end

	local job_id = vim.fn.jobstart(config.command, {
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = on_output,
		on_stderr = on_output,
		on_exit = function(_, exit_code, _)
			stop_spinner()
			if exit_code ~= 0 then
				print(config.command .. " command failed with exit code: " .. exit_code)
			end
		end,
	})

	-- Ensure job handles are cleaned up properly
	vim.fn.jobwait({ job_id }, 1000)
end

-- Define command to trigger the SvelteCheck functionality
vim.cmd("command! SvelteCheck lua require('plugins.svelte_check').run_check_and_populate_quickfix()")

-- Debugging: Print a message indicating command registration
print("SvelteCheck command registered.")

-- Return a function to allow configuration of the plugin
return function(user_config)
	if user_config then
		config.command = user_config.command or config.command
	end
end
