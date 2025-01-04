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
  cmd = "ListTodos",
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

- :ListTodos - Opens a floating window and Lists TODOs.

## Contributing

Contributions are welcome! Feel free to open issues and submit pull requests.

## License

See LICENSE file

## Credits

- TJ DeVries (@teej_dv) - Tutorial on creating a Neovim plugin
[Neovim Plugin From Scratch: Markdown Presentation (Part 1)](https://www.youtube.com/watch?v=VGid4aN25iI)

- Folke Lemaitre (@folke) - After starting this project, I found that Folke already
had created one. I took some inspiration around how he is displaying todos, and
plan on also adding support for additional flags.
