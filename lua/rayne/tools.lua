local utils = require("rayne.utils")

local M = {}

local VERSION_FILE = "VERSION"

local function read_version()
	local lines = vim.fn.readfile(VERSION_FILE)
	if #lines < 2 then
		vim.notify("Invalid VERSION file format", vim.log.levels.ERROR)
		return nil
	end

	local build = tonumber(lines[1])
	if not build then
		vim.notify("Invalid build number in VERSION file", vim.log.levels.ERROR)
		return nil
	end

	local version = lines[2]
	local major, minor, patch = version:match("(%d+)%.(%d+)%.(%d+)")
	if not major then
		vim.notify("Invalid version format in VERSION file", vim.log.levels.ERROR)
		return nil
	end

	return {
		build = build,
		major = tonumber(major),
		minor = tonumber(minor),
		patch = tonumber(patch),
	}
end

local function write_version(build, major, minor, patch)
	local lines = { tostring(build), major .. "." .. minor .. "." .. patch }
	vim.fn.writefile(lines, VERSION_FILE)
end

local function make_version_commit(version_str, build)
	utils.confirm({
		prompt = "Create commit & tag for version " .. version_str .. " (" .. build .. ")?",
		yes = "Create",
		no = "Skip",
	}, function(confirmed)
		if not confirmed then
			return
		end

		local message = "chore: bump version to " .. version_str .. " (" .. build .. ")"
		local tag_message = "version " .. version_str .. ", build " .. build

		vim.fn.system({ "git", "add", VERSION_FILE })
		vim.fn.system({ "git", "commit", "-m", message })
		vim.fn.system({ "git", "tag", "-a", "v" .. version_str, tag_message })
	end)
end

--- @param type "major" | "minor" | "patch"
function M.bump_version(type)
	if type ~= "major" and type ~= "minor" and type ~= "patch" then
		vim.notify("Usage: bump_version(major|minor|patch)", vim.log.levels.ERROR)
		return
	end

	local version = read_version()
	if not version then
		return
	end

	local build = version.build + 1
	local major = version.major
	local minor = version.minor
	local patch = version.patch

	if type == "major" then
		major = major + 1
		minor = 0
		patch = 0
	elseif type == "minor" then
		minor = minor + 1
		patch = 0
	elseif type == "patch" then
		patch = patch + 1
	end

	write_version(build, major, minor, patch)

	local version_str = major .. "." .. minor .. "." .. patch

	make_version_commit(version_str, build)
end

return M
