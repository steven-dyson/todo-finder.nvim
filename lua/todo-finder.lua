local M = {}

--[[
-- TODO: Add tests 
-- TODO: Support for additional flags such as NOTE, TEST, and WARN
-- TODO: Update README to include manual and Packer installation methods
-- TODO: Might want to require a minimum neovim version
-- TODO: Add some fancy CD pipeline just because
--]]

local settings = {
	exclude_dirs = {
		["node_modules"] = true,
		[".git"] = true,
		[".cache"] = true,
		["target"] = true,
		["build"] = true,
		["dist"] = true,
		["venv"] = true,
		["__pycache__"] = true,
	},
	keymap = "<leader>T",
	colors = {
		flag = { fg = "#000000", bg = "#40E0D0", bold = true },
		text = { fg = "#40E0D0" },
		active = { fg = "#FFAF5F" },
	},
}

-- Set up an autocmd that triggers when a new buffer is opened
vim.api.nvim_create_autocmd("BufWinEnter", {
	callback = function()
		--print("Ran")
	end,
})

M.setup = function(opts)
	opts = opts or {}

	if opts.colors then
		settings.colors = opts.colors
	end

	if opts.keymap then
		settings.keymap = opts.keymap
	end

	if opts.exclude_dirs then
		settings.exclude_dirs = opts.exclude_dirs
	end

	vim.api.nvim_set_hl(0, "TodoFlag", settings.colors.flag)
	vim.api.nvim_set_hl(0, "TodoText", settings.colors.text)
	vim.api.nvim_set_hl(0, "TodoActive", settings.colors.active)

	vim.api.nvim_create_user_command("ListTodos", M.list_todos, {})

	vim.keymap.set("n", settings.keymap, M.list_todos, {
		desc = "List Project Todos",
		silent = true,
	})
end

local state = {
	todos = {},
	current_win = nil,
	current_buf = nil,
	current_todo = 1,
	search_win = nil,
	search_buf = nil,
	search_string = "",
}

local set_buf_keymap = function(buf, mode, lhs, func)
	vim.keymap.set(mode, lhs, func, {
		buffer = buf,
		noremap = true,
		nowait = true,
		silent = true,
	})
end

local function update_todo_highlights(ns)
	local lines = vim.api.nvim_buf_get_lines(state.current_buf, 0, -1, false)
	local win_width = vim.api.nvim_win_get_width(0)
	vim.api.nvim_buf_clear_namespace(state.current_buf, ns or -1, 0, -1)

	for i = 1, #lines do
		local todo_block = math.floor((i - 1) / 3) + 1 -- Calculate block number (1-based)
		local line_in_block = (i - 1) % 3 -- Determine which line within the block (0, 1, 2)
		local end_col = win_width

		-- Highlight the first line's "TODO" flag and file path
		if line_in_block == 0 then
			vim.api.nvim_buf_add_highlight(state.current_buf, ns or -1, "TodoFlag", i - 1, 0, 4) -- "TODO" (first 4 chars)
			vim.api.nvim_buf_add_highlight(state.current_buf, ns or -1, "Title", i - 1, 4, -1) -- Rest of the line
		end

		-- First line of active block
		if line_in_block == 0 and todo_block == state.current_todo then
			vim.api.nvim_buf_add_highlight(state.current_buf, ns or -1, "CursorLine", i - 1, 4, end_col)
		end

		-- Second line of active block
		if line_in_block == 1 and todo_block == state.current_todo then
			vim.api.nvim_buf_add_highlight(state.current_buf, ns or -1, "CursorLine", i - 1, 0, 200)
		end
	end
end

-- TODO: Make this generic so it supports being used on any floating windows.
-- It currently uses state.current_buf and state.current_win
local create_floating_window = function(config, enter)
	local buf = vim.api.nvim_create_buf(false, true)
	local win = vim.api.nvim_open_win(buf, enter or false, config)
	vim.api.nvim_set_option_value("omnifunc", "", { buf = buf })
	--vim.api.nvim_set_option_value("completeopt", "manual", { buf = buf }) -- TODO: Hide cursor in current window

	set_buf_keymap(buf, "n", "q", function()
		M.close_todos()
	end)

	set_buf_keymap(buf, "n", "<Esc>", function()
		M.close_todos()
	end)

	return { buf = buf, win = win }
end

-- Define the namespace globally or in a shared scope
local ns_id = vim.api.nvim_create_namespace("search_highlights")

local highlight_buffer_matches = function(buf, string)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

	-- Clear previous highlights
	vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)

	for i, line in ipairs(lines) do
		local match_start, match_end = line:find(string)
		if match_start and match_end then
			-- Add highlight for each match
			vim.api.nvim_buf_add_highlight(buf, ns_id, "TodoActive", i - 1, match_start - 1, match_end)
		end
	end
end

M.jump_to_todo = function()
	local todo_index = state.current_todo
	local todo = state.todos[todo_index]

	if todo then
		local path = todo.path
		local line = todo.line

		M.close_todos()

		vim.cmd("edit " .. path)
		vim.api.nvim_win_set_cursor(0, { line, 0 })
	end
end

M.list_todos = function()
	-- TODO: Centering seems off for some reason
	local width = math.floor(vim.o.columns * 0.7)
	local height = math.floor(vim.o.lines * 0.7)
	local col = math.floor((vim.o.columns - width) / 2)
	local row = math.floor((vim.o.lines - height) / 3)

	local todo_ns = vim.api.nvim_create_namespace("todo_highlights")
	local window_config = {
		relative = "editor",
		width = width,
		height = height,
		col = col,
		row = row,
		style = "minimal",
		border = "rounded",
		title = " Todo Finder ",
		title_pos = "center",
		footer = " j = Next, k = Previous, Enter = Jump to ",
		footer_pos = "right",
	}

	local todo_list = create_floating_window(window_config, true)
	state.current_buf = todo_list.buf
	state.current_win = todo_list.win

	set_buf_keymap(todo_list.buf, "n", "/", function()
		vim.api.nvim_set_current_win(state.search_win)
		vim.cmd("startinsert")
	end)

	set_buf_keymap(todo_list.buf, "n", "j", function()
		if state.current_todo < #state.todos then
			state.current_todo = state.current_todo + 1
			update_todo_highlights(todo_ns)
		end
	end)

	set_buf_keymap(todo_list.buf, "n", "k", function()
		if state.current_todo > 1 then
			state.current_todo = state.current_todo - 1
			update_todo_highlights(todo_ns)
		end
	end)

	set_buf_keymap(todo_list.buf, "n", "<CR>", function()
		M.jump_to_todo()
	end)

	state.todos = M.find_todos()

	local todo_text = {}

	local spaces = ""

	for i = 1, 150 do
		spaces = spaces .. " "
	end

	for _, todo in ipairs(state.todos) do
		if todo.text:find(state.search_string) then
			table.insert(todo_text, string.format("TODO %s:%s%s", todo.path, todo.line, spaces))
			table.insert(todo_text, string.format("%s%s", todo.text, spaces))
			table.insert(todo_text, "")
		end
	end

	vim.api.nvim_buf_set_lines(state.current_buf, 0, -1, false, todo_text)

	update_todo_highlights(todo_ns)

	local search_window_config = {
		relative = "win", -- Set relative to the current todo list window
		win = state.current_win, -- The reference window is the current TODO list window
		width = width,
		height = 1, -- Set height for one line of text
		col = -1, -- Position left (or adjust as needed)
		row = height + 1, -- Position it directly below the todo list window
		style = "minimal",
		border = "rounded",
		title = " Search Results ",
		title_pos = "left",
	}

	local search = create_floating_window(search_window_config, false)
	state.search_win = search.win
	state.search_buf = search.buf

	vim.api.nvim_create_autocmd({ "TextChangedI", "TextChangedP" }, {
		buffer = state.search_buf,
		callback = function()
			local lines = vim.api.nvim_buf_get_lines(state.search_buf, 0, -1, false)
			local query = table.concat(lines, "\n")
			print("Current input: " .. query) -- Live output
			state.search_string = query

			highlight_buffer_matches(state.current_buf, query)
		end,
	})

	set_buf_keymap(search.buf, "n", "<Esc>", function()
		print("RAN ESC")
		vim.cmd("stopinsert")
		vim.api.nvim_set_current_win(todo_list.win)
	end)

	set_buf_keymap(search.buf, "i", "<CR>", function()
		vim.cmd("stopinsert")
		vim.api.nvim_set_current_win(todo_list.win)
	end)
end

M.find_todos = function()
	state.todos = {}
	local project_root = vim.fn.getcwd()

	local function todo_search(path)
		for name, t in vim.fs.dir(path) do
			-- TODO: Can probably just get the relative path
			local full_path = path .. "/" .. name

			if t == "directory" and not settings.exclude_dirs[name] and name:sub(1, 1) ~= "." then
				todo_search(full_path)
			elseif t == "file" then
				local data = vim.fn.readfile(full_path)
				local line_number = 0

				for _, line in ipairs(data) do
					line_number = line_number + 1

					-- Trim the line before
					local trimmed_line = line:match("^%s*(.-)%s*$")

					-- TODO: I removed the test_chars because it broken todos at the end
					-- of new lines. However I'd like to add a check for comments to
					-- address this later

					if trimmed_line:find("TODO: ") then
						-- Extract the text after "TODO"
						local text = trimmed_line:match("TODO:%s*(.*)")

						-- Get the relative path
						local relative_path = full_path:sub(#project_root + 2)

						table.insert(state.todos, {
							text = text,
							path = relative_path,
							line = line_number,
						})
					end
				end
			end
		end
	end

	todo_search(project_root)

	-- TODO: After going back ad forth on using state or a local
	-- variable, I'm still undecided so I'll probably change later
	return state.todos
end

M.close_todos = function()
	-- Close the TODO list window
	if state.current_win and vim.api.nvim_win_is_valid(state.current_win) then
		vim.api.nvim_win_close(state.current_win, true)
		state.current_win = nil
	end

	-- Close the search window (if it exists)
	if state.search_win and vim.api.nvim_win_is_valid(state.search_win) then
		vim.api.nvim_win_close(state.search_win, true)
		state.search_win = nil
	end

	-- Delete the associated buffers
	if state.current_buf and vim.api.nvim_buf_is_valid(state.current_buf) then
		vim.api.nvim_buf_delete(state.current_buf, { force = true })
		state.current_buf = nil
	end

	if state.search_buf and vim.api.nvim_buf_is_valid(state.search_buf) then
		vim.api.nvim_buf_delete(state.search_buf, { force = true })
		state.search_buf = nil
	end

	-- Reset the current todo to the first one
	state.current_todo = 1
end

-- Modify the 'q' and '<Esc>' key mappings to close both windows
set_buf_keymap(state.current_buf, "n", "q", function()
	M.close_todos()
end)

set_buf_keymap(state.current_buf, "n", "<Esc>", function()
	M.close_todos()
end)

return M
