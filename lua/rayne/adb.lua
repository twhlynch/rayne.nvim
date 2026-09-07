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

--- @param pkg string
--- @param port number
--- @param lldb_path string
function M.forward(pkg, port, lldb_path)
	vim.fn.jobstart({
		"adb",
		"shell",
		"run-as",
		pkg,
		lldb_path,
		"platform",
		"--listen",
		"unix-abstract:///" .. pkg .. "/lldb-server-sock",
		"--server",
	}, { detach = true })

	local target = "localabstract:" .. pkg .. "/lldb-server-sock"

	local deadline = vim.loop.now() + 5000
	while vim.loop.now() < deadline do
		local result = vim.system({ "adb", "forward", "tcp:" .. port, target }):wait()
		if result.code == 0 then
			return true
		end
		vim.wait(50)
	end

	vim.notify("Timed out waiting for LLDB server forward", vim.log.levels.ERROR)
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

return M
