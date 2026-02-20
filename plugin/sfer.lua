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

local function find_sarif_path()
	local cwd = vim.fn.getcwd()
	local matches = vim.fn.globpath(cwd, "*.sarif", false, true)
	if type(matches) ~= "table" then
		return nil
	end
	if #matches == 0 then
		return nil
	end

	table.sort(matches)
	return matches[1]
end

local function load_rule_map(sarif_path)
	local rule_map = require("sfer.parser").load(sarif_path)
	local total_rules = vim.tbl_count(rule_map)
	rule_map.__header = {
		path = sarif_path,
		rules = total_rules,
	}

	return rule_map
end

local function check_and_open_sarif(opts)
	opts = opts or {}
	local is_auto = opts.auto == true

	if is_auto and should_skip_on_startup() then
		return
	end

	local sarif_path = find_sarif_path()
	if not sarif_path then
		return
	end

	local rule_map = load_rule_map(sarif_path)

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

vim.api.nvim_create_user_command("SarifQuickfix", function()
	local sarif_path = find_sarif_path()
	if not sarif_path then
		vim.notify("[sfer] No .sarif file found in current directory", vim.log.levels.WARN)
		return
	end

	local rule_map = load_rule_map(sarif_path)
	require("sfer.ui").to_quickfix(rule_map)
end, { desc = "Send SARIF findings to quickfix" })

vim.api.nvim_create_autocmd("VimEnter", {
	callback = function()
		check_and_open_sarif({ auto = true })
	end,
	desc = "Open sidebar if has .sarif in the actual directory",
})
