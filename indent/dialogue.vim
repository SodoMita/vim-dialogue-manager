" indent/dialogue.vim — indent settings for Dialogue Manager files
"
" The actual indent logic lives in autoload/dialogue.vim (dialogue#Indent).

if exists('b:did_indent')
  finish
endif
let b:did_indent = 1

let s:save_cpo = &cpoptions
set cpo&vim

setlocal autoindent
setlocal indentexpr=dialogue#Indent(v:lnum)

" Re-indent when structural keywords are typed at the start of a line.
" (The "0={word}" entries fire when {word} begins the line.)
let &l:indentkeys = '0{,0},0),0],0#,!^F,o,O,e'
      \ . ',0~,0-,0=>,0=if,0=elif,0=else,0=while,0=match,0=when'
      \ . ',0=import,0=using,0=%,0=do,0=set,0=$'

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim: nowrap sw=2 sts=2 ts=8 noet
