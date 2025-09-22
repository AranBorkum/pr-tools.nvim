local utils = require("pr-tools.utils")

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

return M
