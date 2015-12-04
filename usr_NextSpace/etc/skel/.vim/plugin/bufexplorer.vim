"=============================================================================
"    Copyright: Copyright (C) 2001-2007 Jeff Lanzarotta
"               Permission is hereby granted to use and distribute this code,
"               with or without modifications, provided that this copyright
"               notice is copied with it. Like anything else that's free,
"               bufexplorer.vim is provided *as is* and comes with no
"               warranty of any kind, either expressed or implied. In no
"               event will the copyright holder be liable for any damages
"               resulting from the use of this software.
" Name Of File: bufexplorer.vim
"  Description: Buffer Explorer Vim Plugin
"   Maintainer: Jeff Lanzarotta (delux256-vim at yahoo dot com)
" Last Changed: Friday, 27 April 2007
"      Version: See g:loaded_bufexplorer for version number.
"        Usage: Normally, this file should reside in the plugins
"               directory and be automatically sourced. If not, you must
"               manually source this file using ':source bufexplorer.vim'.
"
"               You may use the default keymappings of
"
"                 <Leader>be  - Opens BufExplorer
"                 <Leader>bs  - Opens split window BufExplorer
"                 <Leader>bv  - Opens vertical split window BufExplorer
"
"               Or you can use
"
"                 ":BufExplorer" - Opens BufExplorer
"                 ":SBufExplorer" - Opens split window BufExplorer
"                 ":VSBufExplorer" - Opens vertical split window BufExplorer
"
"               For more help see supplied documentation.
"      History: See supplied documentation.
"=============================================================================

" Exit quickly when BufExplorer has already been loaded or when 'compatible'
" is set.
if exists("g:loaded_bufexplorer") || &cp
  finish
endif

" Version number.
let g:loaded_bufexplorer = "7.0.15"

" Check to make sure the Vim version 700 or greater.
if v:version < 700
  echo "Sorry, bufexplorer ".g:loaded_bufexplorer."\nONLY runs with Vim 7.0 and greater"
  finish
endif

" Set {{{1
function s:Set(var, default)
  if !exists(a:var)
    if type(a:default)
      exec "let" a:var "=" string(a:default)
    else
      exec "let" a:var "=" a:default
    endif

    return 1
  endif

  return 0
endfunction
"1}}}

" Set Defaults.
call s:Set("g:bufExplorerDefaultHelp", 1) " Show default help?
call s:Set("g:bufExplorerDetailedHelp", 0) " Show detailed help?
call s:Set("g:bufExplorerReverseSort", 0) " Sort reverse?
call s:Set("g:bufExplorerShowDirectories", 1) " Show directories? (Dir's are added by commands like ':e .')
call s:Set("g:bufExplorerShowRelativePath", 0) " Show listings with relative or absolute paths?
call s:Set("g:bufExplorerSortBy", "mru") " Sorting methods are in s:sort_by:
call s:Set("g:bufExplorerSplitBelow", &splitbelow) " Show horizontal splits below or above?
call s:Set("g:bufExplorerSplitHorzSize", 0) " Height for a horizontal split.
call s:Set("g:bufExplorerSplitOutPathName", 1) " Split out path and file name?
call s:Set("g:bufExplorerSplitRight", &splitright) " Show vertical splits right or left?
call s:Set("g:bufExplorerSplitVertical", 0) " Show splits horizontal or vertical?
call s:Set("g:bufExplorerSplitVertSize", 0) " Height for a vertical split.
call s:Set("g:bufExplorerUseCurrentWindow", 0) " Open selected buffer in current or new window.
let s:sort_by = ["number", "name", "fullpath", "mru", "extension"]

" Setup the autocommands that handle the MRUList and other stuff. {{{1
augroup bufexplorer
  autocmd!
  autocmd BufNew * call <SID>MRUPush()
  autocmd BufEnter * call <SID>MRUPush()
  autocmd BufEnter * call <SID>SetAltBufName()
  autocmd BufDelete * call <SID>MRUPop()
  autocmd BufWinEnter \[BufExplorer\] call <SID>Initialize()
  autocmd BufWinLeave \[BufExplorer\] call <SID>Cleanup()
  autocmd VimEnter * call <SID>BuildMRU()
augroup End

" Create commands {{{1
command BufExplorer :call <SID>StartBufExplorer("drop")
command SBufExplorer  :call <SID>StartBufExplorer("sp")
command VSBufExplorer :call <SID>StartBufExplorer("vsp")

" Public Interfaces {{1
map <silent> <unique> <Leader>be :BufExplorer<CR>
map <silent> <unique> <Leader>bs :SBufExplorer<CR>
map <silent> <unique> <Leader>bv :VSBufExplorer<CR>

let s:MRUList = []
let s:running = 0

" Winmanager Integration {{{1
let g:BufExplorer_title = "\[Buf\ List\]"
call s:Set("g:bufExplorerResize", 1)
call s:Set("g:bufExplorerMaxHeight", 25) " Handles dynamic resizing of the window.

" Function to start display. Set the mode to 'winmanager' for this buffer.
" This is to figure out how this plugin was called. In a standalone fashion
" or by winmanager.
function BufExplorer_Start()
  let b:displayMode = "winmanager"
  call s:StartBufExplorer("e")
endfunction

" Returns whether the display is okay or not.
function BufExplorer_IsValid()
  return 0
endfunction

" Handles dynamic refreshing of the window.
function BufExplorer_Refresh()
  let b:displayMode = "winmanager"
  call s:StartBufExplorer("e")
endfunction

" BufExplorer_ReSize.
function BufExplorer_ReSize()
  if !g:bufExplorerResize
    return
  end

  let nlines = min([line("$"), g:bufExplorerMaxHeight])

  exe nlines." wincmd _"

  " The following lines restore the layout so that the last file line is also
  " the last window line. Sometimes, when a line is deleted, although the
  " window size is exactly equal to the number of lines in the file, some of
  " the lines are pushed up and we see some lagging '~'s.
  let pres = getpos(".")

  exe $

  let _scr = &scrolloff
  let &scrolloff = 0

  normal! z-

  let &scrolloff = _scr

  call setpos(".", pres)
endfunction

" Initialize {{{1
function s:Initialize()
  let s:_insertmode = &insertmode
  set noinsertmode

  let s:_showcmd = &showcmd
  set noshowcmd

  let s:_cpo = &cpo
  set cpo&vim

  let s:_report = &report
  let &report = 10000

  let s:_list = &list
  set nolist

  setlocal nonumber
  setlocal foldcolumn=0
  setlocal nofoldenable
  setlocal cursorline
  setlocal nospell

  set nobuflisted

  let s:running = 1
endfunction

" Cleanup {{{1
function s:Cleanup()
  let &insertmode = s:_insertmode
  let &showcmd = s:_showcmd
  let &cpo = s:_cpo
  let &report = s:_report
  let &list = s:_list
  let s:running = 0

  delmarks!
endfunction

" StartBufExplorer {{{1
function s:StartBufExplorer(open)
  let name = '[BufExplorer]'

  if !has("win32")
    " On non-Windows boxes, escape the name so that is shows up correctly.
    let name = escape(name, "[]")
  endif

  " Make sure there is only one explorer open at a time.
  if s:running == 1
    " Go to the open buffer.
    if has("gui")
      exec "drop" name
    end

    return
  endif

  silent let s:raw_buffer_listing = s:GetBufferList()

  if len(s:raw_buffer_listing) < 2
    echo "\r"
    call s:Warn("Sorry, there are no more buffers to explore")

    return
  endif

  " Get the alternate buffer number for later, just in case
  let nr = bufnr("#")
  if buflisted(nr)
    let s:altBufNbr = nr
  endif

  let s:numberOfOpenWindows = winnr("$")
  let s:MRUListSaved = copy(s:MRUList)

  if !exists("b:displayMode") || b:displayMode != "winmanager"
    " Do not use keepalt when opening bufexplorer to allow the buffer that we
    " are leaving to become the new alternate buffer
    call s:SplitOpen("silent ".a:open." ".name)

    let s:splitWindow = winnr("$") > s:numberOfOpenWindows

    if s:splitWindow
      " Resize
      let [s, c] = (a:open =~ "v") ? [g:bufExplorerSplitVertSize, "|"] : [g:bufExplorerSplitHorzSize, "_"]

      if (s > 0)
        exe s "wincmd" c
      endif
    endif
  else
    let s:splitWindow = winnr("$") > s:numberOfOpenWindows
  endif

  call s:DisplayBufferList()
endfunction

" DisplayBufferList {{{1
function s:DisplayBufferList()
  setlocal bufhidden=delete
  setlocal buftype=nofile
  setlocal modifiable
  setlocal noswapfile
  setlocal nowrap

  call s:SetupSyntax()
  call s:MapKeys()
  call setline(1, s:CreateHelp())
  call s:BuildBufferList()
  call cursor(s:firstBufferLine, 1)

  if !g:bufExplorerResize
    normal! zz
  endif

  setlocal nomodifiable
endfunction

" MapKeys {{{1
function s:MapKeys()
  if exists("b:displayMode") && b:displayMode == "winmanager"
    nnoremap <buffer> <silent> <tab> :call <SID>SelectBuffer(1)<cr>
  endif

  nnoremap <buffer> <silent> <F1> :call <SID>ToggleHelp()<cr>
  nnoremap <buffer> <silent> <2-leftmouse> :call <SID>SelectBuffer(0)<cr>
  nnoremap <buffer> <silent> <cr> :call <SID>SelectBuffer(0)<cr>
  nnoremap <buffer> <silent> d :call <SID>DeleteBuffer()<cr>
  nnoremap <buffer> <silent> m :call <SID>MRUListShow()<cr>

  if s:splitWindow == 1
    nnoremap <buffer> <silent> o :call <SID>ToggleOpenMode()<cr>
  endif

  nnoremap <buffer> <silent> p :call <SID>ToggleSplitOutPathName()<cr>
  nnoremap <buffer> <silent> q :call <SID>Close()<cr>
  nnoremap <buffer> <silent> r :call <SID>SortReverse()<cr>
  nnoremap <buffer> <silent> R :call <SID>ToggleShowRelativePath()<cr>
  nnoremap <buffer> <silent> s :call <SID>SortSelect()<cr>
  nnoremap <buffer> <silent> S :call <SID>SelectBuffer(1)<cr>
  nnoremap <buffer> <silent> t :call <SID>ToggleSplitType()<cr>

  for k in ["G", "n", "N", "L", "M", "H"]
    exec "nnoremap <buffer> <silent>" k ":keepjumps normal!" k."<cr>"
  endfor
endfunction

" SetupSyntax {{{1
function s:SetupSyntax()
  if has("syntax")
    syn match bufExplorerHelp     "^\".*" contains=bufExplorerSortBy,bufExplorerMapping,bufExplorerTitle,bufExplorerSortType,bufExplorerToggleSplit,bufExplorerToggleOpen
    syn match bufExplorerOpenIn   "Open in \w\+ window" contained
    syn match bufExplorerSplit    "\w\+ split" contained
    syn match bufExplorerSortBy   "Sorted by .*" contained contains=bufExplorerOpenIn,bufExplorerSplit
    syn match bufExplorerMapping  "\" \zs.\+\ze :" contained
    syn match bufExplorerTitle    "Buffer Explorer.*" contained
    syn match bufExplorerSortType "'\w\{-}'" contained
    syn match bufExplorerBufNbr   /^\s*\d\+/
    syn match bufExplorerToggleSplit  "toggle split type" contained
    syn match bufExplorerToggleOpen   "toggle open mode" contained

    syn match bufExplorerModBuf    /^\s*\d\+.\{4}+.*/
    syn match bufExplorerLockedBuf /^\s*\d\+.\{3}[\-=].*/
    syn match bufExplorerHidBuf    /^\s*\d\+.\{2}h.*/
    syn match bufExplorerActBuf    /^\s*\d\+.\{2}a.*/
    syn match bufExplorerCurBuf    /^\s*\d\+.%.*/
    syn match bufExplorerAltBuf    /^\s*\d\+.#.*/

    hi def link bufExplorerBufNbr Number
    hi def link bufExplorerMapping NonText
    hi def link bufExplorerHelp Special
    hi def link bufExplorerOpenIn Identifier
    hi def link bufExplorerSortBy String
    hi def link bufExplorerSplit NonText
    hi def link bufExplorerTitle NonText
    hi def link bufExplorerSortType bufExplorerSortBy
    hi def link bufExplorerToggleSplit bufExplorerSplit
    hi def link bufExplorerToggleOpen bufExplorerOpenIn

    hi def link bufExplorerActBuf Identifier
    hi def link bufExplorerAltBuf String
    hi def link bufExplorerCurBuf Type
    hi def link bufExplorerHidBuf Constant
    hi def link bufExplorerLockedBuf Special
    hi def link bufExplorerModBuf Exception
  endif
endfunction

" GetHelpStatus {{{1
function s:GetHelpStatus()
  let h = '" Sorted by '.((g:bufExplorerReverseSort == 1) ? "reverse " : "").g:bufExplorerSortBy

  if s:splitWindow == 1
    if g:bufExplorerUseCurrentWindow == 1
      let h .= ' | Open in Same window'
    else
      let h .= ' | Open in New window'
    endif
  endif

  if g:bufExplorerSplitVertical
    let h .= ' | Vertical split'
  else
    let h .= ' | Horizontal split'
  endif

  return h
endfunction

" CreateHelp {{{1
function s:CreateHelp()
  if g:bufExplorerDefaultHelp == 0 && g:bufExplorerDetailedHelp == 0
    let s:firstBufferLine = 1
    return []
  endif

  let header = []

  if g:bufExplorerDetailedHelp == 1
    call add(header, '" Buffer Explorer ('.g:loaded_bufexplorer.')')
    call add(header, '" --------------------------')
    call add(header, '" <F1> : toggle this help')
    call add(header, '" <enter> or Mouse-Double-Click : open buffer under cursor')
    call add(header, '" S : open buffer under cursor in new split window')
    call add(header, '" d : delete buffer')

    if s:splitWindow == 1
      call add(header, '" o : toggle open mode')
    endif

    call add(header, '" p : toggle spliting of file and path name')
    call add(header, '" q : quit')
    call add(header, '" r : reverse sort')
    call add(header, '" R : toggle showing relative or full paths')
    call add(header, '" s : select sort field '.string(s:sort_by).'')
    call add(header, '" t : toggle split type')
  else
    call add(header, '" Press <F1> for Help')
  endif

  call add(header, s:GetHelpStatus())

  call add(header, '"=')
  let s:firstBufferLine = len(header) + 1

  return header
endfunction

" GetBufferList {{{1
function s:GetBufferList()
  redir => bufoutput
  buffers
  redir END

  let bufs = split(bufoutput, '\n')
  let [all, widths, s:maxWidths] = [[], {}, {}]
  let s:types = ["fullname", "relativename", "relativepath", "path", "shortname"]
  for n in s:types
    let widths[n] = []
  endfor

  for buf in bufs
    let b = {}
    let bufName = matchstr(buf, '"\zs.\+\ze"')
    let nameonly = fnamemodify(bufName, ":t")

    if (nameonly =~ '^\[.\+\]')
      let b["relativename"] = nameonly
      let b["fullname"] = nameonly
      let b["shortname"] = nameonly
      let b["relativepath"] = ""
      let b["path"] = ""
    else
      let b["relativename"] = fnamemodify(bufName, ':~:.')
      let b["fullname"] = fnamemodify(bufName, ":p")

      if getftype(b["fullname"]) == "dir" && g:bufExplorerShowDirectories == 1
        let b["shortname"] = "<DIRECTORY>"
      else
        let b["shortname"] = fnamemodify(bufName, ":t")
      end

      let b["relativepath"] = fnamemodify(b["relativename"], ':h')
      let b["path"] = fnamemodify(b["fullname"], ":h")
    endif

    let b["attributes"] = matchstr(buf, '^\zs.\{-1,}\ze"')
    let b["line"] = matchstr(buf, 'line \d\+')

    call add(all, b)

    for n in s:types
      call add(widths[n], len(b[n]))
    endfor
  endfor

  for n in s:types
    let s:maxWidths[n] = max(widths[n])
  endfor

  return all
endfunction

" BuildBufferList {{{1
function s:BuildBufferList()
  let lines = []
  let pads = {}

  for n in s:types
    let pads[n] = repeat(' ', s:maxWidths[n])
  endfor

  " Loop through every buffer.
  for buf in s:raw_buffer_listing
    let line = buf["attributes"]." "

    if g:bufExplorerSplitOutPathName
      let type = (g:bufExplorerShowRelativePath) ? "relativepath" : "path"
      let path = buf[type]
      let line .= buf["shortname"]." ".strpart(pads["shortname"].path, len(buf["shortname"]))
    else
      let type = (g:bufExplorerShowRelativePath) ? "relativename" : "fullname"
      let path = buf[type]
      let line .= path
    endif

    if !empty(pads[type])
      let line .= strpart(pads[type], len(path))." "
    endif

    let line .= buf["line"]

    call add(lines, line)
  endfor

  call setline(s:firstBufferLine, lines)

  call s:SortListing()
endfunction

" SelectBuffer {{{1
function s:SelectBuffer(split)
  " Sometimes messages are not cleared when we get here so it looks like an
  " error has occurred when it really has not.
  echo ""

  " Are we on a line with a file name?
  if line('.') < s:firstBufferLine
    exec "normal! \<cr>"
    return
  endif

  let _bufNbr = str2nr(getline('.'))

  if exists("b:displayMode") && b:displayMode == "winmanager"
    let bufname = expand("#"._bufNbr.":p")

    call WinManagerFileEdit(bufname, a:split)

    return
  end

  if bufexists(_bufNbr)
    let ka = "keepalt"

    if (g:bufExplorerUseCurrentWindow && s:splitWindow) || (!s:splitWindow && a:split)
      " we will return to the previous buffer before opening the new one, so
      " be sure to not use the keepalt modifier
      silent bd!
      let ka = ""
    endif

    if bufnr("#") == _bufNbr
      " we are about to set the % # buffers to the same thing, so open the
      " original alt buffer first to restore it. This only happens when
      " selecting the current (%) buffer.
      try
        exe "keepjumps silent b!" s:altBufNbr
      catch
      endtry

      let ka = ""
    endif

    let cmd = (a:split) ? (g:bufExplorerSplitVertical == 1) ? "vert sb" : "sb" : "b!"
    call s:SplitOpen(ka." keepjumps silent ".cmd." "._bufNbr)
  else
    call s:Error("Sorry, that buffer no longer exists, please select another")
    call s:RemoveBuffer(_bufNbr)
  endif
endfunction

" RemoveBuffer {{{1
function s:RemoveBuffer(buf)
  " This routine assumes that the buffer to be removed is on the current line
  try
    exe "silent bw ".a:buf

    setlocal modifiable
    " "_dd does not move the cursor (d _ does)
    normal! "_dd
    setlocal nomodifiable

    call s:MRUPop(a:buf)

    " Delete the buffer from the raw buffer list
    call filter(s:raw_buffer_listing, 'v:val["attributes"] !~ " '.a:buf.' "')
  catch
    call s:Error(v:exception)
  endtry
endfunction

" SplitOpen {{{1
function s:SplitOpen(cmd)
  let [_splitbelow, _splitright] = [&splitbelow, &splitright]
  let [&splitbelow, &splitright] = [g:bufExplorerSplitBelow, g:bufExplorerSplitRight]

  exe a:cmd

  let [&splitbelow, &splitright] = [_splitbelow, _splitright]
endfunction

" DeleteBuffer {{{1
function s:DeleteBuffer()
  " Are we on a line with a file name?
  if line('.') < s:firstBufferLine
    return
  endif

  " Do not allow this buffer to be deleted if it is the last one.
  if len(s:MRUList) == 1
    call s:Error("Sorry, you are not allowed to delete the last buffer")

    return
  endif

  " These commands are to temporarily suspend the activity of winmanager.
  if exists("b:displayMode") && b:displayMode == "winmanager"
    call WinManagerSuspendAUs()
  end

  let _bufNbr = str2nr(getline('.'))

  if getbufvar(_bufNbr, '&modified') == 1
    call s:Error("Sorry, no write since last change for buffer "._bufNbr.", unable to delete")
  else
    call s:RemoveBuffer(_bufNbr)
  endif

  " Reactivate winmanager autocommand activity.
  if exists("b:displayMode") && b:displayMode == "winmanager"
    call WinManagerForceReSize("BufExplorer")
    call WinManagerResumeAUs()
  end
endfunction

" Close {{{1
function s:Close()
  let alt = bufnr("#")

  if (s:numberOfOpenWindows > 1 && !s:splitWindow)
    " if we "bw" in this case, then the previously existing split will be
    " lost, so open the most recent item in the MRU list instead.
    for b in s:MRUListSaved
      try
        exec "silent b" b
        break
      catch
      endtry
    endfor
  else
    " If this is the only window, then let Vim choose the buffer to go to.
    bw!
  endif

  if (alt == bufnr("%"))
    " This condition is true most of the time. The alternate buffer is the one
    " that we just left when we opened the bufexplorer window. Vim will select
    " another buffer for us if we've deleted the current buffer. In that case,
    " we will not need to restore the alternate buffer because it was
    " clobbered anyway.
    try
      " Wrap this into a try/catch block because we do not want "b #" to execute
      " if "b s:altBufNbr" fails
      exec "silent b" s:altBufNbr
      silent b #
    catch
    endtry
  endif
endfunction

" ToggleHelp {{{1
function s:ToggleHelp()
  let g:bufExplorerDetailedHelp = !g:bufExplorerDetailedHelp

  setlocal modifiable

  " Save position
  normal! ma

  " Remove old header
  if (s:firstBufferLine > 1)
    exec "1,".(s:firstBufferLine-1) "d _"
  endif

  call append(0, s:CreateHelp())

  silent! normal! g`a
  delmarks a

  setlocal nomodifiable

  if exists("b:displayMode") && b:displayMode == "winmanager"
    call WinManagerForceReSize("BufExplorer")
  end
endfunction

" ToggleSplitOutPathName {{{1
function s:ToggleSplitOutPathName()
  let g:bufExplorerSplitOutPathName = !g:bufExplorerSplitOutPathName
  call s:RebuildBufferList()
endfunction

" ToggleShowRelativePath {{{1
function s:ToggleShowRelativePath()
  let g:bufExplorerShowRelativePath = !g:bufExplorerShowRelativePath
  call s:RebuildBufferList()
endfunction

" RebuildBufferList {{{1
function s:RebuildBufferList()
  setlocal modifiable

  let curPos = getpos('.')

  call s:BuildBufferList()
  call setpos('.', curPos)

  setlocal nomodifiable
endfunction

" ToggleOpenMode {{{1
function s:ToggleOpenMode()
  let g:bufExplorerUseCurrentWindow = !g:bufExplorerUseCurrentWindow
  call s:UpdateHelpStatus()
endfunction

" ToggleSplitType {{{1
function s:ToggleSplitType()
  let g:bufExplorerSplitVertical = !g:bufExplorerSplitVertical
  call s:UpdateHelpStatus()
endfunction

" UpdateHelpStatus {{{1
function s:UpdateHelpStatus()
  if s:firstBufferLine > 1
    setlocal modifiable

    let text = s:GetHelpStatus()
    call setline(s:firstBufferLine - 2, text)

    setlocal nomodifiable
  endif
endfunction

" MRUCmp {{{1
function s:MRUCmp(line1, line2)
  return index(s:MRUList, str2nr(a:line1)) - index(s:MRUList, str2nr(a:line2))
endfunction

" SortReverse {{{1
function s:SortReverse()
  let g:bufExplorerReverseSort = !g:bufExplorerReverseSort
  call s:ReSortListing()
endfunction

" SortSelect {{{1
function s:SortSelect()
  let i = index(s:sort_by, g:bufExplorerSortBy)
  let i += 1
  let g:bufExplorerSortBy = get(s:sort_by, i, s:sort_by[0])

  call s:ReSortListing()
endfunction

" ReSortListing {{{1
function s:ReSortListing()
  setlocal modifiable

  let curPos = getpos('.')

  call s:SortListing()
  call s:UpdateHelpStatus()

  call setpos('.', curPos)

  setlocal nomodifiable
endfunction

" SortListing {{{1
function s:SortListing()
  let sort = s:firstBufferLine.",$sort".((g:bufExplorerReverseSort == 1) ? "!": "")

  if g:bufExplorerSortBy == "number"
    " Easiest case.
    exec sort 'n'
  elseif g:bufExplorerSortBy == "name"
    if g:bufExplorerSplitOutPathName
      exec sort 'ir /\d.\{7}\zs\f\+\ze/'
    else
      exec sort 'ir /\zs[^\/\\]\+\ze\s*line/'
    endif
  elseif g:bufExplorerSortBy == "fullpath"
    if g:bufExplorerSplitOutPathName
      " Sort twice - first on the file name then on the path.
      exec sort 'ir /\d.\{7}\zs\f\+\ze/'
    endif

    exec sort 'ir /\zs\f\+\ze\s\+line/'
  elseif g:bufExplorerSortBy == "extension"
    exec sort 'ir /\.\zs\w\+\ze\s/'
  elseif g:bufExplorerSortBy == "mru"
    let l = getline(s:firstBufferLine, "$")

    call sort(l, "<SID>MRUCmp")

    if g:bufExplorerReverseSort
      call reverse(l)
    endif

    call setline(s:firstBufferLine, l)
  endif
endfunction

" SetAltBufName {{{1
function s:SetAltBufName()
  let b:altFileName = '# '.expand("#:t")
endfunction

" MRUPush {{{1
function s:MRUPush()
  let bufNbr = str2nr(expand('<abuf>'))

  " Skip temporary buffer with buftype set.
  " Don't add the BufExplorer window to the list.
  if !empty(getbufvar(bufNbr, "&buftype")) ||
        \ !buflisted(bufNbr) ||
        \ fnamemodify(bufname(bufNbr), ":t") == "[BufExplorer]"
    return
  end

  call s:MRUPop(bufNbr)
  call insert(s:MRUList, bufNbr)
endfunction

" MRUPop {{{1
function s:MRUPop(...)
  let idx = index(s:MRUList, (a:0) ? a:1 : bufnr("%"))

  if (idx != -1)
    call remove(s:MRUList, idx)
  endif
endfunction

" BuildMRU {{{1
function s:BuildMRU()
  let s:MRUList = range(1, bufnr('$'))
  call filter(s:MRUList, 'buflisted(v:val)')
endfunction

" MRUListShow {{{1
function s:MRUListShow()
  echomsg "MRUList=".string(s:MRUList)
endfunction

" BufExplorerGetAltBuf {{{1
function BufExplorerGetAltBuf()
  return (exists("b:altFileName") ? b:altFileName : "")
endfunction

" Error {{{1
function s:Error(msg)
  echohl ErrorMsg | echo a:msg | echohl none
endfunction

" Warn {{{1
function s:Warn(msg)
  echohl WarningMsg | echo a:msg | echohl none
endfunction

" vim:ft=vim foldmethod=marker sw=2
