# `sfer.nvim`

**sfer.nvim** is a lightweight Neovim plugin designed to visualize SARIF (Static Analysis Results Interchange Format) files directly within the editor. Currently optimized for CodeQL SARIF outputs, it provides an intuitive sidebar interface to navigate and inspect static analysis findings.

<a href="https://asciinema.org/a/720709" target="_blank"><img width="500" src="https://asciinema.org/a/720709.svg" /></a>

## 📦 Installation

<details>
<summary>Using [lazy.nvim](https://github.com/folke/lazy.nvim):</summary>

```lua
{
  'fguisso/sfer.nvim',
  config = function()
    require('sfer').setup()
  end
}
```

</details>

## ✨ Features

* **Sidebar Navigation**: Explore SARIF reports in a structured sidebar.
* **Interactive Exploration**: Press `l` to open files at specific findings.
* **Visual Highlights**: Highlights affected code regions.
* **Lazy Loading**: Optimized for performance with lazy loading capabilities.
* **Minimal Dependencies**: Designed to work seamlessly with LazyVim and other setups.

## 🚀 Usage

Once `sfer.nvim` is installed and configured, it works automatically:

* ✅ When you open a Neovim session in a folder that contains a `.sarif` file (e.g. `results.sarif`), the plugin automatically detects and loads it.
* 🧭 A sidebar will appear on the right showing:

  * Grouped rules
  * Findings per file
  * Locations per finding

### 🕹️ Controls

* `l`:

  * Expand/collapse items in the sidebar
  * If you're on a specific location, it will open the related file and highlight the issue
* `q`: Close the sidebar

## ⚙️ Configuration

<details>

<summary>Customize the plugin by passing options to the `setup` function:</summary>

```lua
require('sfer').setup({
  sidebar = {
    width = 45,       -- Width of the sidebar
    border = 'single' -- Border style: 'single', 'double', 'rounded', etc.
  },
  indent = {
    rule = 0,         -- Indentation for rule lines
    location = 2,     -- Indentation for location lines
    alert = 4         -- Indentation for alert lines
  }
})
```

</details>

## 🔮 TODO

We're actively developing sfer.nvim. Here are the next planned features:

* 🎨 **Add custom highlight groups** for better visual distinction of results and locations
* 🧱 **Improve Nerd Font icons** for each tree level (rule, result, location)
* 📐 **Indent guide lines** similar to `nvim-tree`, showing vertical lines along hierarchy
* 🔍 **Hover preview**: show full file path of a location in the statusline or a floating window
* 🖍 **Highlight current result block** with stronger styles (bold, underline, or background)
* 📊 **SARIF Explorer mode**: allow filtering by rule, severity, or file (for large reports)

## 🙏 Acknowledgements

This project was inspired by the excellent work from:
- [pwntester/codeql.nvim](https://github.com/pwntester/codeql.nvim)
- [microsoft/sarif-vscode-extension](https://github.com/microsoft/sarif-vscode-extension)

Thanks for paving the way in SARIF tooling and Neovim integration.


Pull requests and ideas are welcome!
Feel free to open issues or create discussions.

*Hack the planet!*
