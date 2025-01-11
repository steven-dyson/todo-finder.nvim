# todo-finder.nvim

**Todo Finder** is a Neovim plugin that scans your project directory
for TODO comments and displays them in a floating window for
easy navigation. It streamlines project management by allowing
quick access to pending tasks.

![Neovim window with todo-finder.nvim open](https://raw.githubusercontent.com/steven-dyson/todo-finder.nvim/main/images/screenshot_1.png)

## Features

- **Fast Scanning**: Quickly searches your project for TODOs.
- Buffer Highlight: Flags are highlighted in the active buffer.
- **Custom Colors**: Easily configure todo list with custom colors.
- **Keybinding Support**: Set a custom keybinding to open the TODO list.
- **Directory Exclusion**: Exclude directories containing plugins or modules.
- Filtering: Filter todo list by file name and todo text.
- Search Highlights: Search results include highlights.
- User Interface: Clean user interface to make reading todos easy.

## Installation

### Using Lazy.nvim

```lua
return {
  "steven-dyson/todo-finder.nvim",
  branch = "main", -- or tag = "0.5.1"
  dependencies = { "folke/which-key.nvim" },
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
- Jump to TODO Press `<CR>` to jump to the selected TODO item.
- Search TODO List: Press `/` to enter search window.

## Commands

- :ListTodos - Opens a floating window and Lists TODOs.

## Contributing

Contributions are welcome! Feel free to open issues and submit pull requests.

## Support My Work

If you find this project useful, consider [buying me a coffee](https://www.buymeacoffee.com/steven.dyson)!

## License

See LICENSE file

## Credits

- TJ DeVries (@teej_dv) - Tutorial on creating a Neovim plugin
[Neovim Plugin From Scratch: Markdown Presentation (Part 1)](https://www.youtube.com/watch?v=VGid4aN25iI)

- Folke Lemaitre (@folke) - After starting this project, I found that Folke already
had created one [todo-comments.nvim](https://github.com/folke/todo-comments.nvim).
I took some inspiration around how he is displaying todos, and plan on also adding
support for additional flags.
