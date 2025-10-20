local utils = require("pr-tools.utils")
local Path = require("plenary.path")
local popup = require("plenary.popup")

local M = {}

function M.open_pr_in_browser()
	local pr_json =
		vim.fn.system("gh pr view --json title,number,headRepository,headRepositoryOwner,url,additions,deletions")

	local ok, pr = pcall(vim.fn.json_decode, pr_json)
	if not ok or not pr then
		vim.notify("Failed to parse PR info (invalid JSON): " .. (pr_json or ""), vim.log.levels.ERROR)
		return
	end
	local sysname = vim.loop.os_uname().sysname

	if sysname == "Darwin" then
		-- macOS
		vim.fn.jobstart({ "open", pr.url }, { detach = true })
	elseif sysname == "Windows_NT" then
		-- Windows
		vim.fn.jobstart({ "cmd.exe", "/c", "start", pr.url }, { detach = true })
	else
		-- Linux and others
		vim.fn.jobstart({ "xdg-open", pr.url }, { detach = true })
	end
end

function M.create_slack_pr_link(emoji)
	local emoji = utils.emojify(emoji)
	-- Get PR info as JSON
	if vim.fn.executable("gh") ~= 1 then
		vim.notify("GitHub CLI ('gh') not found. Please install it to use this feature.", vim.log.levels.ERROR)
		return
	end
	local pr_json =
		vim.fn.system("gh pr view --json title,number,headRepository,headRepositoryOwner,url,additions,deletions")
	-- Check for command failure (gh outputs errors to stdout if not piped)
	if not pr_json or pr_json == "" or pr_json:match("^gh:") or pr_json:match("^error:") then
		vim.notify("Failed to fetch PR info: " .. (pr_json or "unknown error"), vim.log.levels.ERROR)
		return
	end
	-- Parse JSON using vim.fn.json_decode
	local ok, pr = pcall(vim.fn.json_decode, pr_json)
	if not ok or not pr then
		vim.notify("Failed to parse PR info (invalid JSON): " .. (pr_json or ""), vim.log.levels.ERROR)
		return
	end

	-- Build Markdown, HTML, and title
	local md = string.format("<%s|%s>", pr.url, pr.title)
	local lines = string.format("+%s -%s", pr.additions, pr.deletions)
	local html = string.format('<a href="%s">%s</a>', pr.url, pr.title)

	-- Create HTML content and convert to hex
	local html_content = string.format("%s <code>%s</code> %s", emoji, lines, html)
	local t = {}
	for i = 1, #html_content do
		t[i] = string.format("%02x", html_content:byte(i))
	end
	local html_hex = table.concat(t)

	-- Escape quotes for AppleScript
	local escaped_md = string.format("%s `%s` %s", emoji, lines, md)
	escaped_md = escaped_md:gsub('"', '\\"')

	-- Detect OS
	local sysname = (vim.loop.os_uname and vim.loop.os_uname().sysname) or ""
	sysname = sysname:lower()

	if sysname:find("darwin") then
		utils.copy_link_macos(html_hex, escaped_md)
	elseif sysname:find("linux") then
		utils.copy_link_linux(emoji, md)
	elseif sysname:find("windows") then
		utils.copy_link_windows(emoji, md)
	else
		vim.notify("Unsupported OS for clipboard copy", vim.log.levels.ERROR)
	end
end

function M.create_pull_request(open_in_draft)
	vim.ui.input({ prompt = "PR Title: " }, function(input)
		if not input then
			vim.notify("No input provided", vim.log.levels.INFO)
			return
		elseif #input == 0 then
			vim.notify("Empty input provided", vim.log.levels.INFO)
			return
		end

		vim.notify("Creating pull request: " .. input)

		local cmd = { "gh", "pr", "create", "--title", input, "--body", "" }
		if open_in_draft then
			table.insert(cmd, "--draft")
		end
		utils.spawn_background_task(cmd, "Pull request created", "Error creating pull request")
	end)
end

function M.mark_pr_as_ready()
	vim.notify("Marking pull request as ready")

	local cmd = { "gh", "pr", "ready" }

	utils.spawn_background_task(cmd, "Pull request marked as ready for review", "Error marking pull request as ready")
end

function M.mark_pr_as_draft()
	vim.notify("Marking pull request as draft")

	local cmd = { "gh", "pr", "ready", "--undo" }

	utils.spawn_background_task(cmd, "Pull request marked as draft", "Error marking pull request draft")
end

function M.edit_pull_request_description()
	local lines = {}

	-- 2️⃣ Otherwise try PR template
	local template_path = Path:new(".github/pull_request_template.md")
	if template_path:exists() then
		lines = template_path:readlines()
	else
		-- 3️⃣ Fallback to empty buffer
		lines = {}
		vim.notify("No PR template or temp file found — opening empty buffer", vim.log.levels.INFO)
	end

	-- create a normal, listed buffer
	local bufnr = vim.api.nvim_create_buf(true, false)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

	-- buffer settings
	vim.bo[bufnr].filetype = "markdown"
	vim.bo[bufnr].swapfile = false
	vim.bo[bufnr].bufhidden = "wipe"

	-- give it a real temporary filename so :w and :wq work
	local tmpfile = vim.fn.tempname() .. ".md"
	vim.api.nvim_buf_set_name(bufnr, tmpfile)

	-- open floating window with plenary.popup
	local win_id, _ = popup.create(bufnr, {
		title = "PR Template (tmp)",
		highlight = "Normal",
		minwidth = 100,
		minheight = 40,
		line = math.floor((vim.o.lines - 40) / 2),
		col = math.floor((vim.o.columns - 100) / 2),
		border = true,
	})

	-- Close floating window on BufUnload
	vim.api.nvim_create_autocmd("BufUnload", {
		buffer = bufnr,
		callback = function()
			if vim.api.nvim_win_is_valid(win_id) then
				vim.api.nvim_win_close(win_id, true)
			end
		end,
	})

	-- Run gh pr edit asynchronously only on save
	vim.api.nvim_create_autocmd("BufWritePost", {
		buffer = bufnr,
		callback = function()
			local handle
			local cmd = { "gh", "pr", "edit", "--body-file", tmpfile }
			vim.notify("Updating PR body")
			handle = vim.loop.spawn(cmd[1], { args = { cmd[2], cmd[3], cmd[4], cmd[5] } }, function(code, _)
				vim.schedule(function()
					if code == 0 then
						vim.notify("PR body updated via gh CLI")
					else
						vim.notify("gh pr edit failed (code " .. code .. ")", vim.log.levels.ERROR)
					end
				end)
				handle:close()
			end)
		end,
	})
end

function M.show_pr_check_summary()
	-- Run gh pr checks with JSON output
	local raw = vim.fn.system({ "gh", "pr", "checks", "--json", "state" })

	if vim.v.shell_error ~= 0 then
		vim.notify("Error running gh pr checks", vim.log.levels.ERROR)
		return
	end

	local ok, checks = pcall(vim.fn.json_decode, raw)
	if not ok or not checks then
		vim.notify("Failed to parse gh pr checks output", vim.log.levels.ERROR)
		return
	end

	local passed, failed, running = 0, 0, 0

	for _, check in ipairs(checks) do
		if check.state == "COMPLETED" or check.state == "SUCCESS" then
			passed = passed + 1
		elseif check.state == "FAILED" or check.state == "FAILURE" then
			failed = failed + 1
		elseif check.state == "IN_PROGRESS" or check.state == "QUEUED" or check.state == "PENDING" then
			running = running + 1
		end
	end

	vim.notify(
		string.format("Checks summary:\n✅ Passed: %d\n❌ Failed: %d\n⏳ Running: %d", passed, failed, running),
		vim.log.levels.INFO,
		{ title = "PR Checks" }
	)
end

function M.switch_postgres_instance(db_instance_dir, pg_ctl)
    if db_instance_dir == "" then
        vim.notify(
            "You must define the path to your postgres instances",
            vim.log.levels.ERROR
        )
        return
    end

    local instances, running_instance =
        utils.get_postgres_instances(db_instance_dir, pg_ctl)
    local prompt = "Select postgress instance"
    if running_instance ~= "" then
        prompt = prompt .. " ('" .. running_instance .. "' currently running)"
    end

    local callback = function(selection)
        utils.switch_postgres_instance(selection, db_instance_dir, pg_ctl)
    end

    vim.ui.select(instances, {
        prompt = prompt,
    }, callback)
end

return M
