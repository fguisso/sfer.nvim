local api = vim.api
local M = {}

local fold_state = {}
local result_fold_state = {}
local main_win = nil

local config = {
	width = 45,
}

function M.set_config(opts)
	config.width = opts.width or config.width
end

local function render_sidebar(tree)
	local lines = {}
	local meta = {}

	local header = tree.__header or {}
	table.insert(lines, "SARIF file: " .. (header.path or "<unknown>"))
	table.insert(meta, { type = "header" })

	table.insert(lines, string.format("Found %d rules", header.rules or 0))
	table.insert(meta, { type = "header" })

	table.insert(lines, "")
	table.insert(meta, { type = "spacer" })

	for rule_id, rule_info in pairs(tree) do
		if rule_id ~= "__header" then
			local is_open = fold_state[rule_id]
			local icon = is_open and "" or ""
			local description = rule_info.description or "<no description>"
			local result_count = rule_info.results and #rule_info.results or 0

			table.insert(lines, string.format("%s %s (%d)", icon, rule_id, result_count))
			table.insert(meta, {
				lnum = #lines - 1,
				type = "rule",
				rule = rule_id,
			})

			if is_open then
				table.insert(lines, "  • " .. description)
				table.insert(meta, { type = "rule_description", rule = rule_id })

				for _, result in ipairs(rule_info.results or {}) do
					local file = result.base_location and result.base_location.file or "?"
					local filename = file:match("([^/\\]+)$") or file
					local msg = result.message or ""
					local key = rule_id .. "::" .. file
					local is_result_open = result_fold_state[key]
					local step_count = result.flow and #result.flow or 0
					local result_icon = is_result_open and "▼" or "▶"

					table.insert(lines, string.format("  %s %s (%d)", result_icon, filename, step_count))
					table.insert(meta, {
						lnum = #lines - 1,
						type = "result_file",
						rule = rule_id,
						file = file,
						key = key,
					})

					if is_result_open then
						table.insert(lines, "  • " .. msg)
						table.insert(meta, {
							lnum = #lines - 1,
							type = "result_msg",
							rule = rule_id,
							file = file,
						})

						for _, step in ipairs(result.flow or {}) do
							local full_path = step.file or "?"
							local r_filename = full_path:match("([^/\\]+)$") or full_path
							local line = step.line or "?"
							local desc = step.text or ""
							table.insert(lines, string.format("    • %s:%s - %s", r_filename, line, desc))
							table.insert(meta, {
								lnum = #lines - 1,
								type = "flow",
								rule = rule_id,
								file = full_path,
								line = step.line,
								kind = step.kind,
								text = desc,
								start_col = step.start_col,
								end_col = step.end_col,
							})
						end
					end
				end
			end
		end
	end

	for i, line in ipairs(lines) do
		lines[i] = line:gsub("\n", " ")
	end

	return lines, meta
end

function M.open_sidebar(tree)
	main_win = api.nvim_get_current_win()

	local buf = api.nvim_create_buf(false, true)
	vim.cmd("vsplit")
	local win = api.nvim_get_current_win()
	api.nvim_win_set_width(win, config.width)
	api.nvim_win_set_buf(win, buf)

	if buf and api.nvim_buf_is_valid(buf) then
		api.nvim_set_option_value("buflisted", false, { buf = buf })
		api.nvim_set_option_value("filetype", "sfer", { buf = buf })
	end

	if win and api.nvim_win_is_valid(win) then
		api.nvim_set_option_value("number", false, { win = win })
		api.nvim_set_option_value("relativenumber", false, { win = win })
		api.nvim_set_option_value("cursorline", true, { win = win })
	end

	local lines, meta = render_sidebar(tree)
	api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.b[buf].sfer_sidebar_meta = meta

	M.attach_mappings(buf, tree)
end

function M.attach_mappings(buf, tree)
	vim.keymap.set("n", "l", function()
		local cursor_row = api.nvim_win_get_cursor(0)[1]
		local meta = vim.b[buf].sfer_sidebar_meta or {}
		local item = meta[cursor_row]
		if not item then
			return
		end

		if item.type == "rule" and item.rule then
			fold_state[item.rule] = not fold_state[item.rule]
		elseif item.type == "result_file" and item.key then
			result_fold_state[item.key] = not result_fold_state[item.key]
		elseif item.type == "flow" and item.file and item.line then
			if main_win and api.nvim_win_is_valid(main_win) then
				local filepath = vim.fn.fnamemodify(item.file, ":p")

				local group = api.nvim_create_augroup("SferJumpOnce", { clear = true })
				api.nvim_create_autocmd("BufEnter", {
					group = group,
					pattern = filepath,
					once = true,
					callback = function()
						api.nvim_set_current_win(main_win)
						local total_lines = api.nvim_buf_line_count(0)
						local line = math.max(1, math.min(item.line, total_lines))
						api.nvim_win_set_cursor(main_win, { line, 0 })

						if item.start_col and item.end_col then
							api.nvim_buf_add_highlight(
								0,
								-1,
								"IncSearch",
								line - 1,
								item.start_col - 1,
								item.end_col - 1
							)
						end
					end,
				})

				api.nvim_win_call(main_win, function()
					vim.cmd("edit " .. filepath)
				end)
			else
				vim.notify("[sfer] Principal window not found", vim.log.levels.ERROR)
			end
			return
		end

		local lines, new_meta = render_sidebar(tree)
		api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		vim.b[buf].sfer_sidebar_meta = new_meta
		api.nvim_win_set_cursor(0, { math.min(cursor_row, #lines), 0 })
	end, { buffer = buf })

	vim.keymap.set("n", "q", function()
		api.nvim_buf_delete(buf, { force = true })
	end, { buffer = buf })
end

return M
