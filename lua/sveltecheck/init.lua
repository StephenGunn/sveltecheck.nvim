local M = {}

local default_config = {
    command = "pnpm run check",
    use_telescope = true, -- New configuration option
    spinner_frames = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" },
    debug_mode = false,
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

local function make_quickfix_list(lines)
    local quickfix_list = {}
    local last_line = nil

    -- Process each line
    for _, line in ipairs(lines) do
        -- Check if the line starts with an epoch timestamp
        local timestamp = line:match("^%d+")

        if timestamp then
            if line:match("COMPLETED") then
                last_line = line
            end

            local error_type, file_path, line_number, column_number, description =
                line:match('^%d+%s+(%a+)%s+"(.-)"%s+(%d+):(%d+)%s+"(.-)"')

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
            end
        end
    end

    if last_line then
        -- Flexible pattern to capture the statistics
        local stats_pattern =
        "^%d+%s+COMPLETED%s+(%d+)%s+FILES%s+(%d+)%s+ERRORS%s+(%d+)%s+WARNINGS%s+(%d+)%s+FILES_WITH_PROBLEMS"
        local files, errors, warnings, files_with_problems = last_line:match(stats_pattern)

        if files and errors and warnings and files_with_problems then
            summary_info = "Svelte Check completed with "
                .. errors
                .. " errors and "
                .. warnings
                .. " warnings in "
                .. files
                .. " files."
        end
    end

    return quickfix_list
end

local function on_output(_, data, event)
    local svelte_check_output = table.concat(data, "\n")
    local lines = vim.split(svelte_check_output, "\n")

    if config.debug_mode then
        print("Output: " .. svelte_check_output)
        print("Event: " .. event)
        print("Lines: " .. #lines)
    end

    local quickfix_list = make_quickfix_list(lines)

    if config.use_telescope then
        if not pcall(require, "telescope") then
            error("Telescope.nvim not found. Please install it before using this feature.")
        end

        local telescope = require("telescope")
        local pickers = require("telescope.pickers")
        local finders = require("telescope.finders")
        local actions = require("telescope.actions")
        local previewers = require("telescope.previewers")
        local entry_display = require("telescope.pickers.entry_display")

        local results = {}
        for _, item in ipairs(quickfix_list) do
            table.insert(results, {
                filename = item.filename,
                lnum = item.lnum,
                col = item.col,
                text = item.text,
                display = entry_display.create({
                    separator = " ▏",
                    items = {
                        { width = 50 },
                        { width = 10 },
                        { remaining = true },
                    },
                }),
            })
        end

        pickers
            .new({}, {
                prompt_title = "Svelte Check Results",
                finder = finders.new_table({
                    results = results,
                    entry_maker = function(entry)
                        return {
                            valid = true,
                            value = entry,
                            ordinal = entry.filename .. ":" .. entry.lnum .. ":" .. entry.col .. " " .. entry.text,
                            display = entry.display,
                        }
                    end,
                }),
                sorter = require("telescope.config").values.generic_sorter({}),
                attach_mappings = function(prompt_bufnr, map)
                    actions.select_default:replace(function()
                        local selection = actions.get_selected_entry()
                        actions.close(prompt_bufnr)
                        vim.cmd(string.format("%d%s", selection.value.lnum, "G"))
                        vim.cmd("norm zz")
                    end)
                    return true
                end,
            })
            :find()
    else
        if #quickfix_list > 0 then
            vim.fn.setqflist({}, "r", { title = "Svelte Check", items = quickfix_list })
            vim.cmd("copen")
        end
    end
end

M.run = function()
    start_spinner()

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

    if config.use_telescope then
        vim.api.nvim_create_command("SvelteCheckTelescope", function()
            M.run()
        end, { nargs = 0, desc = "Run `svelte-check` asynchronously and load the results into Telescope" })
    end
end

return M
