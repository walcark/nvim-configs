## Configuration files for Neovim

This folder contains all my configurations for [Neovim](https://neovim.io/).

## My Neovim configuration journey

I had the opportunity to start learning neovim with [NvChad](https://nvchad.com/) for which configuration was not beginner-friendly because of the package-specific Lua syntax. I decided to abandon this configuration because I found it hard to customize for a newcomer.

Then, I switched to [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) which is thought to be a good starting point for neovim because of its well documented single-file configuration. 

Finally, I tried [AstroNvim](https://github.com/astronvim/astronvim), and really liked it from the start. It is really simple to configure, has an [extensive community plugins repository](https://github.com/AstroNvim/astrocommunity) that allows to easily install packs of plugins. This community repository has solutions for many issues encountered in neovim. However, I feel like those plugins are a bit too _rigid_, as you have to copy them in your configuration file rather than import them if you wish to modify their behaviour. I feel like they are a good starting point but lack versatility if you really wish to have a fully-customized configuration.

This is why I am thinking about trying [mini.nvim](https://github.com/nvim-mini/mini.nvim), a lightweight library of independent Lua modules that enhance Neovim with minimal interdependencies between each module. Indeed, as a user that does not visit my neovim configuration files every day, I found that all the neovim libraries that I tested always introduced repetition and interdependencies between modules, making it hard to easily locate the cause of a problem I experience when using neovim.

## Roadmap

- [ ] Try [mini.nvim](https://github.com/nvim-mini/mini.nvim)
