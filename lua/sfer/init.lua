local M = {}

local defaults = {
	sidebar = {
		width = 45,
	},
}

local function normalize(opts)
	opts = opts or {}
	local sidebar = opts.sidebar or {}

	return {
		sidebar = {
			width = sidebar.width or defaults.sidebar.width,
		},
	}
end

function M.setup(opts)
	local config = normalize(opts)
	require("sfer.ui").set_config({
		width = config.sidebar.width,
	})
end

return M
