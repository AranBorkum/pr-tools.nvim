local M = {}

M.options = {
	pr = {
		open_in_draft = false,
		slack_link_emoji = "pr",
	},
	db = {
		db_instance_dir = "",
		pg_ctl = "pg_ctl",
	},
}

function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", M.options, opts or {})

	require("pr-tools.commands").setup()
end

return M
