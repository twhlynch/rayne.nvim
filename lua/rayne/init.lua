local M = {}

--- plugin setup
--- @param opts Rayne.Options option overrides
function M.setup(opts)
	local options = require("rayne.options")
	options.set(opts)
end

return M
