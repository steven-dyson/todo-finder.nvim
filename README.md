# Todo Finder / todo-finder.nvim

**Todo Finder** is a Neovim plugin that scans your project directory
for TODO comments and displays them in a floating window for
easy navigation. It streamlines project management by allowing
quick access to pending tasks.

## Features

- **Fast Scanning**: Quickly searches your project for TODOs.
- **Custom Colors**: Easily configure todo list with custom colors.
- **Keybinding Support**: Set a custom keybinding to open the TODO list.
- **Directory Exclusion**: Exclude directories containing plugins or modules.

## Installation

### Using Lazy.nvim

```lua
return {
  "steven-dyson/todo-finder.nvim",
  branch = "main",
  cmd = "TodoFinder",
  keys = function()
    return {
      {
        "<leader>T",
        function()
          require("todo-finder").list_todos()
        end,
        desc = "Open todos",
      },
    }
  end,
  config = function()
    require("todo-finder").setup({
      exclude_dirs = {
        ["node_modules"] = true,
        [".git"] = true,
      },
      colors = {
        flag = { fg = "#FFFFFF", bg = "#40E0D0", bold = true },
        text = { fg = "#40E0D0" },
        active = { fg = "#FFAF5F" },
      },
    })
  end,
}
```

### Manual Installation

Work In Progress...

## Usage

- Open TODO List: Press `<leader>T` to open the floating window with all TODOs.
- Navigate: Use the arrow keys or `<C-j>` / `<C-k>` to move through the list.
- Jump to TODO: Press `<CR>` to jump to the selected TODO item.

## Commands

- :TodoFinder - Opens the floating TODO window.
- :ListTodos - Lists TODOs in the command line.

## Contributing

Contributions are welcome! Feel free to open issues and submit pull requests.

## License

See LICENSE file