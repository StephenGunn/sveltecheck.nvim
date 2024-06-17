local M = {}

local default_config = {
    command = "pnpm run check",
    spinner_frames = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" },
    debug_mode = true,
}

local config = vim.deepcopy(default_config)
local spinner_index = 1
local spinner_timer = nil
local summary_info = "No errors or warnings found... nice!"

local silent_print = function(msg)
    vim.api.nvim_echo({ { msg, "Normal" } }, false, {})
end

local function start_spinner()
    silent_print("Running Svelte Check... ")
    spinner_timer = vim.loop.new_timer()
    spinner_timer:start(
        0,
        100,
        vim.schedule_wrap(function()
            silent_print("Running Svelte Check... " .. config.spinner_frames[spinner_index])
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

    local function on_output(_, data, event)
        local svelte_check_output = table.concat(data, "\n")
        local lines = vim.split(svelte_check_output, "\n")

        if config.debug_mode then
            print("Output: " .. svelte_check_output)
            print("Event: " .. event)
            print("Lines: " .. #lines)
        end

        local quickfix_list = {}

        -- Process each line
        for _, line in ipairs(lines) do
            if config.debug_mode then
                print("Processing line: " .. line)
            end

            -- Check if the line starts with an epoch timestamp
            local timestamp = line:match("^%d+")

            if timestamp then
                -- Extract details from lines starting with an epoch
                local error_type, file_path, line_number, column_number, description =
                    line:match('^%d+%s+(%a+)%s+"(.-)"%s+(%d+):(%d+)%s+"(.-)"')

                -- Debugging information
                if config.debug_mode then
                    print("Timestamp: " .. timestamp)
                    print("Error Type: " .. (error_type or "nil"))
                    print("File Path: " .. (file_path or "nil"))
                    print("Line Number: " .. (line_number or "nil"))
                    print("Column Number: " .. (column_number or "nil"))
                    print("Description: " .. (description or "nil"))
                end

                -- Ensure that all captured components are valid
                if error_type and file_path and line_number and column_number and description then
                    -- Convert the numbers from strings to actual numbers
                    line_number = tonumber(line_number)
                    column_number = tonumber(column_number)

                    -- Insert the details into the quickfix list
                    table.insert(quickfix_list, {
                        filename = file_path,
                        lnum = line_number,
                        col = column_number,
                        text = description,
                        type = error_type:sub(1, 1), -- "E" for ERROR, "W" for WARNING, assuming type is "ERROR" or "WARNING"
                        nr = 0,
                        valid = true,
                    })
                else
                    -- Handle the case where not all components could be matched
                    if config.debug_mode then
                        print("Incomplete match for line: " .. line)
                    end
                end
            else
                -- Optionally handle non-epoch lines
                if config.debug_mode then
                    print("Skipped non-epoch line: " .. line)
                end
            end
        end

        -- If there are items to add to the quickfix list, update and open it
        if #quickfix_list > 0 then
            vim.fn.setqflist({}, "r", { title = config.command .. " output", items = quickfix_list })
            vim.cmd("copen")
        end
    end

    local final_command = config.command .. " --output machine"

    local job_id = vim.fn.jobstart(final_command, {
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout = function(_, data)
            on_output(_, data, "stdout")
        end,
        on_exit = function(_, exit_code)
            stop_spinner()

            print(summary_info)

            if exit_code > 1 then
                print("Svelte Check failed with exit code " .. exit_code)
            end
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
