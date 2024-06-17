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

local function start_spinner()
    print("Running Svelte Check... ")
    spinner_timer = vim.loop.new_timer(_)
    spinner_timer:start(
        0,
        100,
        vim.schedule_wrap(function()
            print("Running Svelte Check... " .. config.spinner_frames[spinner_index])
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
        if event == "stdout" or event == "stderr" then
            local svelte_check_output = table.concat(data, "\n")
            local lines = vim.split(svelte_check_output, "\n")

            if config.debug_mode then
                print("Output: " .. svelte_check_output)
                print("Event: " .. event)
                print("Lines: " .. #lines)
            end

            local quickfix_list = {}
            local files, errors, warnings, files_with_problems

            for _, line in ipairs(lines) do
                if config.debug_mode then
                    print(line)
                end

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

                    files, errors, warnings, files_with_problems = line:match(
                        "COMPLETED%s+([^%s]+)%s+FILES%s+([^%s]+)%s+ERRORS%s+([^%s]+)%s+WARNINGS%s+([^%s]+)%s+FILES_WITH_PROBLEMS"
                    )
                end
            end

            if #quickfix_list > 0 then
                vim.fn.setqflist({}, "r", { title = config.command .. " output", items = quickfix_list })
                vim.cmd("copen")
            end

            if files and errors and warnings and files_with_problems then
                summary_info = string.format(
                    "Svelte Check completed with %s errors and %s warnings in %s files with problems",
                    errors,
                    warnings,
                    files_with_problems
                )
            end
        end
    end

    local final_command = config.command .. " --output machine"

    local job_id = vim.fn.jobstart(final_command, {
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
