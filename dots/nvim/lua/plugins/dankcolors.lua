return {
	{
		"RRethy/base16-nvim",
		priority = 1000,
		config = function()
			require('base16-colorscheme').setup({
				base00 = '#141314',
				base01 = '#141314',
				base02 = '#84838e',
				base03 = '#84838e',
				base04 = '#d9d8e5',
				base05 = '#f9f8ff',
				base06 = '#f9f8ff',
				base07 = '#f9f8ff',
				base08 = '#ff9fb5',
				base09 = '#ff9fb5',
				base0A = '#dddbf0',
				base0B = '#a5ffb6',
				base0C = '#f3f2ff',
				base0D = '#dddbf0',
				base0E = '#edecff',
				base0F = '#edecff',
			})

			vim.api.nvim_set_hl(0, 'Visual', {
				bg = '#84838e',
				fg = '#f9f8ff',
				bold = true
			})
			vim.api.nvim_set_hl(0, 'Statusline', {
				bg = '#dddbf0',
				fg = '#141314',
			})
			vim.api.nvim_set_hl(0, 'LineNr', { fg = '#84838e' })
			vim.api.nvim_set_hl(0, 'CursorLineNr', { fg = '#f3f2ff', bold = true })

			vim.api.nvim_set_hl(0, 'Statement', {
				fg = '#edecff',
				bold = true
			})
			vim.api.nvim_set_hl(0, 'Keyword', { link = 'Statement' })
			vim.api.nvim_set_hl(0, 'Repeat', { link = 'Statement' })
			vim.api.nvim_set_hl(0, 'Conditional', { link = 'Statement' })

			vim.api.nvim_set_hl(0, 'Function', {
				fg = '#dddbf0',
				bold = true
			})
			vim.api.nvim_set_hl(0, 'Macro', {
				fg = '#dddbf0',
				italic = true
			})
			vim.api.nvim_set_hl(0, '@function.macro', { link = 'Macro' })

			vim.api.nvim_set_hl(0, 'Type', {
				fg = '#f3f2ff',
				bold = true,
				italic = true
			})
			vim.api.nvim_set_hl(0, 'Structure', { link = 'Type' })

			vim.api.nvim_set_hl(0, 'String', {
				fg = '#a5ffb6',
				italic = true
			})

			vim.api.nvim_set_hl(0, 'Operator', { fg = '#d9d8e5' })
			vim.api.nvim_set_hl(0, 'Delimiter', { fg = '#d9d8e5' })
			vim.api.nvim_set_hl(0, '@punctuation.bracket', { link = 'Delimiter' })
			vim.api.nvim_set_hl(0, '@punctuation.delimiter', { link = 'Delimiter' })

			vim.api.nvim_set_hl(0, 'Comment', {
				fg = '#84838e',
				italic = true
			})

			local current_file_path = vim.fn.stdpath("config") .. "/lua/plugins/dankcolors.lua"
			if not _G._matugen_theme_watcher then
				local uv = vim.uv or vim.loop
				_G._matugen_theme_watcher = uv.new_fs_event()
				_G._matugen_theme_watcher:start(current_file_path, {}, vim.schedule_wrap(function()
					local new_spec = dofile(current_file_path)
					if new_spec and new_spec[1] and new_spec[1].config then
						new_spec[1].config()
						print("Theme reload")
					end
				end))
			end
		end
	}
}
