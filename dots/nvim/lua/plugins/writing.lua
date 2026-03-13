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

  -- Citation completion from .bib files (Zotero auto-export)
  -- Type @ in markdown to get citekey completion, or use <C-a>m / <leader>am
  -- to open the fzf picker. In LaTeX, \cite{ triggers completion automatically.
  {
    "urtzienriquez/citeref.nvim",
    ft = { "markdown", "tex", "latex" },
    config = function()
      require("citeref").setup({
        backend = "fzf",
        bib_files = { "~/notes/references/library.bib" },
        filetypes = { "markdown", "tex", "latex" },
      })
    end,
  },

  -- Register citeref as a blink.cmp completion source
  {
    "saghen/blink.cmp",
    opts = {
      sources = {
        providers = {
          citeref = {
            name = "citeref",
            module = "citeref.backends.blink",
          },
        },
        per_filetype = {
          markdown = { inherit_defaults = true, "citeref" },
          tex = { inherit_defaults = true, "citeref" },
          latex = { inherit_defaults = true, "citeref" },
        },
      },
    },
  },
}
