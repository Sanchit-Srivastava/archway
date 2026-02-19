return {
	{
		"lervag/vimtex",
		lazy = false, -- load immediately; avoids filetype timing issues
		init = function()
			-- Use LuaLaTeX by default
			vim.g.vimtex_compiler_method = "latexmk"
			vim.g.vimtex_compiler_latexmk = {
				build_dir = "",
				callback = 1,
				continuous = 1,
				executable = "latexmk",
				options = {
					"-pdf",
					"-shell-escape",
					"-verbose",
					"-file-line-error",
					"-synctex=1",
					"-interaction=nonstopmode",
					"-lualatex",
				},
			}

			-- PDF viewer
			vim.g.vimtex_view_method = "zathura"

			-- Enable inverse search (from PDF -> nvim)
			vim.g.vimtex_view_general_viewer = "zathura"
			vim.g.vimtex_view_general_options = "--synctex-forward @line:@col:@tex @pdf"

			-- Optional quality-of-life
			vim.g.vimtex_quickfix_mode = 0 -- don't auto-open quickfix on warnings
		end,
	},
}
