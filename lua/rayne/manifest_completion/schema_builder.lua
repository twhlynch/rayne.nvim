local schema_mod = require("rayne.manifest_completion.schema")

local M = {}

local schema_path = vim.fn.stdpath("data") .. "/android-manifest/build-config-schema.json"

--- generate a JSON schema for build-config.json with permission/feature/metadata enums
--- @return table|nil
function M.generate()
	local s = schema_mod.load()
	if not s then
		return nil
	end

	-- collect all names for the bare string enum
	local all_names = {}
	local seen = {}
	local function add_name(name)
		if not seen[name] then
			seen[name] = true
			all_names[#all_names + 1] = name
		end
	end
	for _, e in ipairs(s.permissions or {}) do
		add_name(e.name)
	end
	for _, e in ipairs(s.features or {}) do
		add_name(e.name)
	end

	-- json schema
	local schema = {
		["$schema"] = "http://json-schema.org/draft-07/schema#",
		["$id"] = "https://github.com/uberpixel/Rayne",
		title = "Rayne Build Configuration",
		description = "Build configuration for Rayne projects",
		type = "object",
		properties = {
			-- TODO: could add the rest of the properties
		},
		additionalProperties = true,
		definitions = {
			permission_entry = {},
		},
	}

	-- build permission_entry schema
	local permission_entry = {
		description = "A permission, feature, metadata, or query entry",
		anyOf = {},
	}

	-- bare permission or feature name string
	if #all_names > 0 then
		permission_entry.anyOf[#permission_entry.anyOf + 1] = {
			type = "string",
			enum = all_names,
			description = 'Permission or feature name (shorthand for {type: "permission", name: ...})',
		}
	end

	-- all known names for the "name" field in objects
	local all_known_names = {}
	local seen_names = {}
	local function add_known(name)
		if not seen_names[name] then
			seen_names[name] = true
			all_known_names[#all_known_names + 1] = name
		end
	end
	for _, e in ipairs(s.permissions or {}) do
		add_known(e.name)
	end
	for _, e in ipairs(s.features or {}) do
		add_known(e.name)
	end
	for _, e in ipairs(s.metadata or {}) do
		add_known(e.name)
	end

	-- object with type field
	local name_field = { type = "string", description = "Permission, feature, metadata, or package name" }
	if #all_known_names > 0 then
		name_field.enum = all_known_names
	end

	local permission_obj = {
		type = "object",
		properties = {
			type = {
				type = "string",
				enum = { "permission", "feature", "metadata", "query" },
				description = "Entry type",
			},
			name = name_field,
			required = { type = "boolean", description = "Whether this is required" },
			value = { type = "string", description = "Metadata value (for type: metadata)" },
			platforms = {
				type = "array",
				items = { type = "string" },
				description = "Limit to specific platforms",
			},
			["maxSdkVersion"] = {
				type = "integer",
				description = "Maximum SDK version (for type: permission)",
			},
		},
		additionalProperties = false,
	}

	permission_entry.anyOf[#permission_entry.anyOf + 1] = permission_obj

	schema.definitions.permission_entry = permission_entry

	-- add permissions~android pattern property
	schema.properties["permissions~android"] = {
		type = "array",
		items = { ["$ref"] = "#/definitions/permission_entry" },
		description = "Android permissions, features, metadata, and queries",
	}

	return schema
end

--- write the JSON schema to disk and return the path
--- @return string|nil path
function M.write()
	local schema = M.generate()
	if not schema then
		return nil
	end

	local dir = vim.fn.fnamemodify(schema_path, ":h")
	if vim.fn.isdirectory(dir) == 0 then
		vim.fn.mkdir(dir, "p")
	end

	local f = io.open(schema_path, "w")
	if f then
		f:write(vim.json.encode(schema))
		f:close()
	end

	return schema_path
end

--- @return string
function M.get_path()
	return schema_path
end

return M
