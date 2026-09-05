local M = {}

--- @class Rayne.Options plugin options
local options = {
	engine_path = vim.fn.getcwd() .. "/../../Rayne",
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
