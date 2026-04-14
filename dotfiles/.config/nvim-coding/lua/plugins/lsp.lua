if vim.loop and vim.loop.getuid and vim.loop.getuid() == 0 then
    return {}
end

return {
    {
        'williamboman/mason.nvim',
        event = 'VeryLazy',
        opts = {
            ui = {
                border = 'rounded',
            },
        },
    },

    {
        'williamboman/mason-lspconfig.nvim',
        dependencies = {
            'williamboman/mason.nvim',
            'neovim/nvim-lspconfig',
        },
        event = 'VeryLazy',
        opts = {
            ensure_installed = {
                'ruff',
                'ts_ls',
                'bashls',
                'lua_ls',
                'gopls',
            },
            handlers = {
                function(server_name)
                    vim.lsp.config(server_name, {
                        capabilities = require('blink.cmp').get_lsp_capabilities(),
                        on_attach = function(client, _)
                            client.server_capabilities.diagnosticProvider = false
                        end,
                    })
                    vim.lsp.enable(server_name)
                end,
            },
        },
    },

    {
        'WhoIsSethDaniel/mason-tool-installer.nvim',
        dependencies = {
            'williamboman/mason.nvim',
        },
        event = 'VeryLazy',
        opts = {
            ensure_installed = {
                'stylua',
                'ruff',
                'shfmt',
                'prettierd',
                'goimports',
                'gofumpt',
            },
            auto_update = false,
        },
    },

    {
        'neovim/nvim-lspconfig',
        event = 'VeryLazy',
        config = function()
            vim.api.nvim_create_autocmd('LspAttach', {
                group = vim.api.nvim_create_augroup('lsp-attach', { clear = true }),
                callback = function(event)
                    local map = function(keys, func, desc, mode)
                        mode = mode or 'n'
                        vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
                    end

                    map('<leader>d', vim.diagnostic.open_float, 'Show diagnostics float')
                    map('<leader>q', vim.diagnostic.setloclist, 'Diagnostics to loclist')
                    map('grn', vim.lsp.buf.rename, '[R]e[n]ame')
                    map('gra', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })
                    map('grr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
                    map('gri', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')
                    map('grd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')
                    map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')
                    map('grt', require('telescope.builtin').lsp_type_definitions, '[G]oto [T]ype Definition')
                    map('<C-k>', vim.lsp.buf.signature_help, 'Signature help')
                    map('gO', require('telescope.builtin').lsp_document_symbols, 'Open Document Symbols')
                    map('gW', require('telescope.builtin').lsp_dynamic_workspace_symbols, 'Open Workspace Symbols')

                    local client = vim.lsp.get_client_by_id(event.data.client_id)
                    client.server_capabilities.documentFormattingProvider = false
                end,
            })
        end,
    },

    {
        'stevearc/conform.nvim',
        cmd = { 'ConformFormat', 'ConformInfo' },
        keys = {
            {
                '<leader>f',
                function()
                    require('conform').format { async = true, lsp_format = 'fallback' }
                end,
                desc = '[F]ormat buffer',
            },
        },
        opts = {
            notify_on_error = true,
            formatters_by_ft = {
                lua = { 'stylua' },
                python = { 'ruff_format' },
                sh = { 'shfmt' },
                javascript = { 'prettierd' },
                javascriptreact = { 'prettierd' },
                css = { 'prettierd' },
                html = { 'prettierd' },
                json = { 'prettierd' },
                go = { 'goimports', 'gofumpt' },
            },
        },
    },

    {
        'saghen/blink.cmp',
        version = '1.*',
        event = { 'InsertEnter', 'CmdlineEnter' },
        dependencies = {
            {
                'L3MON4D3/LuaSnip',
                version = '2.*',
                build = (function()
                    if vim.fn.has 'win32' == 1 or vim.fn.executable 'make' == 0 then
                        return
                    end
                    return 'make install_jsregexp'
                end)(),
                opts = {},
            },
            'onsails/lspkind.nvim',
            'folke/lazydev.nvim',
        },
        opts = {
            keymap = {
                preset = 'default',
            },
            appearance = {
                nerd_font_variant = 'mono',
            },
            completion = {
                list = {
                    selection = {
                        preselect = true,
                        auto_insert = true,
                    },
                },
                documentation = {
                    auto_show = false,
                    auto_show_delay_ms = 500,
                },
            },
            sources = {
                default = { 'lsp', 'path', 'snippets', 'buffer', 'lazydev' },
                providers = {
                    lazydev = { module = 'lazydev.integrations.blink', score_offset = 100 },
                },
            },
            snippets = { preset = 'luasnip' },
            signature = { enabled = true },
            fuzzy = { implementation = 'prefer_rust_with_warning' },
        },
    },
}
