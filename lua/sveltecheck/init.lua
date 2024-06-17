local M = {}

-- Default configuration
local default_config = {
    command = "pnpm run check",
    spinner_frames = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" },
}
local config = vim.deepcopy(default_config)

-- Spinner control variables
local spinner_index = 1
local spinner_timer = nil

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

    -- Variable to store summary information
    local summary_info = ""

    local function on_output(_, data, event)
        if event == "stdout" or event == "stderr" then
            local result = table.concat(data, "\n")

            -- Define the minimum number of '=' characters for delimiters
            local min_delimiter_length = 8

            -- Regular expression to find start and end delimiters
            local start_delimiter_pattern = "={" .. min_delimiter_length .. ",}"
            local end_delimiter_pattern = "={" .. min_delimiter_length .. ",}"

            -- Find start and end positions of the main content section
            local start_pos = result:find(start_delimiter_pattern) or 1
            local end_pos = result:find(end_delimiter_pattern, start_pos + min_delimiter_length) or #result

            -- Extract the main content section
            local main_content = result:sub(start_pos, end_pos)

            -- get the last lines from result
            local last_lines = result:sub(-10)

            print(last_lines)

            -- Regular expression to match file paths with line and column numbers
            local pattern = "(/[%w%./_%-%+]+:%d+:%d+)"

            -- Split the main content section into lines
            local lines = vim.split(main_content, "\n")

            -- Track whether to capture the next line as error/warning message
            local quickfix_list = {}

            for i = 1, #lines do
                local line = lines[i]

                -- Check if line matches the file path pattern
                local filepath = line:match(pattern)

                if filepath then
                    -- Extract file, line, and column from the matched line
                    local file, line_num, col = filepath:match("(.+):(%d+):(%d+)")

                    -- If the next line exists, capture it as the error or warning message
                    if i + 1 <= #lines then
                        local error_text = vim.trim(lines[i + 1])

                        -- Add the error/warning to the quickfix list
                        local entry = {
                            filename = file,
                            lnum = tonumber(line_num),
                            col = tonumber(col),
                            text = error_text,
                        }
                        table.insert(quickfix_list, entry)

                        -- Move to the line after next in the loop
                        i = i + 1
                    end
                end
            end

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
