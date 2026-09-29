" compiler/dialogue.vim — check Dialogue Manager files with :make
"
" Two ways to use it:
"
" 1. Built-in linter (no Godot needed):
"      :DialogueCheck
"    (works out of the box, see :h :DialogueCheck)
"
" 2. The real compiler, via Godot:
"      copy tools/dialogue_check.gd into your Godot project, then
"      let g:dialogue_makeprg = 'godot --headless --path . -s dialogue_check.gd -- %:p'
"      :compiler dialogue
"      :make
"
" Any command that prints "file:line:column: message" works as
" g:dialogue_makeprg.

if exists('current_compiler')
  finish
endif
let current_compiler = 'dialogue'

" :compiler defines this for us; define it for direct sourcing too
if exists(':CompilerSet') != 2
  command -nargs=* CompilerSet setlocal <args>
endif

let s:save_cpo = &cpoptions
set cpo&vim

if exists('g:dialogue_makeprg')
  let &l:makeprg = g:dialogue_makeprg
else
  " Default to the helper script copied into the project root.
  let &l:makeprg = 'godot --headless --path . -s dialogue_check.gd -- %:p'
endif

" path:line:col: message  /  path:line: message
" Anything else (engine noise, "Godot Engine" banner, ...) is ignored.
CompilerSet errorformat=%f:%l:%c:\ %m,%f:%l:\ %m,%-G%.%#

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim: nowrap sw=2 sts=2 ts=8 noet
