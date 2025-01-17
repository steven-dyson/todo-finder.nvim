local helpers = require("todo-finder.helpers")

local M = {}

-- TODO: Add tests
-- TODO: Support for additional flags such as NOTE, TEST, and WARN
-- TODO: Update README to include manual and Packer installation methods
-- TODO: Might want to require a minimum neovim version
-- TODO: Add some fancy CD pipeline just because
-- TODO: Remove autocomplete from search window
-- TODO: Hide users cursor and replace with > character
-- TODO: Add function params
-- TODO: Multiline Support for multiple languages (only lua right now)
-- TODO: Some kind of UI change to show turrent todo number and total
-- TODO: Icons on left of line numbers for flags
-- TODO: Concat multiline text to todo list text

if vim.fn.has("nvim-0.8") == 0 then
	vim.api.nvim_err_writeln("This plugin requires Neovim 0.8 or higher. Please update your Neovim version.")
	return
end

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
		flagFilled = { fg = "#40E0D0", bg = "#40E0D0" },
		text = { fg = "#40E0D0" },
		active = { fg = "#FFAF5F" },
	},
	comment_definitions = {
		-- Shared comment styles
		["js_like"] = {
			filetypes = { "javascript", "typescript", "javascriptreact", "typescriptreact", "svelte", "vue" },
			comments = {
				{ open = "//", close = "" }, -- Single-line
				{ open = "/*", close = "*/" }, -- Multi-line
			},
		},
	},
}

-- NOTE: Optimized
M.setup = function(opts)
	local wk = require("which-key")

	opts = opts or {}

	-- Merge opts into settings to prevent errors with old configs
	settings = vim.tbl_deep_extend("force", settings, opts)

	vim.api.nvim_set_hl(0, "TodoFlag", settings.colors.flag)
	vim.api.nvim_set_hl(0, "TodoText", settings.colors.text)
	vim.api.nvim_set_hl(0, "TodoActive", settings.colors.active)
	vim.api.nvim_set_hl(0, "TodoFlagFilled", settings.colors.flagFilled)

	vim.api.nvim_create_user_command("ListTodos", M.list_todos, {})

	wk.add({
		{ settings.keymap, M.list_todos, desc = "List Project Todos", icon = "📋" },
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

-- Highlight Namespaces
local todo_list_default = vim.api.nvim_create_namespace("todo_list_default")
local todo_list_active = vim.api.nvim_create_namespace("todo_list_active")
local todo_list_search = vim.api.nvim_create_namespace("todo_list_search")

-- TODO: This should take in the exclusions as a table with start and end
-- TODO: This should take in a color instead of using TodoActive
local highlight_buffer_matches = function(buf, string, ns, color, exclude_padding)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

	for i, line in ipairs(lines) do
		local lower = string.lower(line:sub(exclude_padding))
		local match_start, match_end = lower:find(string)

		if match_start and match_end then
			vim.api.nvim_buf_add_highlight(
				buf,
				ns,
				color,
				i - 1,
				match_start + exclude_padding - 2,
				match_end + exclude_padding - 1
			)
		end
	end
end

--local

local function get_comments_for_filetype(ft)
	local styles = {}

	for _, group in pairs(settings.comment_definitions) do
		if vim.tbl_contains(group.filetypes, ft) then
			vim.list_extend(styles, group.comments)
		end
	end

	return styles
end

local function escape_pattern(text)
	local escaped = text:gsub("([%p])", "%%%1")
	--return escaped
	return text
end

vim.api.nvim_create_autocmd({ "BufWinEnter", "TextChangedI", "TextChanged" }, {
	callback = function()
		local ft = vim.bo.filetype
		local comments = get_comments_for_filetype(ft)

		local ns = vim.api.nvim_create_namespace("todo-hl-test")
		vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)

		local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
		local is_multiline = false
		local highlights = {}

		for i, line in ipairs(lines) do
			local start_index, end_index = line:find("TODO" .. ":")

			local prev_line = "  "
			if i > 1 then
				prev_line = lines[i - 1]
			end

			local combined = line .. prev_line:sub(1, 2)

			if start_index and end_index then
				table.insert(highlights, { 0, ns, "TodoText", i - 1, 0, -1 })
				--table.insert(highlights, { 0, ns, "TodoFlagFilled", i - 1, end_index - 1, end_index })
				table.insert(highlights, { 0, ns, "TodoFlag", i - 1, start_index - 1, end_index - 1 })
			end

			-- Start multiline checks
			for _, comment in ipairs(comments) do
				if is_multiline then
					table.insert(highlights, { 0, ns, "TodoText", i - 1, 0, -1 })
				end

				local open_start, open_end = line:find(escape_pattern(comment.open))
				local close_start, close_end = combined:find(escape_pattern(comment.close))

				if start_index and open_start and comment.close ~= "" and not close_start then
					is_multiline = true
					table.insert(highlights, { 0, ns, "TodoText", i - 1, 0, -1 })
				end

				if close_start and comment.close ~= "" then
					is_multiline = false
				end
			end
		end

		for _, hl in ipairs(highlights) do
			vim.api.nvim_buf_add_highlight(hl[1], hl[2], hl[3], hl[4], hl[5], hl[6])
		end
	end,
})

local function update_todo_highlights()
	local lines = vim.api.nvim_buf_get_lines(state.current_buf, 0, -1, false)
	local win_width = vim.api.nvim_win_get_width(0)
	vim.api.nvim_buf_clear_namespace(state.current_buf, todo_list_default, 0, -1)

	for i = 1, #lines do
		local todo_block = math.floor((i - 1) / 3) + 1
		local line_in_block = (i - 1) % 3
		local end_col = win_width

		-- Highlight the first line's flag and file path
		if line_in_block == 0 then
			vim.api.nvim_buf_add_highlight(state.current_buf, todo_list_default, "TodoFlag", i - 1, 0, 4)
			vim.api.nvim_buf_add_highlight(state.current_buf, todo_list_default, "Title", i - 1, 4, -1)
		end

		-- First line of active block
		if line_in_block == 0 and todo_block == state.current_todo then
			if vim.api.nvim_get_current_win() ~= state.search_win then
				vim.api.nvim_win_set_cursor(0, { i, 0 })
			end
			vim.api.nvim_buf_add_highlight(state.current_buf, todo_list_default, "CursorLine", i - 1, 4, end_col)
		end

		-- Second line of active block
		if line_in_block == 1 and todo_block == state.current_todo then
			vim.api.nvim_buf_add_highlight(state.current_buf, todo_list_default, "CursorLine", i - 1, 0, 200)
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
	vim.cmd("nohlsearch")
	M.create_list_window()

	M.update_list_buf()

	M.create_search_window()
end

M.update_list_buf = function()
	local all_todos = M.find_todos()
	local filtered_todos = {}

	local todo_text = {}
	local spaces = string.rep(" ", 150)

	for _, todo in ipairs(all_todos) do
		local lower_text = string.lower(todo.text)
		local lower_path = string.lower(todo.path)

		if lower_text:find(state.search_string) or lower_path:find(state.search_string) then
			table.insert(filtered_todos, todo)
			table.insert(todo_text, string.format("TODO %s:%s%s", todo.path, todo.line, spaces))
			table.insert(todo_text, string.format("%s%s", todo.text, spaces))
			table.insert(todo_text, "")
		end
	end

	state.todos = filtered_todos

	vim.api.nvim_buf_set_lines(state.current_buf, 0, -1, false, todo_text)

	update_todo_highlights()
	highlight_buffer_matches(state.current_buf, state.search_string, todo_list_search, "TodoActive", 5)
end

M.create_list_window = function()
	local width = math.floor(vim.o.columns * 0.7)
	local height = math.floor(vim.o.lines * 0.7)
	local col = math.floor((vim.o.columns - width) / 2)
	local row = math.floor((vim.o.lines - height) / 3)

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
		footer = " / = Search, j = Next, k = Previous, Enter = Jump to, q = Quit ",
		footer_pos = "right",
	}

	local todo_list = helpers.create_floating_window(window_config, true)
	state.current_buf = todo_list.buf
	state.current_win = todo_list.win

	helpers.set_buf_keymap(todo_list.buf, "n", "q", function()
		M.close_todos()
	end)

	helpers.set_buf_keymap(todo_list.buf, "n", "<Esc>", function()
		M.close_todos()
	end)

	helpers.set_buf_keymap(todo_list.buf, "n", "/", function()
		vim.api.nvim_set_current_win(state.search_win)
		vim.cmd("startinsert")
	end)

	helpers.set_buf_keymap(todo_list.buf, "n", "j", function()
		if state.current_todo < #state.todos then
			state.current_todo = state.current_todo + 1
			update_todo_highlights()
		end
	end)

	helpers.set_buf_keymap(todo_list.buf, "n", "k", function()
		if state.current_todo > 1 then
			state.current_todo = state.current_todo - 1
			update_todo_highlights()
		end
	end)

	helpers.set_buf_keymap(todo_list.buf, "n", "<CR>", function()
		M.jump_to_todo()
	end)
end

M.create_search_window = function()
	local width = math.floor(vim.o.columns * 0.7)
	local height = math.floor(vim.o.lines * 0.7)
	local search_window_config = {
		relative = "win",
		win = state.current_win,
		width = width,
		height = 1,
		col = -1,
		row = height + 1,
		style = "minimal",
		border = "rounded",
		title = " Search Results ",
		title_pos = "left",
		footer = " <CR> = Search, q = Quit ",
		footer_pos = "right",
	}

	local search = helpers.create_floating_window(search_window_config, false)
	state.search_win = search.win
	state.search_buf = search.buf

	vim.api.nvim_create_autocmd({ "TextChangedI", "TextChangedP" }, {
		buffer = state.search_buf,
		callback = function()
			local lines = vim.api.nvim_buf_get_lines(state.search_buf, 0, -1, false)
			local query = table.concat(lines, "\n")
			state.search_string = string.lower(query)

			M.update_list_buf()
		end,
	})

	helpers.set_buf_keymap(search.buf, "n", "<Esc>", function()
		vim.cmd("stopinsert")
		vim.api.nvim_set_current_win(state.current_win)
	end)

	helpers.set_buf_keymap(search.buf, "i", "<Esc>", function()
		vim.cmd("stopinsert")
		vim.api.nvim_set_current_win(state.current_win)
	end)

	helpers.set_buf_keymap(search.buf, "n", "q", function()
		vim.cmd("stopinsert")
		M.close_todos()
	end)

	helpers.set_buf_keymap(search.buf, "i", "<CR>", function()
		vim.cmd("stopinsert")
		vim.api.nvim_set_current_win(state.current_win)
	end)
end

M.find_todos = function()
	state.todos = {}
	local project_root = vim.fn.getcwd()

	local function todo_search(path)
		for name, t in vim.fs.dir(path) do
			local full_path = path .. "/" .. name
			local relative_path = full_path:sub(#project_root + 2)

			if t == "directory" and not settings.exclude_dirs[name] and name:sub(1, 1) ~= "." then
				todo_search(full_path)
			elseif t == "file" then
				local data = vim.fn.readfile(full_path)
				local line_number = 1

				for _, line in ipairs(data) do
					local lower = string.lower(line)

					local trimmed_line = line:match("^%s*(.-)%s*$")

					if trimmed_line:find("TODO:" .. " ") then
						local text = trimmed_line:match("TODO:%s*(.*)")

						table.insert(state.todos, {
							text = text,
							path = relative_path,
							line = line_number,
						})
					end
					line_number = line_number + 1
				end
			end
		end
	end

	todo_search(project_root)

	return state.todos
end

M.close_todos = function()
	if state.current_win and vim.api.nvim_win_is_valid(state.current_win) then
		vim.api.nvim_win_close(state.current_win, true)
		state.current_win = nil
	end

	if state.search_win and vim.api.nvim_win_is_valid(state.search_win) then
		vim.api.nvim_win_close(state.search_win, true)
		state.search_win = nil
	end

	if state.current_buf and vim.api.nvim_buf_is_valid(state.current_buf) then
		vim.api.nvim_buf_delete(state.current_buf, { force = true })
		state.current_buf = nil
	end

	if state.search_buf and vim.api.nvim_buf_is_valid(state.search_buf) then
		vim.api.nvim_buf_delete(state.search_buf, { force = true })
		state.search_buf = nil
	end

	state.current_todo = 1
	state.search_string = ""
end

return M