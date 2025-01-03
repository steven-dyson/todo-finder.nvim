local M = {}
-- Default settings
local default_config = {
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
}

local config = default_config

M.setup = function(opts)
	opts = opts or {}

	vim.api.nvim_create_user_command("ListTodos", M.list_todos, {})

	local keymap = opts.keymap or config.keymap

	if opts.exclude_dirs then
		config.exclude_dirs = opts.exclude_dirs
	end

	vim.keymap.set("n", keymap, M.list_todos, {
		desc = "list project todos",
		silent = true,
	})
end

-- state
local state = {
	todos = {},
	current_win = nil,
	current_buf = nil,
}

local set_buf_keymap = function(buf, mode, lhs, func)
	vim.keymap.set(mode, lhs, func, {
		buffer = buf,
		noremap = true,
		nowait = true,
		silent = true,
	})
end

local function truncate_text(text, max_width)
	if #text > max_width then
		return text:sub(1, max_width - 3) .. "..."
	end
	return text
end

local function get_cursor_line()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local line = cursor[1] - 1

	return line
end

M.jump_to_todo = function()
	local todo_index = get_cursor_line() + 1
	local todo = state.todos[todo_index]

	if todo then
		local path = todo.path
		local line = todo.line

		M.close_todos()

		vim.cmd("edit " .. path) -- Open the file
		vim.api.nvim_win_set_cursor(0, { line, 0 }) -- Jump to the line
	end
end

local function attach_cursor_event()
	local augroup = vim.api.nvim_create_augroup("TodoHighlight", { clear = true })

	vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
		group = augroup,
		buffer = state.current_buf,
		callback = function()
			-- Clear previous highlights
			vim.api.nvim_buf_clear_namespace(state.current_buf, -1, 0, -1)

			-- Highlight the current line
			local line = get_cursor_line()
			vim.api.nvim_buf_add_highlight(state.current_buf, -1, "Todo", line, 0, -1)
		end,
	})
end

local create_floating_window = function(config, enter)
	if enter == nil then
		enter = false
	end

	local buf = vim.api.nvim_create_buf(false, true)
	local win = vim.api.nvim_open_win(buf, enter or false, config)

	state.current_buf = buf
	state.current_win = win

	set_buf_keymap(buf, "n", "q", function()
		M.close_todos()
	end)

	set_buf_keymap(buf, "n", "<Esc>", function()
		M.close_todos()
	end)

	set_buf_keymap(state.current_buf, "n", "<CR>", function()
		M.jump_to_todo()
	end)

	attach_cursor_event()

	return { buf = buf, win = win }
end

M.find_todos = function()
	state.todos = {}
	local project_root = vim.fn.getcwd()

	local function todo_search(path)
		for name, t in vim.fs.dir(path) do
			local full_path = path .. "/" .. name

			if t == "directory" and not config.exclude_dirs[name] and name:sub(1, 1) ~= "." then
				todo_search(full_path)
			elseif t == "file" then
				local data = vim.fn.readfile(full_path)
				local line_number = 0
				for _, line in ipairs(data) do
					line_number = line_number + 1

					-- Trim the line before testing for "TODO"
					local trimmed_line = line:match("^%s*(.-)%s*$")
					local test_chars = trimmed_line:sub(1, 8)

					if test_chars:find("TODO:") then
						-- Extract the text after "TODO" in the trimmed line
						local text = trimmed_line:match("TODO:%s*(.*)")
						table.insert(state.todos, {
							text = text,
							path = full_path,
							line = line_number,
						})
					end
				end
			end
		end
	end

	todo_search(project_root)

	return state.todos
end

M.list_todos = function()
	local width = math.floor(vim.o.columns * 0.8)
	local height = math.floor(vim.o.lines * 0.8)
	local col = math.floor((vim.o.columns - width) / 2)
	local row = math.floor((vim.o.lines - height) / 2)

	state.todos = M.find_todos()

	local window_config = {
		relative = "editor",
		width = width,
		height = height,
		col = col,
		row = row,
		style = "minimal",
		border = "rounded",
		title = "Current Todos",
		title_pos = "center",
	}

	create_floating_window(window_config, true)

	local todo_text = {}

	for _, todo in ipairs(state.todos) do
		table.insert(
			todo_text,
			string.format("TODO: %s [PATH: %s] [LINE: %s]", truncate_text(todo.text, 80), todo.path, todo.line)
		)
	end

	vim.api.nvim_buf_set_lines(state.current_buf, 0, -1, false, todo_text)
	vim.api.nvim_buf_add_highlight(state.current_buf, -1, "Todo", 0, 0, -1)
end

M.close_todos = function()
	if state.current_win and vim.api.nvim_win_is_valid(state.current_win) then
		vim.api.nvim_win_close(state.current_win, true)
		state.current_win = nil
	end

	if state.current_buf and vim.api.nvim_buf_is_valid(state.current_buf) then
		vim.api.nvim_buf_delete(state.current_buf, { force = true })
		state.current_buf = nil
	end
end

return M
