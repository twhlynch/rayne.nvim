local M = {}

local schema_path = vim.fn.stdpath("data") .. "/android-manifest/schema.json"
local cached = nil

--- @class ManifestSource
--- @field type "git" | "web"
--- @field repo? string
--- @field commit? string
--- @field file? string
--- @field line? integer

--- @class ManifestEntry
--- @field name string
--- @field source ManifestSource

--- @class ManifestMetadataEntry : ManifestEntry
--- @field values? string[]
--- @field separator? string

--- @class ManifestSchema
--- @field permissions ManifestEntry[]
--- @field features ManifestEntry[]
--- @field metadata ManifestMetadataEntry[]
--- @field updated_at string|osdate

--- @return ManifestSchema?
function M.load()
	if cached then
		return cached
	end

	if vim.fn.filereadable(schema_path) == 0 then
		return nil
	end

	local ok, data = pcall(vim.json.decode, table.concat(vim.fn.readfile(schema_path), "\n"))
	if not ok or not data then
		return nil
	end

	cached = data
	return cached
end

function M.invalidate()
	cached = nil
end

--- @return ManifestSchema
function M.empty()
	return {
		permissions = {},
		features = {},
		metadata = {},
		updated_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
	}
end

--- @param schema ManifestSchema
function M.save(schema)
	schema.updated_at = os.date("!%Y-%m-%dT%H:%M:%SZ")

	local dir = vim.fn.fnamemodify(schema_path, ":h")
	if vim.fn.isdirectory(dir) == 0 then
		vim.fn.mkdir(dir, "p")
	end
	local f = io.open(schema_path, "w")
	if f then
		f:write(vim.json.encode(schema))
		f:close()
	end

	cached = schema
end

return M
