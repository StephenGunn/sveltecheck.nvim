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
        local last_line = nil

        -- Process each line
        for _, line in ipairs(lines) do
            if config.debug_mode then
                print("Processing line: " .. line)
            end

            -- Check if the line starts with an epoch timestamp
            local timestamp = line:match("^%d+")

            if timestamp then
                if line:match("COMPLETED") then
                    if config.debug_mode then
                        print("Found COMPLETED line: " .. line)
                    end
                    last_line = line
                end

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

                if error_type and file_path and line_number and column_number and description then
                    line_number = tonumber(line_number)
                    column_number = tonumber(column_number)

                    table.insert(quickfix_list, {
                        filename = file_path,
                        lnum = line_number,
                        col = column_number,
                        text = description,
                        type = error_type,
                        nr = 0,
                        valid = true,
                    })
                else
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

        if last_line then
            -- Flexible pattern to capture the statistics
            local stats_pattern =
            "^%d+%s+COMPLETED%s+(%d+)%s+FILES%s+(%d+)%s+ERRORS%s+(%d+)%s+WARNINGS%s+(%d+)%s+FILES_WITH_PROBLEMS"
            local files, errors, warnings, files_with_problems = last_line:match(stats_pattern)

            if config.debug_mode then
                print("Stats Pattern: " .. stats_pattern)
                print("Files: " .. (files or "nil"))
                print("Errors: " .. (errors or "nil"))
                print("Warnings: " .. (warnings or "nil"))
                print("Files with Problems: " .. (files_with_problems or "nil"))
            end

            if files and errors and warnings and files_with_problems then
                summary_info = "Svelte Check completed with "
                    .. errors
                    .. " errors and "
                    .. warnings
                    .. " warnings in "
                    .. files
                    .. " files."
            else
                -- Handle cases where the line does not match the expected pattern completely
                if config.debug_mode then
                    print("Could not extract all stats from COMPLETED line: " .. last_line)
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
