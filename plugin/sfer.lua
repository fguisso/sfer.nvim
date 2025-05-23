require("sfer.ui").set_config({ width = 45 })

local function check_and_open_sarif()
	local cwd = vim.fn.getcwd()
	local sarif_path = vim.fn.glob(cwd .. "/*.sarif")

	if sarif_path == "" then
		return
	end

	local rule_map, total_locations = require("sfer.parser").load(sarif_path)
	local total_rules = vim.tbl_count(rule_map)

	local tree = {}
	for rule_id, info in pairs(rule_map) do
		tree[rule_id] = {
			count = info.count,
			locations = info.locations,
		}
	end

	tree.__header = {
		path = sarif_path,
		rules = total_rules,
		locations = total_locations,
	}

	require("sfer.ui").open_sidebar(tree)
end

vim.api.nvim_create_user_command("SarifSidebar", function()
	check_and_open_sarif()
end, { desc = "Abrir painel lateral se houver .sarif no diretório atual" })

vim.api.nvim_create_autocmd("VimEnter", {
	callback = check_and_open_sarif,
	desc = "Abre sidebar se houver arquivo .sarif no diretório",
})
