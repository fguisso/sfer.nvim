local api = vim.api
local M = {}

local fold_state = {}

local config = {
	width = 30,
}

function M.set_config(opts)
	config.width = opts.width or config.width
end

local function render_sidebar(tree)
	local lines = {}
	local meta = {}

	-- Cabeçalho
	local header = tree.__header
	if header then
		table.insert(lines, "SARIF file: " .. header.path)
		table.insert(lines, string.format("Found %d rules / %d locations", header.rules, header.locations))
		table.insert(lines, "")
	end

	-- Regras e locais
	for rule, info in pairs(tree) do
		if rule ~= "__header" then
			table.insert(lines, "- " .. rule .. string.format(" (%d)", info.count))
			table.insert(meta, {
				lnum = #lines - 1,
				type = "rule",
				rule = rule,
			})

			if fold_state[rule] then
				for _, loc in ipairs(info.locations) do
					table.insert(lines, "  - " .. loc)
					table.insert(meta, {
						lnum = #lines - 1,
						type = "location",
						rule = rule,
						text = loc,
					})
				end
			end
		end
	end

	return lines, meta
end

function M.open_sidebar(tree)
	local buf = api.nvim_create_buf(false, true)
	vim.cmd("vsplit")
	local win = api.nvim_get_current_win()
	api.nvim_win_set_width(win, config.width)
	api.nvim_win_set_buf(win, buf)

	-- Define opções
	api.nvim_set_option_value("buflisted", false, { buf = buf })
	api.nvim_set_option_value("filetype", "sfer", { buf = buf })
	api.nvim_set_option_value("wrap", true, { win = win })
	api.nvim_set_option_value("number", false, { win = win })
	api.nvim_set_option_value("relativenumber", false, { win = win })
	api.nvim_set_option_value("cursorline", true, { win = win })
	api.nvim_set_option_value("winhighlight", "Normal:SferSidebar", { win = win })

	-- Highlight customizado
	api.nvim_set_hl(0, "SferSidebar", { link = "NormalFloat" })

	-- Renderizar
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

			local lines, new_meta = render_sidebar(tree)
			api.nvim_buf_set_lines(buf, 0, -1, false, lines)
			vim.b[buf].sfer_sidebar_meta = new_meta

			-- mantém o cursor na mesma linha
			api.nvim_win_set_cursor(0, { math.min(cursor_row, #lines), 0 })
		end
	end, { buffer = buf })

	vim.keymap.set("n", "q", function()
		api.nvim_buf_delete(buf, { force = true })
	end, { buffer = buf })
end

return M
