-- https://github.com/wbthomason/packer.nvim/blob/6afb67460283f0e990d35d229fd38fdc04063e0a/README.md#bootstrapping
local ensure_packer = function()
  local fn = vim.fn
  local install_path = fn.stdpath('data')..'/site/pack/packer/start/packer.nvim'
  if fn.empty(fn.glob(install_path)) > 0 then
    fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
    vim.cmd [[packadd packer.nvim]]
    return true
  end
  return false
end

local packer_bootstrap = ensure_packer()

return require('packer').startup(function(use)
  -- LSP
  use 'prabirshrestha/async.vim'
  use 'prabirshrestha/asyncomplete.vim'
  use 'prabirshrestha/asyncomplete-lsp.vim'
  use 'prabirshrestha/vim-lsp'
  use 'mattn/vim-lsp-settings'
  use 'mattn/vim-lsp-icons'

  use 'itchyny/lightline.vim'
  use 'airblade/vim-gitgutter'
  use 'flazz/vim-colorschemes'
  use {'tpope/vim-commentary', cmd = {'Commentary'} }
  use 'cohama/lexima.vim'
  use {'tpope/vim-fugitive', cmd = {'Git'} }
  use {'thinca/vim-quickrun', cmd = {'QuickRun'} }
  use 'tyru/open-browser.vim'
  use {'tyru/open-browser-github.vim', cmd = {'OpenGithubFile'} }

  use {'junegunn/fzf', run = function() vim.fn['fzf#install'](0) end }
  use 'junegunn/fzf.vim'

  -- TOML
  use {'cespare/vim-toml', ft = 'toml' }

  -- Protocol Buffers
  use {'uber/prototool', ft = 'proto' }

  -- Golang
  use {'mattn/vim-goimports', ft = 'go' }

  -- TypeScript
  -- use {'leafgarland/typescript-vim', ft = 'typescript' }
  use {'peitalin/vim-jsx-typescript', ft = 'typescript' }

  -- Coffee
  use {'kchmck/vim-coffee-script', ft = 'coffee' }

  -- Re:View
  use {'tokorom/vim-review', ft = 're' }

  -- Swift
  use {'keith/swift.vim', ft = 'swift' }

  -- Kotlin
  use {'udalov/kotlin-vim', ft = 'kotolin' }

  -- Terraform
  use {'hashivim/vim-terraform', ft = 'terraform' }

  -- Ocaml
  use {'ocaml/vim-ocaml', ft = 'ocaml' }

  -- Haskell
  use {'alx741/vim-hindent', ft = 'haskell'}

  use {'rizzatti/dash.vim'}

  use {'chr4/nginx.vim', ft = 'nginx' }
  use {'chrismaher/vim-lookml'}

  use {'jparise/vim-graphql', ft = {'typescript', 'graphql'} }

  use {'rust-lang/rust.vim', ft = 'rust' }

  use {'editorconfig/editorconfig-vim'}
  use {'preservim/nerdtree'}
  use {'github/copilot.vim'}

  if packer_bootstrap then
    require('packer').sync()
  end
end)
