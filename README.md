# sveltecheck.nvim

Run `svelte-check` asynchronously in your Svelte project with Neovim and see the results in the quick fix list.

To run, use the `:SvelteCheck` command.

## Installation

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'StephenGunn/sveltecheck-nvim'
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use 'StephenGunn/sveltecheck-nvim'
```

### Using [Lazy](https://github.com/folke/lazy.nvim)

```lua
require('lazy').set({
  {
    'StephenGunn/sveltecheck-nvim',
    config = function()
      require('plugins.svelte_check')({
        command = "npm run check", -- Override default command if needed
      })
    end
  },
  -- Add your other plugins here
})
```

## Configuration

The plugin supports the following configuration options:

- `command`: The command to execute for checking the SvelteKit project (default: "pnpm run check").

## Usage

Once installed and configured, use the following command in Neovim to run the SvelteCheck:

```vim
:SvelteCheck
```

This command will trigger the configured command and populate the quickfix list with any errors found.

## License

This plugin is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

```

### Instructions

- Copy the entire block above (including all lines starting from `# SvelteCheck Neovim Plugin` to the last line with `details.`) and paste it into your text editor or directly into your `README.md` file.
- Modify the placeholders like `yourusername/sveltecheck-nvim` with your actual repository details and URLs as needed.

This content is ready to be copied and used directly in your `README.md` file without any additional formatting or escaping.
```
