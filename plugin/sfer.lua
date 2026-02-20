require("sfer.ui").set_config({})

local function started_with_directory_arg()
	if vim.fn.argc(-1) == 0 then
		return false
	end

	for _, arg in ipairs(vim.fn.argv()) do
		local path = vim.fn.fnamemodify(arg, ":p")
		if vim.fn.isdirectory(path) == 1 then
			return true
		end
	end

	return false
end

local function should_skip_on_startup()
	return not started_with_directory_arg()
end

local function check_and_open_sarif(opts)
	opts = opts or {}
	local is_auto = opts.auto == true

	if is_auto and should_skip_on_startup() then
		return
	end

	local cwd = vim.fn.getcwd()
	local matches = vim.fn.globpath(cwd, "*.sarif", false, true)
	if type(matches) ~= "table" or #matches == 0 then
		return
	end
	table.sort(matches)
	local sarif_path = matches[1]

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
	check_and_open_sarif({ auto = false })
end, { desc = "Open sidebar if has .sarif in the actual directory" })

vim.api.nvim_create_autocmd("VimEnter", {
	callback = function()
		check_and_open_sarif({ auto = true })
	end,
	desc = "Open sidebar if has .sarif in the actual directory",
})
