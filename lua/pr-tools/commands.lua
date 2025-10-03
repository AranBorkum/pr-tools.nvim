local api = require("pr-tools.api")

local M = {}

function M.setup()
	local opts = require("pr-tools.config").options

	vim.api.nvim_create_user_command(
		"CreateSlackPrLink",
		function() api.create_slack_pr_link() end,
		{
			nargs = 0,
		}
	)

	vim.api.nvim_create_user_command(
		"OpenPrInBrowser",
		function() api.open_pr_in_browser() end,
		{
			nargs = 0
		}
	)

	vim.api.nvim_create_user_command(
		"RunPrToolsTest",
		function() api.ignore_this() end,
		{
			nargs = 0
		}
	)

	vim.api.nvim_create_user_command(
		"CreatePullRequest",
		function () api.create_pull_request(opts.open_in_draft) end,
		{
			nargs = 0
		}
	)

	vim.api.nvim_create_user_command(
		"PullRequestCheckSummary",
		function () api.show_pr_check_summary() end,
		{
			nargs = 0
		}
	)

	vim.api.nvim_create_user_command(
		"MarkPullRequestAsReady",
		function () api.mark_pr_as_ready() end,
		{
			nargs = 0
		}
	)

end

return M
