local api = require("pr-tools.api")

local M = {}

function M.setup()
	local pr_opts = require("pr-tools.config").options.pr
	local db_opts = require("pr-tools.config").options.db

	vim.api.nvim_create_user_command(
		"CreateSlackPrLink",
		function() api.create_slack_pr_link(pr_opts.slack_link_emoji) end,
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
		"EditPullRequestDescription",
		function() api.edit_pull_request_description() end,
		{
			nargs = 0
		}
	)

	vim.api.nvim_create_user_command(
		"CreatePullRequest",
		function () api.create_pull_request(pr_opts.open_in_draft) end,
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

	vim.api.nvim_create_user_command(
		"MarkPullRequestAsDraft",
		function () api.mark_pr_as_draft() end,
		{
			nargs = 0
		}
	)

	vim.api.nvim_create_user_command(
        "SwitchPostgresInstance",
        function()
            api.switch_postgres_instance(db_opts.db_instance_dir, db_opts.pg_ctl)
        end,
        {
            nargs = 0,
        }
    )
end

return M
