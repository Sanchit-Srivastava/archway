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
}
