local api = require("pr-tools.api")

local M = {}

function M.setup()
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
            nargs = 0,
        }
    )

    vim.api.nvim_create_user_command(
        "RunPrToolsTest",
        function() api.ignore_this() end,
        {
            nargs = 0,
        }
    )

    vim.api.nvim_create_user_command(
        "CreatePullRequest",
        function() api.create_pull_request() end,
        {
            nargs = 0,
        }
    )
end

return M
