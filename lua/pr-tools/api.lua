local utils = require("pr-tools.utils")
local chatgpt = require("pr-tools.chat-gpt")
local Path = require("plenary.path")
local popup = require("plenary.popup")

local M = {}

function M.open_pr_in_browser()
	local pr_json = vim.fn.system(
		"gh pr view --json title,number,headRepository,headRepositoryOwner,url,additions,deletions"
	)

	local ok, pr = pcall(vim.fn.json_decode, pr_json)
	if not ok or not pr then
		vim.notify(
			"Failed to parse PR info (invalid JSON): " .. (pr_json or ""),
			vim.log.levels.ERROR
		)
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

function M.create_slack_pr_link()
	local emoji = ":pr-outline:"

	-- Get PR info as JSON
	if vim.fn.executable("gh") ~= 1 then
		vim.notify(
			"GitHub CLI ('gh') not found. Please install it to use this feature.",
			vim.log.levels.ERROR
		)
		return
	end
	local pr_json = vim.fn.system(
		"gh pr view --json title,number,headRepository,headRepositoryOwner,url,additions,deletions"
	)
	-- Check for command failure (gh outputs errors to stdout if not piped)
	if
		not pr_json
		or pr_json == ""
		or pr_json:match("^gh:")
		or pr_json:match("^error:")
	then
		vim.notify(
			"Failed to fetch PR info: " .. (pr_json or "unknown error"),
			vim.log.levels.ERROR
		)
		return
	end
	-- Parse JSON using vim.fn.json_decode
	local ok, pr = pcall(vim.fn.json_decode, pr_json)
	if not ok or not pr then
		vim.notify(
			"Failed to parse PR info (invalid JSON): " .. (pr_json or ""),
			vim.log.levels.ERROR
		)
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

function M.fill_pr_template()
	-- 1️⃣ Load template
	local template_lines = {}
	local template_path = Path:new(".github/pull_request_template.md")
	if template_path:exists() then
		template_lines = template_path:readlines()
	else
		vim.notify("No PR template found, starting empty", vim.log.levels.INFO)
	end

	-- 2️⃣ Get diff
	local diff = table.concat(vim.fn.systemlist("git diff origin/main...HEAD"), "\n")

	-- 3️⃣ Construct prompt
	local prompt = table.concat(template_lines, "\n") ..
		"\n\nFill out the PR template based on the following diff:\n" ..
		diff

	-- 4️⃣ Call ChatGPT
	chatgpt.call_chatgpt(prompt, function(response)
		-- Open floating buffer with filled template
		local bufnr = vim.api.nvim_create_buf(true, false)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(response, "\n"))
		vim.bo[bufnr].filetype = "markdown"
		vim.bo[bufnr].swapfile = false
		vim.bo[bufnr].bufhidden = "wipe"

		popup.create(bufnr, {
			title = "Auto-filled PR Template",
			highlight = "Normal",
			line = math.floor((vim.o.lines - 20) / 2),
			col = math.floor((vim.o.columns - 80) / 2),
			minwidth = 80,
			minheight = 20,
			border = true,
		})
	end)
end

function M.ignore_this()
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
		line = math.floor((vim.o.lines - 20) / 2),
		col = math.floor((vim.o.columns - 80) / 2),
		minwidth = 80,
		minheight = 20,
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
			handle = vim.loop.spawn(cmd[1], { args = { cmd[2], cmd[3], cmd[4], cmd[5] } },
				function(code, _)
					vim.schedule(function()
						if code == 0 then
							vim.notify("PR body updated via gh CLI")
						else
							vim.notify("gh pr edit failed (code " .. code .. ")", vim.log.levels.ERROR)
						end
					end)
					handle:close()
				end
			)
		end,
	})
end

return M
