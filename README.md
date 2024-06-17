# sveltecheck.nvim

A Neovim plugin that runs `svelte-check` asynchronously, displays a spinner while running, and populates the quickfix list with the results.

## Installation

### Using `lazy.nvim`

1. Ensure `lazy.nvim` is set up in your Neovim configuration.
2. Add the plugin to your plugin list:

```lua
-- lazy.nvim plugin configuration
require('lazy').setup({
    {
        'StephenGunn/sveltecheck.nvim',
        config = function()
            require('svelte-check').setup({
                command = "pnpm run check", -- Default command for pnpm
            })
        end,
    },
})
```

### Using `packer.nvim`

1. Ensure `packer.nvim` is set up in your Neovim configuration.
2. Add the plugin to your plugin list:

```lua
-- packer.nvim plugin configuration
return require('packer').startup(function(use)
    use {
        'StephenGunn/sveltecheck.nvim',
        config = function()
            require('svelte-check').setup({
                command = "pnpm run check", -- Default command for pnpm
            })
        end
    }

    -- Add other plugins as needed
end)
```

## Usage

After installation, run the `svelte-check` command in Neovim:

```vim
:SvelteCheck
```

This command will start the `svelte-check` process, display a spinner, and populate the quickfix list with any errors or warnings found. A summary of the check will be printed upon completion.

## Customization

Customize the plugin by passing configuration options to the `setup` function. The available option is:

- `command` (string): The command to run `svelte-check` (default: `"pnpm run check"`).

### Example Customization

```lua
require('svelte-check').setup({
    command = "npm run svelte-check", -- Custom command for npm
})
```

### Using with `lazy.nvim` and `packer.nvim`

**`lazy.nvim` Customization Example:**

```lua
require('lazy').setup({
    {
        'StephenGunn/sveltecheck.nvim',
        config = function()
            require('svelte-check').setup({
                command = "npm run svelte-check",
            })
        end,
    },
})
```

**`packer.nvim` Customization Example:**

```lua
return require('packer').startup(function(use)
    use {
        'StephenGunn/sveltecheck.nvim',
        config = function()
            require('svelte-check').setup({
                command = "npm run svelte-check",
            })
        end
    }

    -- Add other plugins as needed
end)
```
