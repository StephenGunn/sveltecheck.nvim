local M = {}

local default_config = {
    command = "pnpm run check",
    spinner_frames = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" },
}

local config = vim.deepcopy(default_config)
local spinner_index = 1
local spinner_timer = nil
local error_count = 0
local warning_count = 0
local start_time = 0
local end_time = 0
local total_time = 0
local summary = "No errors or warnings found... nice!"

local function start_spinner()
    local notification_id = vim.notify("Running Svelte Check...", "info", {
        timeout = 0,
        log = false,
    })

    spinner_timer = vim.loop.new_timer()

    spinner_timer:start(
        0, -- initial delay in milliseconds (must be integer)
        100, -- repeat interval in milliseconds (must be integer)
        vim.schedule_wrap(function()
            -- Update the notification message with spinner frames
            vim.notify("Running Svelte Check... " .. config.spinner_frames[spinner_index], "info", {
                id = notification_id, -- Update existing notification
                timeout = 0, -- Display indefinitely until cleared manually
                log = false,
            })

            spinner_index = (spinner_index % #config.spinner_frames) + 1
        end)
    )
end

local function stop_spinner()
    if spinner_timer then
        spinner_timer:stop()
        spinner_timer:close()
        spinner_timer = nil
    end
    vim.o.statusline = ""
    vim.cmd("redrawstatus")
end

M.run = function()
    start_spinner()
    local summary_info = "No summary found"

    local function on_output(_, data, event)
        if event == "stdout" or event == "stderr" then
            local svelte_check_output = table.concat(data, "\n")
            local pattern = "(/[%w%./_%-%+]+:%d+:%d+)"
            local lines = vim.split(svelte_check_output, "\n")
            local quickfix_list = {}

            for _, line in ipairs(lines) do
                start_time = line:match("(%d+) START")
                local timestamp, error_type, file_path, line_number, column_number, description =
                    line:match('(%d+)%s+(%a+)%s+"(.-)" (%d+):(%d+)%s+"(.-)"')
                if timestamp and error_type and file_path and line_number and column_number and description then
                    timestamp = tonumber(timestamp)
                    line_number = tonumber(line_number)
                    column_number = tonumber(column_number)

                    table.insert(quickfix_list, {
                        filename = file_path,
                        lnum = line_number,
                        col = column_number,
                        text = description,
                        type = error_type, -- Assuming error_type is "ERROR" or "WARNING"
                        nr = 0,
                        valid = true,
                    })

                    end_time = line:match("(%d+) COMPLETED")
                end
            end

            -- calculate the total time
            total_time = end_time - start_time

            if #quickfix_list > 0 then
                vim.fn.setqflist({}, "r", { title = config.command .. " output", items = quickfix_list })
                vim.cmd("copen")
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

            if exit_code > 1 then
                vim.notify("Svelte Check failed with exit code " .. exit_code, "error", {
                    log = false,
                })
            end

            print(summary_info)
        end,
    })

    vim.fn.jobwait({ job_id }, 1000)
end

function M.setup(user_config)
    if user_config then
        config = vim.tbl_deep_extend("force", config, user_config)
    end

    vim.api.nvim_create_user_command("SvelteCheck", function()
        M.run()
    end, { desc = "Run `svelte-check` asynchronously and load the results into a qflist", force = true })
end

return M
