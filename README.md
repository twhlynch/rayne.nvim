# rayne.nvim

Tooling for using nvim for [Rayne](https://github.com/Überpixel/Rayne) projects.

## Features

- Generate project
- Build project
- Launch project
- Attach lldb to project
- Run and debug Android builds
- Update compile commands in the background
- Bump VERSION, commit, and tag tool
- Build and package release mode
- Upload quest apk

## Usage

Example usage for `lazy.nvim`.

```lua
return {
  "twhlynch/rayne.nvim",
  event = { "BufReadPost", "BufNewFile" },
  opts = {},
  keys = {
    { "<leader>Rb", function() require("rayne.android").build() end, desc = "Android: build" },
    { "<leader>Rl", function() require("rayne.android").build_install_launch() end, desc = "Android: launch" },
    { "<leader>Rd", function() require("rayne.android").build_install_launch_attach() end, desc = "Android: debug" },
    { "<leader>Ra", function() require("rayne.android").attach() end, desc = "Android: attach" },
    { "<leader>Rg", function() require("rayne.android").generate() end, desc = "Android: generate" },
    { "<leader>Rr", function() require("rayne.android").build_install_launch_release() end, desc = "Android: release" },

    { "<leader>RB", function() require("rayne.macos").build() end, desc = "MacOS: build" },
    { "<leader>RL", function() require("rayne.macos").build_launch() end, desc = "MacOS: launch" },
    { "<leader>RD", function() require("rayne.macos").build_launch_attach() end, desc = "MacOS: debug" },
    { "<leader>RA", function() require("rayne.macos").attach() end, desc = "MacOS: attach" },
    { "<leader>RG", function() require("rayne.macos").generate() end, desc = "MacOS: generate" },

    { "<leader>Ru", function() require("rayne.android").upload_quest_build() end, desc = "Upload quest build" },
    { "<leader>Rv", function() require("rayne.tools").bump_version() end, desc = "Bump VERSION" },
  },
}
```
