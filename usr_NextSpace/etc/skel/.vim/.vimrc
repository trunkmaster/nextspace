set nocompatible      
set bs=2              " allow backspacing over everything in insert mode
set ai                " always set autoindenting on
" set paste
set backup            " keep a backup file
set viminfo='20,\"50  " read/write a .viminfo file, don't store more
                      " than 50 lines of registers
set history=50        " keep 50 lines of command line history
set ruler             " show the cursor position all the time
set hlsearch
" set expandtab         " replace tab with spaces
set smarttab
set tabstop=8
set shiftwidth=2
set softtabstop=2
set laststatus=2
"set guioptions=mr
set columns=82

let Tmenu_ctags_cmd = '/usr/bin/ctags-exuberant'

"****************************************************************************
"* Keys mapping
"****************************************************************************
map <F2>     :w<CR>
map <F3>     :e! 
map <S-F3>   :browse confirm e<CR>
map <F4>     :1,$s///g
map <C-F5>   :close<CR>
map <C-b>    :b
map <S-F11>  :buffers<CR>
map <F5>     :bp<CR>
map <F6>     :bn<CR>
map <F7>     :1,$!ispell -drussian -a
map <F8>     :cn<CR>
map <F9>     :w<CR>:make<CR>
map <M-F9>     :w<CR>:make install<CR>
map <S-F9>   :w<CR>:!make distclean<CR>
" map <F10>    :q<CR>
map <S-Up>   zc
map <S-Down> zo

"map <F6>   <C-W>p<C-W>_<C-W>r
"map <F4>   :!par j1<CR>
"map <F3> <C-W>n<C-W>_:edit
"noremap <F8> :so `vimspell.sh %`<CR><CR>
"noremap <F7> :syntax clear SpellErrors<CR>

"****************************************************************************
" Syntax highlighting
" most of moved into ~/.vim/after/syntax
"****************************************************************************
syntax enable
colorscheme darkblue
hi  Cursor        guibg=Magenta
hi  StatusLine    ctermbg=White ctermfg=DarkBlue guifg=#535353 guibg=white
hi  Visual        ctermbg=white ctermfg=DarkBlue guifg=#c5c5c5 guibg=black

set guifont=Liberation\ Mono\ 12

"****************************************************************************
" Folding
"****************************************************************************
set foldcolumn=2
set foldmethod=syntax
set foldopen=search
set foldnestmax=1
"set foldclose=all

"****************************************************************************
"* BufExplorer settings
"****************************************************************************
let g:bufExplorerShowRelativePath=1
let g:bufExplorerSortBy='name'

"****************************************************************************
"* Files settings
"****************************************************************************
if has("autocmd")
  filetype plugin indent on

  " Don't change the order, it's important that the line with * comes first.
  " When editing a file, always jump to the last cursor position
  au FileReadPost *     if line("'\"") | exe "'\"" | endif
  au FileType     *     set formatoptions=tcql nocindent comments&
  au BufRead      *.txt set tw=78

  " Objective C
  au BufRead,BufNewFile  *.m,*.h  set filetype=objc formatoptions=tcroql
  au BufRead,BufNewFile  *.m,*.h  set indentkeys=0{,0},:,0#,!<tab> cindent
  au BufRead,BufNewFile  *.m,*.h  set cinoptions={1s,>2s,:1s,n-2,(0,^-2
  au BufRead,BufNewFile  *.m,*.h  set comments=sr:/*,mb:*,ex:*/,://

  " C/C++
  au BufRead,BufNewFile  *.c,*.cpp set formatoptions=tcroql
  au BufRead,BufNewFile  *.c,*.cpp set cinkeys=0{,0},:,0#,!<tab> cindent 
  au BufRead,BufNewFile  *.c,*.cpp set comments=sr:/*,mb:*,el:*/,://

endif

