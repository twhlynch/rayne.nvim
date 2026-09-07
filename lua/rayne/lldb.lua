local utils = require("rayne.utils")

local M = {}

--- @param root_path string
local function find_servers(root_path)
	local sdk_path = vim.fn.expand(root_path)
	local results = utils.find("lldb-server*", { directory = sdk_path, insensitive = true })

	if #results == 0 then
		vim.notify("Could not locate lldb-server under " .. sdk_path, vim.log.levels.ERROR)
		return nil
	end

	return results
end

local cached_lldb_server_path = nil

function M.find_server(root_path)
	if cached_lldb_server_path then
		return cached_lldb_server_path
	end

	local servers = find_servers(root_path)
	if not servers then
		return nil
	end

	-- prefer aarch64 server
	local chosen = nil
	for _, path in ipairs(servers) do
		if path:match("aarch64") then
			chosen = path
			break
		end
	end
	chosen = chosen or servers[1]

	cached_lldb_server_path = chosen
	return chosen
end

--- @class Rayne.attach_opts
--- @field name string
--- @field pid integer
--- @field commands string[]
--- @field program string

--- @param opts Rayne.attach_opts
function M.attach(opts)
	require("dap").run({
		name = opts.name,
		type = "lldb",
		request = "attach",
		pid = opts.pid,
		attachCommands = opts.commands,
		program = opts.program,
	})
end

return M
