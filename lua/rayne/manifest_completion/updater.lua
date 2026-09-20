local progress = require("rayne.manifest_completion.progress")
local schema_mod = require("rayne.manifest_completion.schema")

local M = {}

local sources_dir = vim.fn.stdpath("data") .. "/android-manifest/sources"

--- @type {url: string, name: string}[]
local default_repos = {
	{ url = "https://github.com/meta-quest/horizon-android-samples", name = "horizon-android-samples" },
	{ url = "https://github.com/meta-quest/agentic-tools", name = "agentic-tools" },
	{ url = "https://github.com/meta-quest/horizon-platform-sdk-samples", name = "horizon-platform-sdk-samples" },
}

local regex = {
	permission = {
		'<uses%-permission[^>]*android:name%s*=%s*"([^"]*)"',
		"<uses%-permission[^>]*android:name%s*=%s*'([^']*)'",
	},
	feature = {
		'<uses%-feature[^>]*android:name%s*=%s*"([^"]*)"',
		"<uses%-feature[^>]*android:name%s*=%s*'([^']*)'",
	},
	metadata = {
		name_value = {
			'<meta%-data[^>]*android:name%s*=%s*"([^"]*)"[^>]*android:value%s*=%s*"([^"]*)"',
			"<meta%-data[^>]*android:name%s*=%s*'([^']*)'[^>]*android:value%s*=%s*'([^']*)'",
		},
		value_name = {
			'<meta%-data[^>]*android:value%s*=%s*"([^"]*)"[^>]*android:name%s*=%s*"([^"]*)"',
			"<meta%-data[^>]*android:value%s*=%s*'([^']*)'[^>]*android:name%s*=%s*'([^']*)'",
		},
	},
	stubs = {
		manifest = "<manifest",
		permission = "<uses%-permission",
		metadata = "<meta%-data",
	},
}

local running = false

--- @return string
function M.get_sources_dir()
	return sources_dir
end

--- @return boolean
function M.is_running()
	return running
end

--- @class ExtractedEntry
--- @field name string
--- @field source ManifestSource

--- extract manifest declarations from XML content (pure, no IO)
--- @param content string
--- @param source ManifestSource
--- @return {permissions: ExtractedEntry[], features: ExtractedEntry[], metadata: ManifestMetadataEntry[]}
local function extract_from_xml(content, source)
	local result = { permissions = {}, features = {}, metadata = {} }
	local seen = {}

	local function add_entry(list, name)
		if name and not seen[name] then
			seen[name] = true
			list[#list + 1] = { name = name, source = source }
		end
	end

	for _, re in ipairs(regex.permission) do
		for name in content:gmatch(re) do
			add_entry(result.permissions, name)
		end
	end

	for _, re in ipairs(regex.feature) do
		for name in content:gmatch(re) do
			add_entry(result.features, name)
		end
	end

	local function add_metadata(name, value)
		if not seen["meta:" .. name] then
			seen["meta:" .. name] = true
			local values = {}
			if value:find("|", 1, true) then
				for v in value:gmatch("[^|]+") do
					values[#values + 1] = v
				end
			else
				values[1] = value
			end
			result.metadata[#result.metadata + 1] = {
				name = name,
				values = values,
				separator = value:find("|", 1, true) and "|" or nil,
				source = source,
			}
		end
	end

	for _, re in ipairs(regex.metadata.name_value) do
		for name, value in content:gmatch(re) do
			add_metadata(name, value)
		end
	end

	for _, re in ipairs(regex.metadata.value_name) do
		for value, name in content:gmatch(re) do
			add_metadata(name, value)
		end
	end

	return result
end

--- @param content string
--- @return string
local function extract_xml_from_markdown(content)
	local blocks = {}
	for block in content:gmatch("```%-?xml\n(.-)```") do
		blocks[#blocks + 1] = block
	end
	return table.concat(blocks, "\n")
end

--- @param entries ExtractedEntry[]
--- @return ExtractedEntry[]
local function dedup(entries)
	local seen = {}
	local result = {}
	for _, entry in ipairs(entries) do
		if not seen[entry.name] then
			seen[entry.name] = true
			result[#result + 1] = entry
		end
	end
	return result
end

--- @param metadata ManifestMetadataEntry[]
--- @return ManifestMetadataEntry[]
local function merge_metadata(metadata)
	local by_name = {}
	local order = {}
	for _, entry in ipairs(metadata) do
		if not by_name[entry.name] then
			by_name[entry.name] = {
				name = entry.name,
				values = {},
				separator = entry.separator,
				source = entry.source,
			}
			order[#order + 1] = entry.name
		end
		local target = by_name[entry.name]
		for _, v in ipairs(entry.values or {}) do
			local found = false
			for _, existing in ipairs(target.values) do
				if existing == v then
					found = true
					break
				end
			end
			if not found then
				target.values[#target.values + 1] = v
			end
		end
	end
	local result = {}
	for _, name in ipairs(order) do
		result[#result + 1] = by_name[name]
	end
	return result
end

local function append_all(dst, src)
	for _, p in ipairs(src.permissions) do
		dst.permissions[#dst.permissions + 1] = p
	end
	for _, f in ipairs(src.features) do
		dst.features[#dst.features + 1] = f
	end
	for _, m in ipairs(src.metadata) do
		dst.metadata[#dst.metadata + 1] = m
	end
end

--- run the schema update in the background using a coroutine.
--- git work is fully async via vim.system callbacks; file scanning
--- yields back to the main loop so the editor never blocks.
--- @param on_done fun(ok: boolean)|nil called on the main loop when finished
--- @return boolean started false when an update is already running
function M.update_async(on_done)
	if running then
		return false
	end
	running = true

	local handle = progress.create("Android manifest schema", "Starting update...")

	local co
	--- resume the worker, handling errors and completion centrally
	--- (avoids pcall inside the coroutine, which LuaJIT forbids yielding across)
	--- @param ... any values passed to the resumed coroutine
	local function step(...)
		local results = { coroutine.resume(co, ...) }
		local ok = results[1]
		if not ok then
			running = false
			handle:fail("Schema update failed: " .. tostring(results[2]))
			if on_done then
				vim.schedule(function()
					on_done(false)
				end)
			end
			return
		end
		if coroutine.status(co) == "dead" then
			running = false
			local counts = results[2]
			if counts then
				handle:finish(string.format("Schema updated: %d permissions, %d features, %d metadata", counts.permissions, counts.features, counts.metadata))
			else
				handle:fail("Failed to update Android manifest schema")
			end
			if on_done then
				vim.schedule(function()
					on_done(counts ~= nil)
				end)
			end
		end
	end

	local function resume_later()
		vim.schedule(function()
			if coroutine.status(co) ~= "dead" then
				step()
			end
		end)
	end

	--- non-blocking vim.system that resumes the worker on completion
	--- must be called from inside the worker coroutine
	--- @param cmd string[]
	--- @param cwd string|nil
	--- @return boolean ok, string output
	local function await_system(cmd, cwd)
		local worker = coroutine.running()
		assert(worker == co, "await_system must run inside update coroutine")
		local done_ok, done_out
		vim.system(cmd, { text = true, cwd = cwd }, function(res)
			done_ok = res.code == 0
			done_out = (res.stdout or "") .. (res.stderr or "")
			resume_later()
		end)
		coroutine.yield()
		return done_ok, done_out
	end

	--- yield back to the main loop so the UI stays responsive
	local function checkpoint()
		resume_later()
		coroutine.yield()
	end

	--- @param url string
	--- @param name string
	--- @param index integer
	--- @param total integer
	local function ensure_repo_async(url, name, index, total)
		local dir = sources_dir .. "/" .. name
		if vim.fn.isdirectory(dir .. "/.git") == 1 then
			handle:report(string.format("Fetching %s (%d/%d)...", name, index, total), (index - 1) / total * 60)
			local ok = await_system({ "git", "fetch", "--all" }, dir)
			if ok then
				ok = await_system({ "git", "pull" }, dir)
			end
			return ok
		else
			handle:report(string.format("Cloning %s (%d/%d)...", name, index, total), (index - 1) / total * 60)
			if vim.fn.isdirectory(dir) == 1 then
				vim.fn.delete(dir, "rf")
			end
			return await_system({ "git", "clone", "--depth=1", url, dir })
		end
	end

	--- @param repo_dir string
	--- @return string commit hash or "unknown"
	local function get_commit_async(repo_dir)
		local ok, out = await_system({ "git", "rev-parse", "HEAD" }, repo_dir)
		if ok then
			return (out:gsub("%s+", ""))
		end
		return "unknown"
	end

	--- scan a repo dir, yielding to the main loop every batch of files
	--- @param dir string
	--- @param repo_url string
	--- @param commit string
	--- @return table extracted
	local function extract_from_dir_async(dir, repo_url, commit)
		local extracted = { permissions = {}, features = {}, metadata = {} }

		local function scan(pattern, from_markdown)
			local files = vim.fn.glob(dir .. pattern, false, true)
			for i, filepath in ipairs(files) do
				local rel = filepath:sub(#dir + 2)
				local content = table.concat(vim.fn.readfile(filepath), "\n")
				if from_markdown then
					content = extract_xml_from_markdown(content)
				end
				if #content > 0 and (content:match(regex.stubs.manifest) or content:match(regex.stubs.permission) or content:match(regex.stubs.metadata)) then
					local source = { type = "git", repo = repo_url, commit = commit, file = rel }
					append_all(extracted, extract_from_xml(content, source))
				end
				if i % 25 == 0 then
					checkpoint()
				end
			end
		end

		scan("/**/*.xml", false)
		checkpoint()
		scan("/**/*.md", true)

		return extracted
	end

	co = coroutine.create(function()
		if vim.fn.isdirectory(sources_dir) == 0 then
			vim.fn.mkdir(sources_dir, "p")
		end

		local total = #default_repos
		for i, repo in ipairs(default_repos) do
			local ok = ensure_repo_async(repo.url, repo.name, i, total)
			if not ok then
				progress.notify("Failed to update " .. repo.name, vim.log.levels.WARN)
			end
		end

		local all = { permissions = {}, features = {}, metadata = {} }
		for i, repo in ipairs(default_repos) do
			local dir = sources_dir .. "/" .. repo.name
			if vim.fn.isdirectory(dir) == 1 then
				handle:report(string.format("Scanning %s (%d/%d)...", repo.name, i, total), 60 + (i - 1) / total * 35)
				local commit = get_commit_async(dir)
				append_all(all, extract_from_dir_async(dir, repo.url, commit))
			end
		end

		handle:report("Saving schema...", 98)
		all.permissions = dedup(all.permissions)
		all.features = dedup(all.features)
		all.metadata = merge_metadata(all.metadata)

		local s = schema_mod.empty()
		s.permissions = all.permissions
		s.features = all.features
		s.metadata = all.metadata
		schema_mod.save(s)
		checkpoint()

		return { permissions = #s.permissions, features = #s.features, metadata = #s.metadata }
	end)

	step()
	return true
end

return M
