local M = {}

M.set_buf_keymap = function(buf, mode, lhs, func)
	vim.keymap.set(mode, lhs, func, {
		buffer = buf,
		noremap = true,
		nowait = true,
		silent = true,
	})
end

M.create_floating_window = function(config, enter)
	local buf = vim.api.nvim_create_buf(false, true)
	local win = vim.api.nvim_open_win(buf, enter or false, config)

	vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })

	vim.keymap.set("n", "i", "<nop>", { buffer = buf })
	vim.keymap.set("n", "a", "<nop>", { buffer = buf })
	vim.keymap.set("n", "o", "<nop>", { buffer = buf })
	vim.keymap.set("n", "O", "<nop>", { buffer = buf })
	vim.keymap.set("n", "c", "<nop>", { buffer = buf })
	vim.keymap.set("n", "s", "<nop>", { buffer = buf })

	return { buf = buf, win = win }
end

return M
