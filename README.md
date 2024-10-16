# dbt-nvim: be a more efficient Analytics Engineer

A neovim plugin that gives you shortcuts to do everyday tasks in dbt.

![demo_show_results_preview](https://github.com/user-attachments/assets/1ef34f0c-3bf6-47c0-a82a-15549acdb0f5)

[Video demo](https://youtu.be/LB6GXFVRNDw)

Current features:

- show full query results in markdown table for current buffer

## Requirements

- Temporary solution for query execution: add this package to your dbt project: [alhankeser/dbt_nvim](https://github.com/alhankeser/dbt_nvim)

## Installation

With lazy.nvim:
```lua
  {
    dir = 'alhankeser/dbt-nvim',
    config = function()
      require('dbt-nvim').setup {
        venv_path = '.venv', --path to your .venv, used for calling dbt
        split_direction = 'horizontal', --where to open query results. other option is vertical
        limit = 100, --max number of results to return. limit n gets appended to any query that is run
        do_create_file = false, --whether a markdown file should be created for the query results e.g. targets/dbt-nvim/stg_orders.md
      }
    end,
  },
```

## Usage

In normal mode:
```
:lua require"dbt-nvim".show()
```

A keymap idea:
```
vim.keymap.set('n', '<leader>q', '<cmd>lua require("dbt-nvim").show()<CR>')
```

