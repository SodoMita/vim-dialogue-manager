" ftplugin/dialogue.vim — settings for Godot Dialogue Manager files
"
" See :h dialogue.txt for all options, commands and mappings.

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

let s:save_cpo = &cpoptions
set cpo&vim

let b:undo_ftplugin = 'setlocal formatoptions< comments< commentstring< formatlistpat<'
      \ . ' tabstop< shiftwidth< foldmethod< foldexpr< foldtext< foldlevel< omnifunc<'
      \ . '| unlet! b:dialogue_indent_width'

" -------------------------------------------------------------------------
" Comments and formatting
" -------------------------------------------------------------------------
" '#' is a full-line comment; '##' is a note for translators.
setlocal comments=:##,:#
setlocal commentstring=#\ %s
" Never auto-wrap or auto-continue dialogue.
setlocal formatoptions-=t
setlocal formatoptions-=a
setlocal formatoptions-=o
setlocal formatoptions-=r
" Let gq/gw understand response lists.
setlocal formatlistpat=^\\s*[-~][[:space:]]

" -------------------------------------------------------------------------
" Indentation
" -------------------------------------------------------------------------
" The Dialogue Manager counts indentation in tabs (or 2/4 spaces); one level
" per token. Four matches the editor's display width. Set g:dialogue_indent
" to 0 to keep your own tab/shift settings.
if !exists('g:dialogue_indent') || g:dialogue_indent
  setlocal tabstop=4
  setlocal shiftwidth=4
endif

" -------------------------------------------------------------------------
" Folding: one fold per ~ cue, nested folds for branches and blocks
" -------------------------------------------------------------------------
if !exists('g:dialogue_folding') || g:dialogue_folding
  setlocal foldmethod=expr
  setlocal foldexpr=dialogue#FoldExpr(v:lnum)
  setlocal foldtext=dialogue#FoldText()
  if !exists('b:dialogue_foldlevel_set')
    setlocal foldlevel=1
    let b:undo_ftplugin .= '| unlet! b:dialogue_foldlevel_set'
  endif
endif

" -------------------------------------------------------------------------
" Completion of cue names after "=>"
" -------------------------------------------------------------------------
setlocal omnifunc=dialogue#Complete

" -------------------------------------------------------------------------
" Commands
" -------------------------------------------------------------------------
command! -buffer -nargs=0 DialogueCues call dialogue#Cues()
command! -buffer -nargs=0 -bang DialogueCheck call dialogue#Check(<bang>0)

let b:undo_ftplugin .= '| unlet! b:did_ftplugin'
      \ . '| silent! delcommand DialogueCues'
      \ . '| silent! delcommand DialogueCheck'

" -------------------------------------------------------------------------
" Mappings
" -------------------------------------------------------------------------
if !exists('g:dialogue_no_mappings')
  nnoremap <buffer><silent> [[ :<C-U>call dialogue#JumpCue(-1)<CR>
  nnoremap <buffer><silent> ]] :<C-U>call dialogue#JumpCue(1)<CR>
  " gd: jump to the definition of the cue referenced on this line ("=> cue")
  nnoremap <buffer><silent> <script> gd :<C-U>call dialogue#GotoDefinition()<CR>
  let b:undo_ftplugin .= '| silent! nunmap <buffer> [['
        \ . '| silent! nunmap <buffer> ]]'
        \ . '| silent! nunmap <buffer> gd'
endif

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim: nowrap sw=2 sts=2 ts=8 noet
