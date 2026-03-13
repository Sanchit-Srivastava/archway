return {
  -- Grammar and spell checking via LanguageTool (LSP)
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        ltex_plus = {
          filetypes = { "tex", "latex", "markdown", "bib" },
          settings = {
            ltex = {
              language = "en-US",
              -- Technical terms that are not real errors
              dictionary = {
                ["en-US"] = {
                  "Hamiltonian",
                  "Hermitian",
                  "ansatz",
                  "bosonic",
                  "citekey",
                  "eigenstates",
                  "eigenvalues",
                  "entanglement",
                  "fermionic",
                  "qubit",
                  "qubits",
                  "superposition",
                  "unitary",
                  "variational",
                },
              },
              -- Disable overly aggressive spell check rules
              disabledRules = {
                ["en-US"] = { "MORFOLOGIK_RULE_EN_US" },
              },
            },
          },
        },
      },
    },
  },

  -- Zotero integration via zotcite: direct DB access, citation completion,
  -- annotation extraction, reference info, and PDF attachment opening.
  -- Type @ in markdown for LSP citekey completion. Use :Zseek for telescope
  -- fuzzy search. In LaTeX, \cite{ triggers completion via the built-in LSP.
  --
  -- Normal mode (cursor on citekey):
  --   <leader>zo  Open PDF attachment
  --   <leader>zi  Reference info (author, year, title)
  --   <leader>za  All reference fields
  --   <leader>zb  Insert abstract into buffer
  --   <leader>zv  View compiled document (PDF/HTML)
  --
  -- Insert mode:
  --   <C-X><C-B>  Citation picker (telescope)
  --
  -- Commands:
  --   :Zseek [pattern]          Fuzzy-search references (telescope)
  --   :Zannotations [key]       Extract Zotero annotations
  --   :Zselectannotations [key] Selectively import annotations
  --   :Znote [key]              Extract Zotero notes
  --   :Zpdfnote [key]           Extract external PDF annotations
  {
    "jalvesaq/zotcite",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-telescope/telescope.nvim",
    },
    config = function()
      require("zotcite").setup({
        -- Use Better BibTeX citation keys (matches existing BBT auto-export)
        key_type = "better-bibtex",
        -- Don't override conceallevel (respect buffer/filetype defaults)
        conceallevel = -1,
      })
    end,
  },

  -- Telescope (required by zotcite for :Zseek and :Zselectannotations)
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    lazy = true,
    cmd = { "Telescope" },
  },
}
