local M = {}

--- @class Rayne.Options plugin options
local options = {
	engine_path = vim.fn.getcwd() .. "/../../Rayne",
	library_pattern = "^libRayne",
	--- @type string | nil
	lldb_server_path = nil,
	snippets = true,
	android = {
		sdk_path = "~/Library/Android/sdk",
		forward_port = 5039,
		lldb_path = "/data/local/tmp/lldb-server",
	},
}

--- sets plugin options keeping defaults where unspecified
--- @param opts? Rayne.Options option overrides
function M.set(opts)
	options = vim.tbl_deep_extend("force", options, opts or {})
end

--- get current options
--- @return Rayne.Options
function M.get()
	return options
end

return M
