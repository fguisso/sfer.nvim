local M = {}

--- Carrega SARIF e retorna:
--  1. rule_counts: map<ruleId, count>
--  2. results_count: number
function M.load(path)
	local ok, lines = pcall(vim.fn.readfile, path)
	if not ok then
		vim.notify("[sfer] Erro ao ler o arquivo: " .. path, vim.log.levels.ERROR)
		return {}, 0
	end

	local content = table.concat(lines, "\n")
	local success, decoded = pcall(vim.fn.json_decode, content)
	if not success or type(decoded) ~= "table" then
		vim.notify("[sfer] JSON inválido em: " .. path, vim.log.levels.ERROR)
		return {}, 0
	end

	local rules = {}
	local results_count = 0

	for _, run in ipairs(decoded.runs or {}) do
		for _, result in ipairs(run.results or {}) do
			local rule_id = result.ruleId or "<sem regra>"
			rules[rule_id] = rules[rule_id] or { count = 0, locations = {} }

			rules[rule_id].count = rules[rule_id].count + 1

			for _, loc in ipairs(result.locations or {}) do
				local uri = loc.physicalLocation
						and loc.physicalLocation.artifactLocation
						and loc.physicalLocation.artifactLocation.uri
					or "<sem arquivo>"
				local line = loc.physicalLocation
						and loc.physicalLocation.region
						and loc.physicalLocation.region.startLine
					or 0
				table.insert(rules[rule_id].locations, string.format("%s:%d", uri, line))
				results_count = results_count + 1
			end
		end
	end

	return rules, results_count
end

return M
