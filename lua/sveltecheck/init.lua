local M = {}

-- Default configuration
local default_config = {
    command = "pnpm run check",
    spinner_frames = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" },
}

-- Current configuration (initialized with defaults)
local config = vim.deepcopy(default_config)

-- Spinner control variables
local spinner_index = 1

-- Initialize spinner_timer as nil initially
local spinner_timer = nil

-- Function to start the spinner and show a continuous notification
local function start_spinner()
    -- Display initial message or prepare for spinner
    local notification_id = vim.notify("Running Svelte Check...", "info", {
        timeout = 0, -- Display indefinitely until cleared manually
    })

    -- Start the spinner animation asynchronously
    spinner_timer = vim.loop.new_timer()

    -- Start the timer with appropriate parameters
    spinner_timer:start(
        0, -- initial delay in milliseconds (must be integer)
        100, -- repeat interval in milliseconds (must be integer)
        vim.schedule_wrap(function()
            -- Update the notification message with spinner frames
            vim.notify("Running Svelte Check... " .. config.spinner_frames[spinner_index], "info", {
                id = notification_id, -- Update existing notification
                timeout = 0, -- Display indefinitely until cleared manually
            })

            spinner_index = (spinner_index % #config.spinner_frames) + 1
        end)
    )
end

-- Function to stop the spinner and reset the status bar
local function stop_spinner()
    if spinner_timer then
        spinner_timer:stop()
        spinner_timer:close()
        spinner_timer = nil
    end
    vim.o.statusline = ""
    vim.cmd("redrawstatus")
end

-- Function to run the check command and populate the quickfix list
M.run = function()
    start_spinner()

    local function on_output(_, data, event)
        if event == "stdout" or event == "stderr" then
            local result = table.concat(data, "\n")
            local pattern = "(/[%w%./_%-]+:%d+:%d+)"
            local quickfix_list = {}

            -- Iterate over each file path match
            local start_idx = 1
            for filepath in string.gmatch(result, pattern) do
                local end_idx = result:find(filepath, start_idx, true) or #result
                local error_text = result:sub(start_idx, math.min(start_idx + 200, end_idx))
                start_idx = end_idx + 1

                local file, line, col = filepath:match("(.+):(%d+):(%d+)")
                table.insert(quickfix_list, {
                    filename = file,
                    lnum = tonumber(line),
                    col = tonumber(col),
                    text = error_text,
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
        on_stdout = function(_, data)
            on_output(_, data, "stdout")
        end,
        on_stderr = function(_, data)
            on_output(_, data, "stderr")
        end,
        on_exit = function(_, exit_code)
            stop_spinner()
            if exit_code ~= 0 then
                print(config.command .. " command failed with exit code: " .. exit_code)
            end
        end,
    })

    -- Ensure job handles are cleaned up properly
    vim.fn.jobwait({ job_id }, 1000)
end

-- Function to setup the plugin and register commands
function M.setup(user_config)
    -- Merge user-provided config with default config
    if user_config then
        config = vim.tbl_deep_extend("force", config, user_config)
    end

    vim.api.nvim_create_user_command("SvelteCheck", function()
        M.run()
    end, { desc = "Run `svelte-check` asynchronously and load the results into a qflist", force = true })

    -- Print initialization message
    print("SvelteCheck plugin loaded successfully.")
end

-- Export the module table
return M
