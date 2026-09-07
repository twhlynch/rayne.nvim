local adb = require("rayne.adb")
local build_config = require("rayne.build_config")
local lldb = require("rayne.lldb")
local options = require("rayne.options")
local utils = require("rayne.utils")

local M = {}

local function start_lldb_server(pkg)
	local opts = options.get()

	local lldb_server_path = lldb.find_server(opts.android.sdk_path)
	if not lldb_server_path then
		return false
	end

	local success = adb.push(lldb_server_path, opts.android.lldb_path)
	if not success then
		return false
	end

	success = adb.forward(pkg, opts.android.forward_port, opts.android.lldb_path)
	if not success then
		return false
	end

	return true
end

local function pick_android_so(search_root)
	return utils.await(function(callback)
		utils.pick_files({
			source = "android_so",
			title = "Pick main .so for symbols",
			cmd = { "find", search_root, "-type", "f", "-iname", "*.so" },
			error = "No .so files found under " .. search_root,
		}, callback)
	end)
end

local function resolve_main_so()
	local main_lib_name = build_config.get_library_name()
	local so_search_root = build_config.get_so_search_root()

	if not main_lib_name then
		return pick_android_so(so_search_root)
	end

	local result = utils.find(main_lib_name, { directory = so_search_root, type = "f" })

	if #result == 0 then
		return pick_android_so(so_search_root)
	end
	if #result == 1 then
		return result[1]
	end

	-- prefer arm64 or aarch64 ABI
	for _, path in ipairs(result) do
		if path:match("arm64") or path:match("aarch64") then
			return path
		end
	end

	return pick_android_so(so_search_root)
end

local function build_extra_symbol_commands(main_so_path)
	local opts = options.get()

	local dir = vim.fn.fnamemodify(main_so_path, ":h")
	local siblings = utils.find("*.so", { directory = dir, maxdepth = 1, insensitive = true })

	local commands = {}
	for _, path in ipairs(siblings) do
		local base = vim.fn.fnamemodify(path, ":t")
		if path ~= main_so_path then
			if base:match(opts.library_pattern) then
				table.insert(commands, "target symbols add " .. path)
			end
		end
	end

	return commands
end

local function build_and_install(project_dir)
	return utils.await(function(done)
		local cmd = { "bash", "-c", "cd " .. project_dir .. " && ./gradlew assembleDebug installDebug" }

		local term = Snacks.terminal.open(cmd, {
			win = { position = "bottom", height = 0.35 },
			auto_close = false,
		})

		vim.api.nvim_create_autocmd("TermClose", {
			buffer = term.buf,
			once = true,
			callback = function()
				local exit_code = vim.v.event and vim.v.event.status or 0
				done(exit_code == 0)
			end,
		})
	end)
end

local function do_attach(pid)
	local package_name = build_config.get_package_name()

	if not start_lldb_server(package_name) then
		return
	end

	local so_path = resolve_main_so()
	if not so_path then
		return
	end

	local attach_commands = {
		"platform select remote-android",
		"platform connect connect://localhost:" .. options.get().android.forward_port,
	}
	vim.list_extend(attach_commands, build_extra_symbol_commands(so_path))

	lldb.attach({
		name = "Attach to Android native (" .. package_name .. ")",
		pid = tonumber(pid) or 0,
		commands = attach_commands,
		program = so_path,
	})
end

-- MARK: Public

function M.build_install_launch()
	utils.async(function()
		local project_dir = build_config.get_android_project_dir()
		if not utils.verify_directory(project_dir) then
			return
		end

		local package_name = build_config.get_package_name()
		local native_activity = build_config.get_native_activity()

		if not build_and_install(project_dir) then
			return
		end

		if not adb.launch(package_name, native_activity) then
			return
		end
	end)
end

function M.build_install_launch_attach()
	utils.async(function()
		local project_dir = build_config.get_android_project_dir()
		if not utils.verify_directory(project_dir) then
			return
		end

		local package_name = build_config.get_package_name()
		local native_activity = build_config.get_native_activity()

		if not build_and_install(project_dir) then
			return
		end

		if not adb.launch_debug(package_name, native_activity) then
			return
		end

		local pid = adb.wait_for_pid(package_name, 8000)
		if not pid then
			return
		end

		do_attach(pid)
	end)
end

function M.attach_only()
	utils.async(function()
		local package_name = build_config.get_package_name()

		local pid = adb.get_pid(package_name)
		if not pid then
			return
		end

		do_attach(pid)
	end)
end

return M
