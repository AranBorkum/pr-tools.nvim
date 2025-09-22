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

return M
