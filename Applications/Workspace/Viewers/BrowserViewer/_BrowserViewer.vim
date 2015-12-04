let SessionLoad = 1
if &cp | set nocp | endif
let s:cpo_save=&cpo
set cpo&vim
map  <F9>
map  <S-F9>
map 	 <M-F9>
map  <M-F9>
map  :w
nmap \o <Plug>GnuchlogOpen
nmap gx <Plug>NetrwBrowseX
nnoremap <silent> <Plug>NetrwBrowseX :call netrw#NetrwBrowseX(expand("<cWORD>"),0)
map <S-Down> zo
map <S-Up> zc
map <Nul> :set foldmethod=manual
map <C-#> :set foldmethod=syntax
map <C-F10> :close
map <F10> :q
map <S-F9> :w:make distclean
map <M-F9> :w:make install
map <F9> :w:make
map <F8> :cn
map <F7> :1,$!ispell -drussian -a
map <F6> :bn
map <F5> :bp
map <C-Tab> 
map <C-F12> :BufExplorer
map <F4> :1,$s///g
map <S-F3> :browse confirm e
map <F3> :e!
map <F2> :w
let &cpo=s:cpo_save
unlet s:cpo_save
set autoindent
set background=dark
set backspace=2
set backup
set cindent
set cinoptions={1s,>2s,:1s,n-2,(0,^-2
set comments=sr:/*,mb:*,ex:*/,://
set foldopen=search
set formatoptions=tcroql
set guicursor=n-v-c:block-Cursor/lCursor,ve:ver35-Cursor,o:hor50-Cursor,i-ci:ver25-Cursor/lCursor,r-cr:hor20-Cursor/lCursor,sm:block-Cursor-blinkwait175-blinkoff150-blinkon175,a:blinkon0
set guifont=Liberation\ Mono\ 9
set history=50
set hlsearch
set indentkeys=0{,0},:,0#,!<tab>
set laststatus=2
set ruler
set shiftwidth=2
set smarttab
set softtabstop=2
set viminfo='20,\"50
set visualbell
set window=58
let s:so_save = &so | let s:siso_save = &siso | set so=0 siso=0
let v:this_session=expand("<sfile>:p")
silent only
cd /Developer/Sources/CUBE/Applications/Workspace/Viewers/BrowserViewer
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
set shortmess=aoO
badd +48 BrowserViewer.h
badd +296 BrowserViewer.m
badd +1 BrowserViewerBrowser.h
badd +46 BrowserViewerBrowser.m
badd +62 ../../Protocols/Viewer.h
badd +231 ../IconsViewer/IconsViewer.m
badd +1 \[BufExplorer]
args \[BufExplorer]
edit BrowserViewer.m
set splitbelow splitright
set nosplitbelow
set nosplitright
wincmd t
set winheight=1 winwidth=1
argglobal
setlocal keymap=
setlocal noarabic
setlocal autoindent
setlocal balloonexpr=
setlocal nobinary
setlocal bufhidden=
setlocal buflisted
setlocal buftype=
setlocal cindent
setlocal cinkeys=0{,0},0),:,0#,!^F,o,O,e
setlocal cinoptions={1s,>2s,:1s,n-2,(0,^-2
setlocal cinwords=if,else,while,do,for,switch
setlocal colorcolumn=
setlocal comments=sr:/*,mb:*,ex:*/,://
setlocal commentstring=/*%s*/
setlocal complete=.,w,b,u,t,i
setlocal concealcursor=
setlocal conceallevel=0
setlocal completefunc=
setlocal nocopyindent
setlocal cryptmethod=
setlocal nocursorbind
setlocal nocursorcolumn
setlocal nocursorline
setlocal define=
setlocal dictionary=
setlocal nodiff
setlocal equalprg=
setlocal errorformat=
setlocal noexpandtab
if &filetype != 'objc'
setlocal filetype=objc
endif
set foldcolumn=2
setlocal foldcolumn=2
setlocal foldenable
setlocal foldexpr=0
setlocal foldignore=#
setlocal foldlevel=0
setlocal foldmarker={{{,}}}
set foldmethod=syntax
setlocal foldmethod=syntax
setlocal foldminlines=1
set foldnestmax=1
setlocal foldnestmax=1
setlocal foldtext=foldtext()
setlocal formatexpr=
setlocal formatoptions=tcroql
setlocal formatlistpat=^\\s*\\d\\+[\\]:.)}\\t\ ]\\s*
setlocal grepprg=
setlocal iminsert=2
setlocal imsearch=2
setlocal include=
setlocal includeexpr=
setlocal indentexpr=GetObjCIndent()
setlocal indentkeys=0{,0},:,0#,!<tab>
setlocal noinfercase
setlocal iskeyword=@,48-57,_,192-255
setlocal keywordprg=
setlocal nolinebreak
setlocal nolisp
setlocal nolist
setlocal makeprg=
setlocal matchpairs=(:),{:},[:]
setlocal modeline
setlocal modifiable
setlocal nrformats=octal,hex
setlocal nonumber
setlocal numberwidth=4
setlocal omnifunc=ccomplete#Complete
setlocal path=
setlocal nopreserveindent
setlocal nopreviewwindow
setlocal quoteescape=\\
setlocal noreadonly
setlocal norelativenumber
setlocal norightleft
setlocal rightleftcmd=search
setlocal noscrollbind
setlocal shiftwidth=2
setlocal noshortname
setlocal nosmartindent
setlocal softtabstop=2
setlocal nospell
setlocal spellcapcheck=[.?!]\\_[\\])'\"\	\ ]\\+
setlocal spellfile=
setlocal spelllang=en
setlocal statusline=
setlocal suffixesadd=
setlocal swapfile
setlocal synmaxcol=3000
if &syntax != 'objc'
setlocal syntax=objc
endif
setlocal tabstop=8
setlocal tags=
setlocal textwidth=0
setlocal thesaurus=
setlocal noundofile
setlocal nowinfixheight
setlocal nowinfixwidth
setlocal wrap
setlocal wrapmargin=0
123
normal! zo
147
normal! zo
225
normal! zo
280
normal! zo
323
normal! zo
337
normal! zo
402
normal! zo
430
normal! zo
483
normal! zo
494
normal! zo
512
normal! zo
let s:l = 324 - ((44 * winheight(0) + 29) / 58)
if s:l < 1 | let s:l = 1 | endif
exe s:l
normal! zt
324
normal! 0
tabnext 1
if exists('s:wipebuf')
  silent exe 'bwipe ' . s:wipebuf
endif
unlet! s:wipebuf
set winheight=1 winwidth=20 shortmess=filnxtToO
let s:sx = expand("<sfile>:p:r")."x.vim"
if file_readable(s:sx)
  exe "source " . fnameescape(s:sx)
endif
let &so = s:so_save | let &siso = s:siso_save
doautoall SessionLoadPost
unlet SessionLoad
" vim: set ft=vim :
