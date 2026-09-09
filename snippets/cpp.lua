---@diagnostic disable: unused-local
local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local c = ls.choice_node
local d = ls.dynamic_node
local r = ls.restore_node
local rep = require("luasnip.extras").rep
local fmta = require("luasnip.extras.fmt").fmta
---@diagnostic enable: unused-local

local function name()
	return vim.fn.expand("%:t:r")
end

local function header_guard()
	return "_" .. string.upper(vim.fn.expand("%:t"):gsub("(%u%U)", "_%1")):gsub("%W", "_") .. "_"
end

local function project()
	return require("rayne.build_config").get_application_name()
end

local function namespace()
	return vim.fn.expand("%:t"):match("^(%u+)%u%U") or project():gsub("%U", "")
end

local function class_name()
	return (vim.fn.expand("%:t:r"):gsub("^%u+(%u%U)", "%1"))
end

return {
	s(
		"object",
		fmta(
			[[
#ifndef <>
#define <>

#include <<Rayne.h>>

namespace <>
{
	class <> : public RN::Object
	{
	public:
		<>();
		~<>();

	private:
		RNDeclareMeta(<>)
	};
}

#endif
]],
			{
				f(header_guard),
				f(header_guard),
				f(namespace),
				f(class_name),
				f(class_name),
				f(class_name),
				f(class_name),
			}
		)
	),

	s(
		"node",
		fmta(
			[[
#ifndef <>
#define <>

#include <<Rayne.h>>

namespace <>
{
	class <> : public RN::SceneNode
	{
	public:
		<>();
		~<>();

		void Update(float delta) override;

	private:
		RNDeclareMeta(<>)
	};
}

#endif
]],
			{
				f(header_guard),
				f(header_guard),
				f(namespace),
				f(class_name),
				f(class_name),
				f(class_name),
				f(class_name),
			}
		)
	),

	s(
		"src",
		fmta(
			[[
#incldue "<>.h"

namespace <>
{
	RNDefineMeta(<>, <>)

	<>::<>() {

	}

	<>::~<>() {

	}
}
]],
			{
				f(name),
				f(namespace),
				f(class_name),
				i(1, "SuperClass"),
				f(class_name),
				f(class_name),
				f(class_name),
				f(class_name),
			}
		)
	),

	s("w", t("World::GetSharedInstance()")),
	s("world", t("World::GetSharedInstance()")),
	s("W", t("World* world = World::GetSharedInstance();")),

	s("log", fmta("RNDebug(<>);", { i(1) })),

	s("meta", fmta("RNDefineMeta(<>, <>);", { i(1, "ClassName"), i(2, "SuperClass") })),

	s("str", fmta('RNSTR("<>")', { i(1) })),
	s("cstr", fmta('RNCSTR("<>")', { i(1) })),
	s(
		"traverse",
		fmta(
			[[
Traverse([&](SceneNode *node) {
	<>
});
]],
			{
				i(1),
			}
		)
	),
	s(
		"enumerate",
		fmta(
			[[
Enumerate<<<>>>([&](<> *element, size_t index, bool &stop) {
	<>
});
]],
			{ i(1, "Type"), rep(1), i(2) }
		)
	),
}
