vim.loader.enable()
require 'options'
require 'keymaps'
require('gruvbox').apply_highlights()
require 'lazy-bootstrap'
require('lazy').setup {
    spec = {
        { import = 'plugins' },
    },
    checker = {
        enabled = true,
        notify = false,
    },
    change_detection = {
        notify = false,
    },
    rocks = {
        enabled = false,
        hererocks = false,
    },
    performance = {
        rtp = {
            disabled_plugins = {
                '2html_plugin',
                'getscript',
                'getscriptPlugin',
                'gzip',
                'logipat',
                'matchit',
                'tohtml',
                'loaded_remote_plugins',
                'loaded_tutor_mode_plugin',
                'rrhelper',
                'man',
                'spellfile',
                'tar',
                'tarPlugin',
                'vimball',
                'vimballPlugin',
                'zip',
                'tutor',
                'rplugin',
                'zipPlugin',
            },
        },
    },
}
require 'autocmds'
