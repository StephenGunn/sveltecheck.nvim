# sveltecheck.nvim

SvelteCheck is a Neovim plugin designed to run `svelte-check` asynchronously and load the results into the quickfix list for easy navigation through errors and warnings in Svelte projects.

## Features

- **Asynchronous Execution**: Runs `svelte-check` in the background without blocking Neovim.
- **Quickfix List Integration**: Directly populates the quickfix list with errors and warnings found.
- **Customizable**: Supports configuration to tweak the command to run and spinner animation frames.

## Installation

Ensure you have Neovim (0.5.0+) with Lua support enabled (`nvim --version` to check). Install using your favorite plugin manager:

### Using Plug (example)

```vim
Plug 'StephenGunn/SvelteCheck'
```

Then reload Neovim and run `:PlugInstall`.

## Usage

### Commands

- `:SvelteCheck`: Execute `pnpm run check` (default) asynchronously and load the results into the quickfix list.

### Configuration

You can customize the behavior of SvelteCheck by overriding default configurations in your `init.lua` (for Neovim's Lua configuration).

```lua
-- Example configuration
require('SvelteCheck').setup({
    command = "pnpm run check", -- Command to run for checking (default: "pnpm run check")
    spinner_frames = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" }, -- Frames for spinner animation
})
```

### Notifications and Status

SvelteCheck provides feedback during execution:

- **Spinner Animation**: Displays a spinner while `svelte-check` runs.
- **Notifications**: Uses Neovim's `vim.notify` to inform about the current operation.

## Contributing

Contributions are welcome! Feel free to open issues for bugs, suggestions, or improvements.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

```

This template provides comprehensive documentation for your SvelteCheck plugin on GitHub, covering installation, usage, configuration, notifications, contributing guidelines, and licensing information.
```
