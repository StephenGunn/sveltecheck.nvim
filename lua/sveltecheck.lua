local M = {}

local config = {
    command = "pnpm run check", -- Default command
    spinner_frames = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" }, -- Spinner animation frames
}

local spinner_index = 1
local spinner_timer = nil

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
local function run_check_and_populate_quickfix()
    start_spinner()
    local function on_output(_, data, event)
        if event == "stdout" or event == "stderr" then
            local result = table.concat(data, "\n")

            -- Pattern to match file paths with line and character numbers
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

    vim.fn.jobstart(config.command, {
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
end

-- Function to setup the plugin and register commands
function M.setup(user_config)
    if user_config then
        config.command = user_config.command or config.command
    end

    -- Register the SvelteCheck command
    if not vim.fn.exists(":SvelteCheck") then
        vim.cmd("command! -nargs=0 SvelteCheck lua require('plugins.sveltecheck').run_check_and_populate_quickfix()")
    end

    -- Print initialization message
    print("SvelteCheck plugin loaded successfully.")
end

-- Export the module table
return M
