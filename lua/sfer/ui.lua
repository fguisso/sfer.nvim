local api = vim.api
local M = {}

local fold_state = {}
local alert_fold_state = {}
local main_win = nil
local highlight_ns = api.nvim_create_namespace("sfer_sidebar")
local quickfix_target_ns = api.nvim_create_namespace("sfer_quickfix_target")
local highlights_initialized = false
local quickfix_autocmds_initialized = false
local last_quickfix_target_buf = nil

local config = {
	width = 45,
}

function M.set_config(opts)
	config.width = opts.width or config.width
end

local function ensure_highlights()
	if highlights_initialized then
		return
	end

	api.nvim_set_hl(0, "SferRuleDescription", { default = true, link = "Comment" })
	api.nvim_set_hl(0, "SferAlertMessage", { default = true, link = "DiagnosticInfo" })
	api.nvim_set_hl(0, "SferAlertCount", { default = true, link = "DiagnosticWarn" })
	api.nvim_set_hl(0, "SferPathCount", { default = true, link = "DiagnosticHint" })
	api.nvim_set_hl(0, "SferHeaderTitle", { default = true, link = "Title" })
	api.nvim_set_hl(0, "SferHeaderMeta", { default = true, link = "Identifier" })
	api.nvim_set_hl(0, "SferHeaderPath", { default = true, link = "Directory" })
	api.nvim_set_hl(0, "SferHeaderHint", { default = true, link = "Comment" })
	api.nvim_set_hl(0, "SferHeaderDivider", { default = true, link = "WinSeparator" })
	api.nvim_set_hl(0, "SferQuickfixTarget", { default = true, link = "IncSearch" })
	highlights_initialized = true
end

local function apply_sidebar_highlights(buf, lines, meta)
	api.nvim_buf_clear_namespace(buf, highlight_ns, 0, -1)

	for i, item in ipairs(meta or {}) do
		local line = lines[i] or ""
		local lnum = i - 1

		if item.type == "rule_description" then
			api.nvim_buf_add_highlight(buf, highlight_ns, "SferRuleDescription", lnum, 4, -1)
		elseif item.type == "alert" then
			api.nvim_buf_add_highlight(buf, highlight_ns, "SferAlertMessage", lnum, 4, -1)
		elseif item.type == "header_title" then
			api.nvim_buf_add_highlight(buf, highlight_ns, "SferHeaderTitle", lnum, 0, -1)
		elseif item.type == "header_meta" then
			api.nvim_buf_add_highlight(buf, highlight_ns, "SferHeaderMeta", lnum, 0, -1)
		elseif item.type == "header_path" then
			api.nvim_buf_add_highlight(buf, highlight_ns, "SferHeaderPath", lnum, 0, -1)
		elseif item.type == "header_hint" then
			api.nvim_buf_add_highlight(buf, highlight_ns, "SferHeaderHint", lnum, 0, -1)
		elseif item.type == "header_divider" then
			api.nvim_buf_add_highlight(buf, highlight_ns, "SferHeaderDivider", lnum, 0, -1)
		elseif item.type == "rule_divider" then
			api.nvim_buf_add_highlight(buf, highlight_ns, "SferHeaderDivider", lnum, 0, -1)
		elseif item.type == "rule" then
			local s = line:find(" ", 1, true)
			if s then
				api.nvim_buf_add_highlight(buf, highlight_ns, "SferAlertCount", lnum, s - 1, -1)
			end
		elseif item.type == "alert_header" then
			local s = line:find("󰑪 ", 1, true)
			if s then
				api.nvim_buf_add_highlight(buf, highlight_ns, "SferPathCount", lnum, s - 1, -1)
			end
		end
	end
end

local function clear_quickfix_target_highlight()
	if last_quickfix_target_buf and api.nvim_buf_is_valid(last_quickfix_target_buf) then
		api.nvim_buf_clear_namespace(last_quickfix_target_buf, quickfix_target_ns, 0, -1)
	end
	last_quickfix_target_buf = nil
end

local function apply_quickfix_target_highlight()
	local qf = vim.fn.getqflist({ idx = 0, items = 1, title = 1 })
	if not (qf.title or ""):match("^SFER") then
		clear_quickfix_target_highlight()
		return
	end

	local item = (qf.items or {})[qf.idx or 0]
	if not item then
		clear_quickfix_target_highlight()
		return
	end

	local bufnr = tonumber(item.bufnr) or 0
	if bufnr <= 0 and item.filename and item.filename ~= "" then
		bufnr = vim.fn.bufnr(item.filename, true)
	end
	if bufnr <= 0 or not api.nvim_buf_is_valid(bufnr) then
		clear_quickfix_target_highlight()
		return
	end

	clear_quickfix_target_highlight()
	last_quickfix_target_buf = bufnr

	local lnum = math.max(1, tonumber(item.lnum) or 1)
	local col = math.max(1, tonumber(item.col) or 1)
	local end_col = tonumber(item.end_col) or col
	local start_col0 = col - 1
	local end_col0 = end_col > col and end_col - 1 or -1
	api.nvim_buf_add_highlight(bufnr, quickfix_target_ns, "SferQuickfixTarget", lnum - 1, start_col0, end_col0)
end

local function ensure_quickfix_target_tracking()
	if quickfix_autocmds_initialized then
		return
	end

	local group = api.nvim_create_augroup("SferQuickfixTarget", { clear = true })
	api.nvim_create_autocmd({ "QuickFixCmdPost", "CursorMoved", "BufEnter" }, {
		group = group,
		callback = function()
			vim.schedule(apply_quickfix_target_highlight)
		end,
	})
	api.nvim_create_autocmd("BufWipeout", {
		group = group,
		callback = function(args)
			if args.buf == last_quickfix_target_buf then
				last_quickfix_target_buf = nil
			end
		end,
	})

	quickfix_autocmds_initialized = true
end

local function push_quickfix_item(items, rule_id, file, line, col, end_col, text)
	if not file or file == "?" or file == "" then
		return
	end

	table.insert(items, {
		filename = vim.fn.fnamemodify(file, ":p"),
		lnum = math.max(1, tonumber(line) or 1),
		col = math.max(1, tonumber(col) or 1),
		end_col = math.max(1, tonumber(end_col) or tonumber(col) or 1),
		text = string.format("[%s] %s", rule_id, text or ""),
	})
end

local function matches_file_filter(result, file_filter)
	if not file_filter then
		return true
	end

	if result.base_location and result.base_location.file == file_filter then
		return true
	end

	for _, step in ipairs(result.flow or {}) do
		if step.file == file_filter then
			return true
		end
	end

	return false
end

local function add_result_to_quickfix(items, rule_id, result)
	local flow = result.flow or {}
	if #flow > 0 then
		for _, step in ipairs(flow) do
			push_quickfix_item(items, rule_id, step.file, step.line, step.start_col, step.end_col, step.text or result.message)
		end
		return
	end

	local base = result.base_location or {}
	push_quickfix_item(items, rule_id, base.file, base.line, 1, 1, result.message)
end

function M.to_quickfix(tree, item)
	local items = {}

	if item and (item.type == "alert" or item.type == "alert_header") and item.rule and item.result_index then
		local rule_info = tree[item.rule]
		local result = rule_info and rule_info.results and rule_info.results[item.result_index] or nil
		if result then
			add_result_to_quickfix(items, item.rule, result)
		end
	else
		for rule_id, rule_info in pairs(tree) do
			if rule_id ~= "__header" then
				if not item or not item.rule or item.rule == rule_id then
					for _, result in ipairs(rule_info.results or {}) do
						if matches_file_filter(result, item and item.file or nil) then
							add_result_to_quickfix(items, rule_id, result)
						end
					end
				end
			end
		end
	end

	if #items == 0 then
		vim.notify("[sfer] No results to send to quickfix", vim.log.levels.WARN)
		return
	end

	local title = "SFER"
	if item and item.rule then
		title = title .. " [" .. item.rule .. "]"
	end
	if item and item.file then
		title = title .. " " .. vim.fn.fnamemodify(item.file, ":t")
	end

	vim.fn.setqflist({}, " ", { title = title, items = items })

	if main_win and api.nvim_win_is_valid(main_win) then
		api.nvim_set_current_win(main_win)
	end

	pcall(vim.cmd, "cfirst")
	pcall(vim.cmd, "botright copen")
	apply_quickfix_target_highlight()
	vim.notify(string.format("[sfer] Sent %d entries to quickfix", #items), vim.log.levels.INFO)
end

local function render_sidebar(tree)
	local lines = {}
	local meta = {}

	local header = tree.__header or {}
	local header_path = header.path or "<unknown>"
	local header_file = vim.fn.fnamemodify(header_path, ":t")
	local total_rules = header.rules or 0
	local total_alerts = 0
	for rule_id, rule_info in pairs(tree) do
		if rule_id ~= "__header" then
			total_alerts = total_alerts + #(rule_info.results or {})
		end
	end

	table.insert(lines, "╭─ 󰆍 sfer.nvim")
	table.insert(meta, { type = "header_title" })
	table.insert(lines, string.format("│ 󰈙 File: %s", header_file))
	table.insert(meta, { type = "header_meta" })
	table.insert(lines, string.format("│ 󰉋 Path: %s", header_path))
	table.insert(meta, { type = "header_path" })
	table.insert(lines, string.format("│ 󱉶 Rules: %d     Alerts: %d", total_rules, total_alerts))
	table.insert(meta, { type = "header_meta" })
	table.insert(lines, "├─ 󰌑 Controls: l toggle  c quickfix  q close")
	table.insert(meta, { type = "header_hint" })
	table.insert(lines, "╰────────────────────────────────")
	table.insert(meta, { type = "header_divider" })
	table.insert(lines, "")
	table.insert(meta, { type = "spacer" })

	local rule_ids = {}
	for rule_id, _ in pairs(tree) do
		if rule_id ~= "__header" then
			table.insert(rule_ids, rule_id)
		end
	end
	table.sort(rule_ids)

	for rule_idx, rule_id in ipairs(rule_ids) do
		local rule_info = tree[rule_id]
		if rule_id ~= "__header" then
			local is_open = fold_state[rule_id]
			local icon = is_open and "" or ""
			local description = rule_info.description or "<no description>"
			local result_count = rule_info.results and #rule_info.results or 0

			table.insert(lines, string.format("%s %s  %d", icon, rule_id, result_count))
			table.insert(meta, {
				lnum = #lines - 1,
				type = "rule",
				rule = rule_id,
			})

			if is_open then
				table.insert(lines, "  │ " .. description)
				table.insert(meta, { type = "rule_description", rule = rule_id })

				for idx, result in ipairs(rule_info.results or {}) do
					local file = result.base_location and result.base_location.file or "?"
					local filename = file:match("([^/\\]+)$") or file
					local msg = result.message or ""
					local step_count = result.flow and #result.flow or 0
					local line = result.base_location and result.base_location.line or "?"
					local short_msg = msg:gsub("\n", " ")
					local alert_key = string.format("%s::%d", rule_id, idx)
					local alert_is_open = alert_fold_state[alert_key] == true
					local alert_icon = alert_is_open and "▼" or "▶"
					local branch = idx == #(rule_info.results or {}) and "╰" or "├"

					table.insert(lines, string.format("  %s─ %s %s:%s 󰑪 %d", branch, alert_icon, filename, line, step_count))
					table.insert(meta, {
						lnum = #lines - 1,
						type = "alert_header",
						rule = rule_id,
						file = file,
						result_index = idx,
						alert_key = alert_key,
					})

					if alert_is_open then
						local msg_prefix = branch == "╰" and "    " or "  │ "
						table.insert(lines, string.format("%s %s", msg_prefix, short_msg))
						table.insert(meta, {
							lnum = #lines - 1,
							type = "alert",
							rule = rule_id,
							file = file,
							result_index = idx,
							alert_key = alert_key,
						})
					end
				end
			end

			if rule_idx < #rule_ids then
				table.insert(lines, "────────────────────────────────")
				table.insert(meta, { type = "rule_divider" })
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
	ensure_highlights()
	ensure_quickfix_target_tracking()

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
		api.nvim_set_option_value("winfixwidth", true, { win = win })
		api.nvim_set_option_value("wrap", true, { win = win })
		api.nvim_set_option_value("linebreak", true, { win = win })
	end

	local lines, meta = render_sidebar(tree)
	api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.b[buf].sfer_sidebar_meta = meta
	apply_sidebar_highlights(buf, lines, meta)

	M.attach_mappings(buf, tree)

	if main_win and api.nvim_win_is_valid(main_win) then
		api.nvim_set_current_win(main_win)
	end
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
		elseif (item.type == "alert" or item.type == "alert_header") and item.alert_key then
			alert_fold_state[item.alert_key] = not alert_fold_state[item.alert_key]
		end

		local lines, new_meta = render_sidebar(tree)
		api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		vim.b[buf].sfer_sidebar_meta = new_meta
		apply_sidebar_highlights(buf, lines, new_meta)
		api.nvim_win_set_cursor(0, { math.min(cursor_row, #lines), 0 })
	end, { buffer = buf })

	vim.keymap.set("n", "q", function()
		api.nvim_buf_delete(buf, { force = true })
	end, { buffer = buf })

	vim.keymap.set("n", "c", function()
		local cursor_row = api.nvim_win_get_cursor(0)[1]
		local meta = vim.b[buf].sfer_sidebar_meta or {}
		local item = meta[cursor_row]
		M.to_quickfix(tree, item)
	end, { buffer = buf })
end

return M
