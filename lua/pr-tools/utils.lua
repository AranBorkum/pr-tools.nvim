local M = {}

function M.copy_link_macos(html_hex, escaped_md)
    local cmd = "osascript"
    local args = {
        "-e",
        string.format(
            'set the clipboard to {«class HTML»:«data HTML%s», string:"%s"}',
            html_hex,
            escaped_md
        ),
    }
    vim.loop.spawn(cmd, { args = args }, function(code)
        if code ~= 0 then
            vim.notify("Failed to copy HTML to clipboard", vim.log.levels.ERROR)
        else
            vim.print("PR link copied to clipboard")
        end
    end)
end

function M.copy_link_linux(emoji, md)
    local clipboard_text = emoji .. " " .. md
    if vim.fn.executable("xclip") == 1 then
        vim.system(
            { "xclip", "-selection", "clipboard" },
            { stdin = clipboard_text },
            function(obj)
                if obj.code == 0 then
                    vim.print("PR link copied to clipboard (plain text)")
                else
                    vim.notify(
                        "Failed to copy PR link to clipboard",
                        vim.log.levels.ERROR
                    )
                end
            end
        )
    elseif vim.fn.executable("xsel") == 1 then
        vim.system(
            { "xsel", "--clipboard", "--input" },
            { stdin = clipboard_text },
            function(obj)
                if obj.code == 0 then
                    vim.print("PR link copied to clipboard (plain text)")
                else
                    vim.notify(
                        "Failed to copy PR link to clipboard",
                        vim.log.levels.ERROR
                    )
                end
            end
        )
    else
        vim.notify("No clipboard utility found (xclip/xsel)", vim.log.levels.ERROR)
    end
end

function M.copy_link_windows(emoji, md)
    if vim.fn.executable("powershell") == 1 then
        vim.system({
            "powershell",
            "-NoLogo",
            "-NoProfile",
            "-Command",
            "Set-Clipboard -Value ([Console]::In.ReadToEnd())",
        }, { stdin = emoji .. " " .. md }, function(obj)
            if obj.code == 0 then
                vim.print("PR link copied to clipboard (plain text)")
            else
                vim.notify("Failed to copy PR link to clipboard", vim.log.levels.ERROR)
            end
        end)
    else
        vim.notify("Clipboard utility 'powershell' not found", vim.log.levels.ERROR)
    end
end

function M.open_single_line_floating_text_entry(prompt, width, height)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(buf, "buftype", "prompt")
    vim.fn.prompt_setprompt(buf, prompt)

    -- Get editor dimensions
    local window_width = width or 40
    local window_height = height or 1
    local editor_width = vim.o.columns
    local editor_height = vim.o.lines

    -- Calculate centered position
    local row = math.floor((editor_height - window_height) / 2)
    local col = math.floor((editor_width - window_width) / 2)

    -- Open floating window in the center
    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = window_width,
        height = window_height,
        row = row,
        col = col,
        style = "minimal",
        border = "single",
    })

    -- Start in insert mode
    vim.api.nvim_command("startinsert")

    -- Handle input on <CR>
    vim.fn.prompt_setcallback(buf, function(text)
        print("You typed: " .. text)
        vim.api.nvim_win_close(win, true)
    end)
end

function M.git_root()
    local handle = io.popen("git rev-parse --show-toplevel 2> /dev/null")
    if handle then
        local result = handle:read("*a")
        handle:close()
        result = result:gsub("%s+$", "")
        return result ~= "" and result or nil
    end
    return nil
end

-- Read a file into a table of lines
function M.read_file_lines(path)
    local lines = {}
    local f = io.open(path, "r")
    if not f then
        return nil
    end
    for line in f:lines() do
        table.insert(lines, line)
    end
    f:close()
    return lines
end

return M
