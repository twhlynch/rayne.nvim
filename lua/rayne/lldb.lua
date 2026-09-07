local options = require("rayne.options")
local utils = require("rayne.utils")

local M = {}

local cached_lldb_server_path = nil

--- @param root_path string
--- @return string|nil
function M.find_server(root_path)
	if cached_lldb_server_path then
		return cached_lldb_server_path
	end

	-- manually set custom path
	local lldb_server = options.get().lldb_server_path
	if lldb_server and vim.fn.executable(lldb_server) == 1 then
		cached_lldb_server_path = lldb_server
		return lldb_server
	end

	-- try to find lldb-server next to lldb
	local lldb_bin = vim.fn.exepath("lldb")
	if lldb_bin ~= "" then
		local lldb_dir = vim.fn.fnamemodify(lldb_bin, ":h")
		local candidate = lldb_dir .. "/lldb-server"
		if vim.fn.executable(candidate) == 1 then
			cached_lldb_server_path = candidate
			return candidate
		end
	end

	-- fall back to SDK
	local sdk_path = vim.fn.expand(root_path)
	local results = utils.find("lldb-server*", { directory = sdk_path, insensitive = true })

	if #results == 0 then
		vim.notify("Could not locate lldb-server under " .. sdk_path, vim.log.levels.ERROR)
		return nil
	end

	-- prefer aarch64 server
	for _, path in ipairs(results) do
		if path:match("aarch64") then
			cached_lldb_server_path = path
			return path
		end
	end

	cached_lldb_server_path = results[1]
	return results[1]
end

--- @class Rayne.attach_opts
--- @field name string
--- @field pid integer
--- @field port number
--- @field program string

--- @param opts Rayne.attach_opts
function M.attach_android(opts)
	require("dap").run({
		name = opts.name,
		type = "lldb",
		request = "attach",
		initCommands = {
			"platform select remote-android",
			"platform connect connect://localhost:" .. opts.port,
		},
		attachCommands = {
			"process attach --pid " .. opts.pid,
			"target symbols add " .. vim.fn.shellescape(opts.program),
			-- dont catch SIGSEGV
			"process handle SIGSEGV -p true -s false -n true",
			-- do catch abort
			"breakpoint set --name abort",
			"breakpoint set --name __android_log_assert",
			"breakpoint set --name __assert2",
		},
		stopOnEntry = false,
	})
end

return M
