" run.vim — test suite for vim-dialogue-manager
"
set viminfo=
" Run with:
"   cd tests && vim -Nu NONE -U NONE -n -es -S run.vim
"
" Exits with code 0 when everything passes, code 1 otherwise.

set nocompatible
let s:root = expand('<sfile>:p:h:h')
execute 'set runtimepath+=' . s:root
syntax on

let s:tests = 0
let s:failures = 0

function! s:Check(name, got, expected) abort
  let s:tests += 1
  if type(a:got) != type(a:expected) || a:got !=# a:expected
    let s:failures += 1
    echo 'FAIL ' . a:name . ': got ' . string(a:got) . ' expected ' . string(a:expected)
  endif
endfunction

function! s:Ok(name, expr) abort
  let s:tests += 1
  if !a:expr
    let s:failures += 1
    echo 'FAIL ' . a:name . ': expected truthy'
  endif
endfunction

" Find the first line matching a pattern, 0 if none.
function! s:LineWith(pattern) abort
  let l:i = 1
  for l:line in getline(1, '$')
    if l:line =~# a:pattern
      return l:i
    endif
    let l:i += 1
  endfor
  return 0
endfunction

" ---------------------------------------------------------------------------
echo '== LineType =='
" ---------------------------------------------------------------------------
let s:T = [
      \ ['Nathan: Hello', 'dialogue'],
      \ ['This is just a line', 'dialogue'],
      \ ['~ start', 'cue'],
      \ ['~start', 'cue'],
      \ ['~', 'cue'],
      \ ['=> END', 'goto'],
      \ ['=> END!', 'goto'],
      \ ['=> some_cue', 'goto'],
      \ ['=>< some_cue', 'goto'],
      \ ['- A response', 'response'],
      \ ['%- not a response', 'dialogue'],
      \ ['-not a response', 'dialogue'],
      \ ['% Nathan: random', 'dialogue'],
      \ ['%2 Nathan: weighted', 'dialogue'],
      \ ['%2.5 Nathan: fractional', 'dialogue'],
      \ ['% [if GameState.x /] => maybe', 'goto'],
      \ ['%', 'random'],
      \ ['if GameState.x == 1', 'condition'],
      \ ['elif GameState.y', 'condition'],
      \ ['else', 'condition'],
      \ ['else if GameState.z', 'condition'],
      \ ['while GameState.count < 3', 'while'],
      \ ['match GameState.mode', 'match'],
      \ ['when > 5', 'when'],
      \ ['$> do_thing()', 'mutation'],
      \ ['$>> do_thing_async()', 'mutation'],
      \ ['do something()', 'mutation'],
      \ ['do! something_nonblocking()', 'mutation'],
      \ ['set GameState.x = 1', 'mutation'],
      \ ['import "res://a.dialogue" as a', 'import'],
      \ ['using GameState', 'using'],
      \ ['# comment', 'comment'],
      \ ['## translators note', 'comment'],
      \ ['', 'unknown'],
      \ ['   ', 'unknown'],
      \ ['| Nathan: concurrent', 'dialogue'],
      \ ['\if I start with if', 'dialogue'],
      \ ['\do I start with do', 'dialogue'],
      \ ['10:30 is a time, not a cue', 'dialogue'],
      \ ]
for [s:line, s:want] in s:T
  call s:Check('LineType(' . string(s:line) . ')', dialogue#LineType(s:line), s:want)
endfor

" ---------------------------------------------------------------------------
echo '== IndentLevel =='
" ---------------------------------------------------------------------------
let s:IL = [
      \ ['Nathan: hi', 0],
      \ ["\tNathan: hi", 1],
      \ ["\t\tNathan: hi", 2],
      \ ['    Nathan: hi', 1],
      \ ['        Nathan: hi', 2],
      \ ['  Nathan: hi', 1],
      \ ['   Nathan: hi', 1],
      \ ["\t- a response", 1],
      \ ]
for [s:line, s:want] in s:IL
  call s:Check('IndentLevel(' . string(s:line) . ')', dialogue#IndentLevel(s:line), s:want)
endfor
call s:Check('StripIndent', dialogue#StripIndent("\t\tNathan"), 'Nathan')
call s:Check('StripIndent 4-space', dialogue#StripIndent('        Nathan'), 'Nathan')

" ---------------------------------------------------------------------------
echo '== Indent =='
" ---------------------------------------------------------------------------
enew!
setlocal shiftwidth=4 tabstop=4
call setline(1, [
      \ '~ start',
      \ 'Nathan: How many projects have you started?',
      \ '- Just a couple',
      \ "\tNathan: That's not so bad.",
      \ '- A lot',
      \ "\tNathan: Maybe you should finish one.",
      \ "\t- A few",
      \ "\t\tNathan: That's great!",
      \ '=> END',
      \ 'if GameState.difficulty == "hard"',
      \ "\tNathan: Hard mode!",
      \ 'elif GameState.difficulty == "easy"',
      \ "\tNathan: Easy mode!",
      \ 'else',
      \ "\tNathan: Normal mode.",
      \ 'match GameState.mode',
      \ "\twhen 1",
      \ "\t\tNathan: It is one.",
      \ "\telse",
      \ "\t\tNathan: It is something else.",
      \ 'Nathan: After the blocks.',
      \ '~ second_cue',
      \ 'Nathan: Second section.',
      \ ])

let s:expected_indents = [
      \ 0, 0, 0, 4, 0, 4, 4, 8, 0,
      \ 0, 4, 0, 4, 0, 4,
      \ 0, 4, 8, 4, 8,
      \ 0, 0, 0,
      \ ]
let s:lnum = 1
for s:want in s:expected_indents
  call s:Check('Indent(line ' . s:lnum . ' ' . string(getline(s:lnum)) . ')',
        \ dialogue#Indent(s:lnum), s:want)
  let s:lnum += 1
endfor

" A new line after a response's child: with the autoindent that Vim gives
" it stays in the branch; an explicitly dedented line is kept where it is.
call append(6, '')
call setline(7, "\tNathan: Brand new child of \"- A lot\".")
call s:Check('Indent(new child in branch)', dialogue#Indent(7), 4)
call setline(7, 'Nathan: Explicitly back at the top.')
call s:Check('Indent(explicit dedent is kept)', dialogue#Indent(7), 0)
" A new sibling response typed after a child dedents to the sibling.
call setline(7, '- Another response')
call s:Check('Indent(new sibling response)', dialogue#Indent(7), 0)
" A jump after response content stays wherever it was typed (never deeper
" than the response).
call setline(7, "\t=> END")
call s:Check('Indent(goto kept in branch)', dialogue#Indent(7), 4)
call setline(7, '=> END')
call s:Check('Indent(goto dedented out)', dialogue#Indent(7), 0)

" A response typed after a condition inside a response branch belongs to the
" response, not to the condition. Also covers 2-space indent style detection.
enew!
call setline(1, [
      \ '~ start',
      \ '- first',
      \ '  Nathan: child',
      \ '  if X == 1',
      \ '    Nathan: deeper',
      \ '  - nested',
      \ '    Nathan: nested child',
      \ ])
call s:Check('Indent(2-space: first response)', dialogue#Indent(2), 0)
call s:Check('Indent(2-space: child)', dialogue#Indent(3), 2)
call s:Check('Indent(2-space: if in branch)', dialogue#Indent(4), 2)
call s:Check('Indent(2-space: if body)', dialogue#Indent(5), 4)
call s:Check('Indent(2-space: nested response)', dialogue#Indent(6), 2)
call s:Check('Indent(2-space: nested child)', dialogue#Indent(7), 4)

" Tab-indented files indent by whole tabstops, and a nested continuation
" line (one deeper than the dialogue above it) keeps its level.
enew!
setlocal tabstop=8 shiftwidth=8 noexpandtab
call setline(1, ['~ start', 'if X', "\tNathan: one", "\t\tcontinued here"])
call s:Check('Indent(tab file: body)', dialogue#Indent(3), 8)
call s:Check('Indent(tab file: continuation)', dialogue#Indent(4), 16)
setlocal tabstop=4 shiftwidth=4

" Re-indenting every line of the example file must be a no-op.
execute 'silent edit!' s:root . '/examples/example.dialogue'
setlocal tabstop=4 shiftwidth=4
let s:changed = []
for s:lnum in range(1, line('$'))
  if getline(s:lnum) !~# '^\s*$'
    if dialogue#Indent(s:lnum) !=# indent(s:lnum)
      call add(s:changed, s:lnum . ' [' . getline(s:lnum) . '] wants ' . dialogue#Indent(s:lnum) . ' has ' . indent(s:lnum))
    endif
  endif
endfor
if !empty(s:changed)
  for s:c in s:changed
    echo 'IDEMPOTENCY: ' . s:c
  endfor
endif
call s:Check('example file indent is idempotent', len(s:changed), 0)

" ---------------------------------------------------------------------------
echo '== Folding =='
" ---------------------------------------------------------------------------
enew!
call setline(1, [
      \ '~ first',
      \ 'Nathan: one',
      \ '- branch',
      \ "\tNathan: nested",
      \ '~ second',
      \ 'Nathan: two',
      \ 'if GameState.x',
      \ "\tNathan: in if",
      \ 'Nathan: after',
      \ '',
      \ '~ third',
      \ 'Nathan: three',
      \ ])
let s:folds = [
      \ ['>1', 1], ['1', 2], ['>2', 3], ['2', 4],
      \ ['>1', 5], ['1', 6], ['>2', 7], ['2', 8], ['1', 9], ['=', 10],
      \ ['>1', 11], ['1', 12],
      \ ]
for [s:want, s:lnum] in s:folds
  call s:Check('FoldExpr(line ' . s:lnum . ' ' . string(getline(s:lnum)) . ')',
        \ dialogue#FoldExpr(s:lnum), s:want)
endfor

" ---------------------------------------------------------------------------
echo '== Linter =='
" ---------------------------------------------------------------------------
execute 'silent edit!' s:root . '/tests/fixtures/errors.dialogue'
let s:errors = dialogue#Check(0)
call s:Check('linter error count', len(s:errors), 12)

" Join all messages per line (one line can legitimately produce two).
let s:seen = {}
for s:entry in s:errors
  let s:seen[s:entry.lnum] = get(s:seen, s:entry.lnum, '') . ' | ' . s:entry.text
endfor
" Each expected problem on its line.
call s:Ok('unknown cue',        s:seen[4] =~# 'Unknown cue "missing_cue"')
call s:Ok('concurrent origin',  s:seen[5] =~# 'Concurrent line has no dialogue')
call s:Ok('duplicate cue',      s:seen[6] =~# 'Duplicate cue "start"')
call s:Ok('empty condition',    s:seen[7] =~# 'Condition has no content')
call s:Ok('when outside match', s:seen[9] =~# '"when" must belong')
call s:Ok('invalid indentation',s:seen[11] =~# 'Invalid indentation')
call s:Ok('duplicate id',       s:seen[13] =~# 'Duplicate static line id')
call s:Ok('lonely id',          s:seen[14] =~# 'no other content')
call s:Ok('duplicate import',   s:seen[16] =~# 'Duplicate import name')
call s:Ok('cue begins number',  s:seen[17] =~# 'cannot begin with a number')
call s:Ok('unknown imported cue', s:seen[18] =~# 'Unknown cue "snippets/nope"')

" The example file (a tiny fake project) must be clean, including the
" res:// import which resolves through examples/project.godot.
execute 'silent edit!' s:root . '/examples/example.dialogue'
let s:example_errors = dialogue#Check(0)
if !empty(s:example_errors)
  for s:entry in s:example_errors
    echo 'EXAMPLE LINT: line ' . s:entry.lnum . ': ' . s:entry.text
  endfor
endif
call s:Check('example file is clean', len(s:example_errors), 0)

" An import pointing at a missing file inside a project is an error.
execute 'silent edit!' s:root . '/tests/fixtures/broken_import/main.dialogue'
let s:broken = dialogue#Check(0)
call s:Check('broken import error count', len(s:broken), 1)
if !empty(s:broken)
  call s:Ok('broken import message', s:broken[0].text =~# 'Cannot read imported file')
endif

" ---------------------------------------------------------------------------
echo '== Syntax =='
" ---------------------------------------------------------------------------
execute 'silent edit!' s:root . '/examples/example.dialogue'
setfiletype dialogue
" Force syntax application for the whole buffer.
redraw

function! s:SynAt(lnum, col) abort
  return synIDattr(synID(a:lnum, a:col, 1), 'name')
endfunction

function! s:CheckSyn(name, pattern, col, group) abort
  let l:lnum = s:LineWith(a:pattern)
  if l:lnum == 0
    call s:Ok(a:name . ' (line found)', 0)
    return
  endif
  call s:Check(a:name . ' line ' . l:lnum . ' col ' . a:col,
        \ s:SynAt(l:lnum, a:col), a:group)
endfunction

call s:CheckSyn('cue',            '^\~ start$', 1, 'dialogueCue')
call s:CheckSyn('comment',        '^# Godot Dialogue Manager 4', 1, 'dialogueComment')
call s:CheckSyn('translator',     '^## This note', 1, 'dialogueTranslatorNote')
call s:CheckSyn('import keyword', '^import "res://', 1, 'dialogueImportKeyword')
call s:CheckSyn('import path',    '^import "res://', 9, 'dialogueImportPath')
call s:CheckSyn('using keyword',  '^using GameState$', 1, 'dialogueUsingKeyword')
call s:CheckSyn('character',      '^Nathan: Hey', 1, 'dialogueCharacter')
call s:CheckSyn('static id',      'ID:WELCOME', 47, 'dialogueLineID')
call s:CheckSyn('interpolation',  '{{GameState.apple_count}}', 20, 'dialogueIdentifier')
call s:CheckSyn('inline random',  '\[\[this', 20, 'dialogueInlineRandom')
call s:CheckSyn('bbcode',         '\[b\]bold', 24, 'dialogueBBCode')
call s:CheckSyn('random prefix',  '^%3 Nathan', 1, 'dialogueRandom')
call s:CheckSyn('concurrent',     '^| Coco', 1, 'dialogueConcurrent')
call s:CheckSyn('condition',      '^if GameState.has_met_nathan', 1, 'dialogueConditionKeyword')
call s:CheckSyn('mutation',       '^\s*\$> GameState\.animate', 2, 'dialogueMutationKeyword')
call s:CheckSyn('jump arrow',     '^=> END$', 1, 'dialogueJumpArrow')
call s:CheckSyn('jump end',       '^=> END$', 4, 'dialogueJumpEnd')
call s:CheckSyn('response',       '^- Tell me more about this dialogue editor', 1, 'dialogueResponse')
call s:CheckSyn('wrapped cond',   'if not GameState.asked_editor /', 43, 'dialogueWrappedDelimiter')
call s:CheckSyn('snippet arrow',  '^\s*=>< snippets/banter', 2, 'dialogueJumpArrow')
call s:CheckSyn('jump target',    '^\s*=>< snippets/banter', 6, 'dialogueJumpTarget')

" expression elements inside a condition
" "if GameState.has_met_nathan == false"
let s:lnum = s:LineWith('^if GameState.has_met_nathan == false')
call s:Check('condition identifier', s:SynAt(s:lnum, 4), 'dialogueIdentifier')
call s:Check('condition operator', s:SynAt(s:lnum, 29), 'dialogueOperator')
call s:Check('condition bool', s:SynAt(s:lnum, 32), 'dialogueBoolean')

" numbers and strings inside mutations
" "	$> GameState.animate(\"Nathan\", \"Wave\")"
let s:lnum = s:LineWith('^\s*\$> GameState\.animate')
call s:Check('mutation function', s:SynAt(s:lnum, 15), 'dialogueFunctionCall')
call s:Check('mutation string', s:SynAt(s:lnum, 23), 'dialogueString')

" plain dialogue text (inside the spoken part) must NOT be highlighted
let s:lnum = s:LineWith('^Nathan: Hey, welcome')
call s:Check('dialogue text is plain', s:SynAt(s:lnum, 20), '')

" ---------------------------------------------------------------------------
if s:failures == 0
  echo 'ALL ' . s:tests . ' TESTS PASSED'
  qa!
else
  echo s:failures . ' OF ' . s:tests . ' TESTS FAILED'
  cquit 1
endif
