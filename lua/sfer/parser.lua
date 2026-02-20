local M = {}

local function uri_to_path(uri)
	if type(uri) ~= "string" or uri == "" then
		return "?"
	end

	if uri:match("^file://") then
		local ok, path = pcall(vim.uri_to_fname, uri)
		if ok and path and path ~= "" then
			return path
		end
	end

	return uri
end

local function build_base_id_map(run)
	local map = {}
	local base_ids = run and run.originalUriBaseIds or {}
	if type(base_ids) ~= "table" then
		return map
	end

	for key, value in pairs(base_ids) do
		if type(value) == "table" and type(value.uri) == "string" then
			map[key] = uri_to_path(value.uri)
		end
	end

	return map
end

local function resolve_artifact_path(artifact, base_id_map, sarif_dir)
	if type(artifact) ~= "table" then
		return "?"
	end

	local uri = uri_to_path(artifact.uri)
	if uri == "?" then
		return "?"
	end

	if uri:match("^/") then
		return uri
	end

	local base = artifact.uriBaseId and base_id_map[artifact.uriBaseId] or nil
	if base and base ~= "" then
		return vim.fn.fnamemodify(base .. "/" .. uri, ":p")
	end

	return vim.fn.fnamemodify(sarif_dir .. "/" .. uri, ":p")
end

function M.load(path)
	local ok, lines = pcall(vim.fn.readfile, path)
	if not ok then
		vim.notify("[sfer] Error on read file: " .. path, vim.log.levels.ERROR)
		return {}
	end

	local content = table.concat(lines, "\n")
	local success, decoded = pcall(vim.fn.json_decode, content)
	if not success or type(decoded) ~= "table" then
		vim.notify("[sfer] Invalid JSON : " .. path, vim.log.levels.ERROR)
		return {}
	end

	local rule_map = {}
	local rule_descriptions = {}
	local sarif_dir = vim.fn.fnamemodify(path, ":p:h")

	for _, run in ipairs(decoded.runs or {}) do
		local rules = run.tool and run.tool.driver and run.tool.driver.rules or {}
		for _, rule in ipairs(rules) do
			rule_descriptions[rule.id] = rule.shortDescription and rule.shortDescription.text or "<no description>"
		end
	end

	for _, run in ipairs(decoded.runs or {}) do
		local base_id_map = build_base_id_map(run)

		for _, result in ipairs(run.results or {}) do
			local rule_id = result.ruleId or "<no_rule>"
			local rule_desc = rule_descriptions[rule_id] or "<no description>"

			if not rule_map[rule_id] then
				rule_map[rule_id] = {
					description = rule_desc,
					results = {},
				}
			end

			local base_location = nil
			if result.locations and result.locations[1] then
				local loc = result.locations[1].physicalLocation
				if loc then
					base_location = {
						file = resolve_artifact_path(loc.artifactLocation, base_id_map, sarif_dir),
						line = loc.region and loc.region.startLine or 0,
					}
				end
			end

			local flow = {}
			local code_flows = result.codeFlows or {}
			for _, cf in ipairs(code_flows) do
				for _, tf in ipairs(cf.threadFlows or {}) do
					for _, step in ipairs(tf.locations or {}) do
						local ploc = step.location and step.location.physicalLocation
						if ploc then
							local region = ploc.region or {}
							local msg = step.location.message and step.location.message.text or ""
							table.insert(flow, {
								file = resolve_artifact_path(ploc.artifactLocation, base_id_map, sarif_dir),
								line = region.startLine or 0,
								start_col = region.startColumn or 1,
								end_col = region.endColumn or region.startColumn or 1,
								text = msg,
								kind = step.kind or "",
							})
						end
					end
				end
			end

			if #flow == 0 and result.locations then
				for _, loc in ipairs(result.locations) do
					local ploc = loc.physicalLocation
					if ploc then
						local region = ploc.region or {}
						local msg = loc.message and loc.message.text or ""
						table.insert(flow, {
							file = resolve_artifact_path(ploc.artifactLocation, base_id_map, sarif_dir),
							line = region.startLine or 0,
							start_col = region.startColumn or 1,
							end_col = region.endColumn or region.startColumn or 1,
							text = msg,
							kind = "location",
						})
					end
				end
			end

			table.insert(rule_map[rule_id].results, {
				message = result.message and result.message.text or "<no message>",
				base_location = base_location,
				flow = flow,
			})
		end
	end

	return rule_map
end

return M
