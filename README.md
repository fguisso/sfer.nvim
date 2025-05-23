# sarifviewer.nvim

A simple SARIF viewer plugin for Neovim, designed for Minimal dependencies and LazyVim integration.

## Installation

Using LazyVim:

```lua
-- in your lazy.lua plugin list
{
  "seu-usuario/lazyvim-sarifviewer",
  dependencies = {},  -- no external dependencies
  config = function()
    require("sarifviewer").setup({
      sidebar = { width = 50 },
    })
    require("sarifviewer.commands")
  end,
}
```

## Usage

* `:SarifOpen path/to/report.sarif.json` - Load SARIF and open sidebar.
* In the sidebar:

  * `l` on a *location* or *alert* opens the file at the specified line.
  * `l` on a *rule* currently does nothing (future: collapse/expand).
  * `q` closes the sidebar.

## Configuration

Call `require("sarifviewer").setup(opts)` before loading commands.

| Option                | Default       | Description                                      |
| --------------------- | ------------- | ------------------------------------------------ |
| `sidebar.width`       | `40`          | Width of the sidebar split                       |
| `sidebar.border`      | `"single"`    | Border style for the split ("single", "rounded") |
| `indent.rule`         | `0`           | Indentation spaces for rule lines                |
| `indent.location`     | `2`           | Indentation for location lines                   |
| `indent.alert`        | `4`           | Indentation for alert lines                      |
| `highlights.rule`     | `"Directory"` | Highlight group for rule lines                   |
| `highlights.location` | `"Title"`     | Highlight for location lines                     |
| `highlights.alert`    | `"Comment"`   | Highlight for alert lines                        |

## Contributing

PRs welcome! Feel free to open issues or feature requests.
