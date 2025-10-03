local M = {}

M.options = {
	open_in_draft = false,
	slack_link_emoji = "pr"
}

function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", M.options, opts or {})

    require("pr-tools.commands").setup()
end

return M
