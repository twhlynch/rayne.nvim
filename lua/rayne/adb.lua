local M = {}

--- @param source string
--- @param dest string
function M.push(source, dest)
	local result = vim.system({ "adb", "push", source, dest }):wait()

	local success = result.code == 0
	if not success then
		vim.notify("Failed to push " .. source .. " to device", vim.log.levels.ERROR)
	end

	return success
end

---@param pkg string
---@param activity string
function M.launch(pkg, activity)
	local result = vim.system({ "adb", "shell", "am", "start", "-n", pkg .. "/" .. activity }):wait()

	local success = result.code == 0
	if not success then
		vim.notify("Failed to launch " .. pkg .. "/" .. activity, vim.log.levels.ERROR)
	end

	return success
end

---@param pkg string
---@param activity string
function M.launch_debug(pkg, activity)
	local result = vim.system({ "adb", "shell", "am", "start", "-D", "-n", pkg .. "/" .. activity }):wait()

	local success = result.code == 0
	if not success then
		vim.notify("Failed to launch " .. pkg .. "/" .. activity .. " in debug mode", vim.log.levels.ERROR)
	end

	return success
end

function M.kill_lldb_server()
	vim.system({ "adb", "shell", "pkill", "-9", "-f", "lldb-server" }):wait()
	vim.wait(500)
end

function M.remove_forward(port)
	vim.system({ "adb", "forward", "--remove", "tcp:" .. port }):wait()
end

--- @param pkg string
--- @param port number
--- @param lldb_server_path string
--- @return boolean
function M.start_lldb_server(pkg, port, lldb_server_path)
	local tmp = "/data/local/tmp/lldb-server"
	local app_dir = "/data/data/" .. pkg

	-- push to temp location
	vim.system({ "adb", "push", lldb_server_path, tmp }):wait()
	vim.system({ "adb", "shell", "chmod", "755", tmp }):wait()

	-- Copy into apps private dir
	vim.system({ "adb", "shell", "run-as", pkg, "cp", tmp, app_dir .. "/lldb-server" }):wait()
	vim.system({ "adb", "shell", "run-as", pkg, "chmod", "700", app_dir .. "/lldb-server" }):wait()

	-- start platform server as the app user
	vim.fn.jobstart({
		"adb",
		"shell",
		"run-as",
		pkg,
		app_dir .. "/lldb-server",
		"platform",
		"--server",
		"--listen",
		"*:" .. tostring(port),
	}, { detach = true })

	-- forward the port
	local deadline = vim.loop.now() + 5000
	while vim.loop.now() < deadline do
		local fwd = vim.system({ "adb", "forward", "tcp:" .. port, "tcp:" .. port }):wait()
		if fwd.code == 0 then
			return true
		end
		vim.wait(50)
	end

	vim.notify("Timed out waiting for lldb-server forward", vim.log.levels.ERROR)
	return false
end

--- @param port number
--- @return boolean
function M.forward_port(port)
	local deadline = vim.loop.now() + 5000
	while vim.loop.now() < deadline do
		local fwd = vim.system({ "adb", "forward", "tcp:" .. port, "tcp:" .. port }):wait()
		if fwd.code == 0 then
			return true
		end
		vim.wait(50)
	end

	vim.notify("Timed out waiting for port forward", vim.log.levels.ERROR)
	return false
end

local function get_pid(pkg)
	local result = vim.fn.systemlist({ "adb", "shell", "pidof", "-s", pkg })

	local pid = result[1] and vim.trim(result[1]) or nil
	if not pid or pid == "" then
		return nil
	end

	return pid
end

--- @param pkg string
function M.get_pid(pkg)
	local pid = get_pid(pkg)

	if not pid then
		vim.notify("Could not find running process for " .. pkg, vim.log.levels.ERROR)
	end

	return pid
end

--- @param port number
--- @param timeout_ms integer
function M.wait_for_port(port, timeout_ms)
	timeout_ms = timeout_ms or 5000
	local waited = 0
	local interval = 100

	while waited < timeout_ms do
		local sock = vim.loop.new_tcp()
		if sock then
			local _, err = sock:connect("127.0.0.1", port, function(_) end)
			sock:close()
			if not err then
				return true
			end
		end
		vim.wait(interval)
		waited = waited + interval
	end

	vim.notify("Timed out waiting for lldb-server on port " .. port, vim.log.levels.ERROR)
	return false
end

--- @param pkg string
--- @param timeout_ms integer
function M.wait_for_pid(pkg, timeout_ms)
	timeout_ms = timeout_ms or 8000
	local waited = 0
	local interval = 200

	while waited < timeout_ms do
		local pid = get_pid(pkg)
		if pid then
			return pid
		end
		vim.wait(interval)
		waited = waited + interval
	end

	vim.notify("Could not find running process for " .. pkg, vim.log.levels.ERROR)
	return nil
end

--- @param apk string
function M.install(apk)
	local result = vim.system({ "adb", "install", apk }):wait()

	local success = result.code == 0
	if not success then
		vim.notify("Failed to install: " .. (result.stderr or ""), vim.log.levels.ERROR)
	end

	return success
end

--- @param pkg string
function M.uninstall(pkg)
	vim.system({ "adb", "uninstall", pkg }):wait()
end

return M
