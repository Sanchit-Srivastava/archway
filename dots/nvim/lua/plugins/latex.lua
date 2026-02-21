local is_mac = vim.fn.has("macunix") == 1
local has_zathura = vim.fn.executable("zathura") == 1

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

			-- PDF viewer: prefer zathura on all platforms, fall back to Skim on macOS
			-- Zathura supports forward/inverse search via SyncTeX on both Linux and macOS.
			-- VimTeX automatically passes -x to zathura for inverse search.
			-- On Wayland (no xdotool), use the simple variant to avoid duplicate instances.
			if has_zathura then
				vim.g.vimtex_view_method = "zathura"
			elseif is_mac then
				-- Fallback: Skim on macOS when zathura is not installed
				vim.g.vimtex_view_method = "skim"
			else
				-- Fallback: generic viewer (shouldn't happen on a properly set up system)
				vim.g.vimtex_view_method = "general"
			end

			-- Optional quality-of-life
			vim.g.vimtex_quickfix_mode = 0 -- don't auto-open quickfix on warnings
		end,
	},
}
