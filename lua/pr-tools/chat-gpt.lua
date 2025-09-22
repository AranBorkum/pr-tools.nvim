local Job = require("plenary.job")
local Path = require("plenary.path")

local M = {}

function M.pr_prompt()
	local diff = table.concat(vim.fn.systemlist("git diff origin/main...HEAD"), "\n")
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

	local prompt = string.format(
		"Analyze the following diff from some active work. Given the markdown supplied fill out the template summarizing the information in the diff. You need to maintain the formatting of the markdown template and return a consice summary. \n\nThis is the diff from the PR\n%s \n\nThis is the markdown template I want you to strictly adhere to\n%s",
		diff, table.concat(lines, "\n"))
	print(prompt)
end

-- Call OpenAI ChatGPT API
function M.call_chatgpt(prompt, on_success)
	local api_key = os.getenv("OPENAI_API_KEY")
	if not api_key then
		vim.notify("OPENAI_API_KEY not set", vim.log.levels.ERROR)
		return
	end

	local payload = vim.fn.json_encode({
		model = "gpt-3.5-turbo",
		messages = {
			{ role = "user", content = prompt }
		}
	})

	-- Use curl via plenary Job asynchronously
	Job:new({
		command = "curl",
		args = {
			"-s",
			"-X", "POST",
			"https://api.openai.com/v1/chat/completions",
			"-H", "Content-Type: application/json",
			"-H", "Authorization: Bearer " .. api_key,
			"-d", payload
		},
		on_exit = function(j, return_val)
			local result = table.concat(j:result(), "\n")
			local decoded = vim.fn.json_decode(result)
			if decoded and decoded.choices and decoded.choices[1] and decoded.choices[1].message then
				local content = decoded.choices[1].message.content
				vim.schedule(function()
					on_success(content)
				end)
			else
				vim.schedule(function()
					vim.notify("Failed to get response from ChatGPT", vim.log.levels.ERROR)
				end)
			end
		end,
	}):start()
end

return M
