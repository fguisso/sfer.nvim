require("sfer.ui").set_config({})

local function check_and_open_sarif()
	local cwd = vim.fn.getcwd()
	local sarif_path = vim.fn.glob(cwd .. "/*.sarif")
	if sarif_path == "" then
		return
	end

	local rule_map = require("sfer.parser").load(sarif_path)

	local total_rules = vim.tbl_count(rule_map)
	rule_map.__header = {
		path = sarif_path,
		rules = total_rules,
	}

	local ok, err = pcall(function()
		require("sfer.ui").open_sidebar(rule_map)
	end)

	if not ok then
		vim.notify("[sfer] Error open the sfer sidebar:\n" .. err, vim.log.levels.ERROR)
	end
end

vim.api.nvim_create_user_command("SarifSidebar", function()
	check_and_open_sarif()
end, { desc = "Open sidebar if has .sarif in the actual directory" })

vim.api.nvim_create_autocmd("VimEnter", {
	callback = check_and_open_sarif,
	desc = "Open sidebar if has .sarif in the actual directory",
})
