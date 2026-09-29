" dialogue.vim — support functions for the vim-dialogue-manager plugin
"
" Line classification and indentation counting mirror the Dialogue Manager
" compiler (addons/dialogue_manager/compiler/compilation.gd) so that Vim and
" Godot agree on what a line means.
"
" Vim 8.0+ / Neovim compatible. No +python needed.

if exists('g:loaded_dialogue_autoload')
  finish
endif
let g:loaded_dialogue_autoload = 1

" Weighted random prefix, mirroring DMCompilerRegEx.WEIGHTED_RANDOM_SIBLINGS_REGEX
let s:WEIGHTED_RANDOM = '^%\%(\d\+\%(\.\d\+\)\=\)\=\%(\s*\[if\s.\{-} \/]\)\=\s'

" The indentation tokens recognised by the compiler, in its order of
" preference: a tab, a literal "\t" (two characters), four spaces, two spaces.
let s:INDENT_TOKENS = ["\t", '\t', '    ', '  ']

" ---------------------------------------------------------------------------
" Classification
" ---------------------------------------------------------------------------

" Return the type of a raw line, mirroring DMCompilation.get_line_type().
" One of: import, using, comment, cue, condition, while, match, when,
" mutation, goto, response, random, dialogue, unknown.
function! dialogue#LineType(raw) abort
  " Strip indentation the way the compiler does, then remove a weighted
  " random prefix (the compiler appends a space so a bare "%" can match).
  let l:text = substitute(a:raw, '^\s*', '', '')
  let l:text = substitute(l:text . ' ', s:WEIGHTED_RANDOM, '', '')
  let l:text = substitute(l:text, '\s*$', '', '')

  if l:text =~# '^import\s'
    return 'import'
  elseif l:text =~# '^using\s'
    return 'using'
  elseif l:text =~# '^#'
    return 'comment'
  elseif l:text =~# '^\~\s\='
    return 'cue'
  elseif l:text =~# '^if\s' || l:text =~# '^elif\>' || l:text =~# '^else\>'
    return 'condition'
  elseif l:text =~# '^while\s'
    return 'while'
  elseif l:text =~# '^match\s'
    return 'match'
  elseif l:text =~# '^when\s'
    return 'when'
  elseif l:text =~# '^do\s' || l:text =~# '^do!\s' || l:text =~# '^set\s'
        \ || l:text =~# '^\$>\s' || l:text =~# '^\$>>\s'
    return 'mutation'
  elseif l:text =~# '^=>\s' || l:text =~# '^=><\s'
    return 'goto'
  elseif l:text =~# '^- '
    return 'response'
  elseif a:raw =~# '^\s*%' && l:text ==# ''
    return 'random'
  elseif l:text !=# ''
    return 'dialogue'
  else
    return 'unknown'
  endif
endfunction

" True if the line opens a block that always contains children.
function! s:IsBlockOpener(type) abort
  return a:type ==# 'condition' || a:type ==# 'while' || a:type ==# 'match'
        \ || a:type ==# 'when' || a:type ==# 'random'
endfunction

" ---------------------------------------------------------------------------
" Indentation levels (as the compiler counts them)
" ---------------------------------------------------------------------------

function! s:IndentTokenOf(line) abort
  for l:token in s:INDENT_TOKENS
    if stridx(a:line, l:token) == 0
      return l:token
    endif
  endfor
  return ''
endfunction

" Number of indent tokens at the start of a line (one tab/4-spaces/2-spaces
" group counts as one).
function! dialogue#IndentLevel(line) abort
  let l:token = s:IndentTokenOf(a:line)
  if l:token ==# ''
    return 0
  endif
  let l:level = 0
  let l:rest = a:line
  while stridx(l:rest, l:token) == 0
    let l:level += 1
    let l:rest = strpart(l:rest, strlen(l:token))
  endwhile
  return l:level
endfunction

" Remove all leading indent tokens from a line.
function! dialogue#StripIndent(line) abort
  let l:token = s:IndentTokenOf(a:line)
  if l:token ==# ''
    return a:line
  endif
  let l:rest = a:line
  while stridx(l:rest, l:token) == 0
    let l:rest = strpart(l:rest, strlen(l:token))
  endwhile
  return l:rest
endfunction

" Column width of one indent level, based on the style already used in the
" buffer (tabs, 4 spaces or 2 spaces). Defaults to 'shiftwidth'.
function! s:IndentWidth() abort
  if exists('b:dialogue_indent_width')
    return b:dialogue_indent_width
  endif
  let l:width = &l:shiftwidth == 0 ? (&l:tabstop == 0 ? 4 : &l:tabstop) : &l:shiftwidth
  let l:last = line('$')
  let l:limit = l:last > 500 ? 500 : l:last
  let l:i = 1
  while l:i <= l:limit
    let l:line = getline(l:i)
    if l:line =~# '^\t'
      " tab-indented: one level is one tab, worth a whole tabstop
      let l:width = &l:tabstop == 0 ? 4 : &l:tabstop
      break
    elseif l:line =~# '^    [^ ]'
      let l:width = 4
      break
    elseif l:line =~# '^  [^ ]'
      let l:width = 2
      break
    endif
    let l:i += 1
  endwhile
  let b:dialogue_indent_width = l:width
  return l:width
endfunction

" Nearest previous line (searching up from a:from) whose indent level is
" strictly less than a:level. Returns 0 when there is none.
function! s:ScanUpForLessIndent(from, level) abort
  let l:i = a:from
  while l:i > 0
    let l:line = getline(l:i)
    if l:line !~# '^\s*$' && dialogue#LineType(l:line) !=# 'comment'
      if dialogue#IndentLevel(l:line) < a:level
        return l:i
      endif
    endif
    let l:i -= 1
  endwhile
  return 0
endfunction

" Previous non-blank, non-comment line above a:lnum. Returns 0 when none.
function! s:PrevCodeLine(lnum) abort
  let l:i = a:lnum - 1
  while l:i > 0
    let l:line = getline(l:i)
    if l:line !~# '^\s*$' && dialogue#LineType(l:line) !=# 'comment'
      return l:i
    endif
    let l:i -= 1
  endwhile
  return 0
endfunction

" ---------------------------------------------------------------------------
" indentexpr
" ---------------------------------------------------------------------------

function! dialogue#Indent(lnum) abort
  let l:cur = getline(a:lnum)
  if l:cur =~# '^\s*$'
    return -1
  endif

  let l:curtype = dialogue#LineType(l:cur)

  " These always live at the left margin.
  if l:curtype ==# 'cue' || l:curtype ==# 'import' || l:curtype ==# 'using'
    return 0
  endif

  let l:width = s:IndentWidth()
  let l:prev = s:PrevCodeLine(a:lnum)
  if l:prev == 0
    return 0
  endif

  let l:pline = getline(l:prev)
  let l:ptype = dialogue#LineType(l:pline)
  let l:plevel = dialogue#IndentLevel(l:pline)
  let l:cur_level = dialogue#IndentLevel(l:cur)

  " elif/else line up with their opening if (or with the "when"s of a match)
  if l:curtype ==# 'condition' && dialogue#StripIndent(l:cur) =~# '^\%(elif\|else\)\>'
    if l:ptype ==# 'condition' || l:ptype ==# 'while' || l:ptype ==# 'match'
      return l:plevel * l:width
    endif
    let l:anchor = s:ScanUpForLessIndent(l:prev, l:plevel)
    if l:anchor > 0
      return dialogue#IndentLevel(getline(l:anchor)) * l:width
    endif
    return l:plevel * l:width
  endif

  " "when" lives one level under its match, in line with any previous "when"
  if l:curtype ==# 'when'
    if l:ptype ==# 'match'
      return (l:plevel + 1) * l:width
    endif
    let l:anchor = s:ScanUpForLessIndent(l:prev, l:plevel)
    if l:anchor > 0
      return dialogue#IndentLevel(getline(l:anchor)) * l:width
    endif
    return l:plevel * l:width
  endif

  " Responses and bare "%" openers stay with their siblings.
  if l:curtype ==# 'response' || l:curtype ==# 'random'
    " Find the outermost response/random block that encloses the previous
    " line (walking the ancestor chain, so blocks in between are skipped).
    let l:r_level = -1
    let l:want = l:plevel + 1
    let l:i = l:prev
    while l:i > 0
      let l:line = getline(l:i)
      if l:line !~# '^\s*$' && dialogue#LineType(l:line) !=# 'comment'
        let l:lvl = dialogue#IndentLevel(l:line)
        if l:lvl < l:want
          let l:t = dialogue#LineType(l:line)
          if l:t ==# 'response' || l:t ==# 'random'
            let l:r_level = l:lvl
          endif
          let l:want = l:lvl
        endif
      endif
      let l:i -= 1
    endwhile

    if l:r_level >= 0
      " The new response is a sibling of the enclosing response when the
      " previous line is at that response's level or one deeper; anything
      " deeper means it belongs inside a nested response.
      if l:plevel <= l:r_level + 1
        let l:sibling = l:r_level
      else
        let l:sibling = l:r_level + 1
      endif
      " Keep a level the user already chose when it is structurally valid
      " (a response may sit at the enclosing response's level or one under).
      if l:cur_level ==# l:r_level || l:cur_level ==# l:r_level + 1
        return l:cur_level * l:width
      endif
      return l:sibling * l:width
    endif

    " No enclosing response: a child of the enclosing block, if any.
    let l:anchor = s:ScanUpForLessIndent(l:prev, l:plevel)
    if l:anchor > 0
      return (dialogue#IndentLevel(getline(l:anchor)) + 1) * l:width
    endif
    return l:plevel * l:width
  endif

  " Condition blocks always contain children.
  if s:IsBlockOpener(l:ptype)
    return (l:plevel + 1) * l:width
  endif

  " Lines after a response belong to its branch — but a response that ends
  " in a jump ("... => cue") can never have a branch, so what follows it
  " exits the response list (never deeper than the response itself).
  if l:ptype ==# 'response'
    if l:curtype ==# 'goto' || l:pline =~# ' =>'
      return (l:cur_level > l:plevel ? l:plevel : l:cur_level) * l:width
    endif
    return (l:plevel + 1) * l:width
  endif

  " Anything else: trust the indent that is already there whenever it is
  " structurally possible (nothing may be more than one level deeper than
  " the line above); only pull back lines that are nested too deep. New
  " lines start out with the previous line's indent ('autoindent'), so they
  " naturally continue at the current depth.
  if l:cur_level > l:plevel + 1
    return (l:plevel + 1) * l:width
  endif
  return l:cur_level * l:width
endfunction

" ---------------------------------------------------------------------------
" foldexpr — fold each ~ cue into a section, and nested blocks inside it
" ---------------------------------------------------------------------------

function! dialogue#FoldExpr(lnum) abort
  let l:line = getline(a:lnum)
  if l:line =~# '^\s*$'
    return '='
  endif

  let l:type = dialogue#LineType(l:line)
  if l:type ==# 'comment'
    return '='
  endif

  if l:type ==# 'cue'
    return '>1'
  endif
  if l:type ==# 'import' || l:type ==# 'using'
    return 0
  endif

  let l:level = dialogue#IndentLevel(l:line) + 1
  if s:HasChildren(a:lnum)
    return '>' . (l:level + 1)
  endif
  return string(l:level)
endfunction

" Does the line at a:lnum have any lines nested beneath it?
function! s:HasChildren(lnum) abort
  let l:level = dialogue#IndentLevel(getline(a:lnum))
  let l:i = a:lnum + 1
  let l:last = line('$')
  while l:i <= l:last
    let l:line = getline(l:i)
    if l:line !~# '^\s*$' && dialogue#LineType(l:line) !=# 'comment'
      return dialogue#IndentLevel(l:line) > l:level
    endif
    let l:i += 1
  endwhile
  return 0
endfunction

function! dialogue#FoldText() abort
  let l:text = substitute(getline(v:foldstart), '^\s*\~\s*', '\~ ', '')
  let l:count = v:foldend - v:foldstart + 1
  return printf('%s  [%d line%s]', l:text, l:count, l:count == 1 ? '' : 's')
endfunction

" ---------------------------------------------------------------------------
" Navigation
" ---------------------------------------------------------------------------

" Jump to the previous/next ~ cue.
function! dialogue#JumpCue(direction) abort
  let l:step = a:direction >= 0 ? 1 : -1
  let l:i = line('.') + l:step
  let l:last = line('$')
  while l:i >= 1 && l:i <= l:last
    if dialogue#LineType(getline(l:i)) ==# 'cue'
      normal! m'
      call cursor(l:i, 1)
      normal! zz
      return
    endif
    let l:i += l:step
  endwhile
  echohl WarningMsg
  echo a:direction >= 0 ? 'No cue below' : 'No cue above'
  echohl None
endfunction

" gd-style jump to the definition of the cue referenced on this line
" ("=> cue", "=>< cue" or "prefix/cue" from an import).
function! dialogue#GotoDefinition() abort
  let l:line = getline('.')
  let l:target = matchstr(l:line, '=>\%(<\)\=\s*\zs\S\+')
  if l:target ==# ''
    let l:target = expand('<cword>')
  endif
  if l:target ==# ''
    echohl WarningMsg
    echo 'No cue reference found on this line'
    echohl None
    return
  endif

  if l:target =~# '^END!\=$'
    echo '=>' . l:target . ' ends the dialogue flow'
    return
  endif

  if l:target =~# '^{{'
    echo 'Expression jump: ' . l:target
    return
  endif

  " Imported cue (prefix/cue): try to open the imported file.
  if l:target =~# '/'
    let l:imported = s:OpenImport(split(l:target, '/', 1)[0], split(l:target, '/', 1)[1])
    if !empty(l:imported)
      echo l:imported
    endif
    return
  endif

  let l:pattern = '^\s*\~\s\=' . escape(l:target, '\') . '\>'
  let l:lnum = search(l:pattern, 'w')
  if l:lnum > 0
    normal! zz
  else
    echohl WarningMsg
    echo 'No cue named "' . l:target . '" in this file'
    echohl None
  endif
endfunction

" Find "import \"...\" as prefix" and open the referenced file at the cue.
function! s:OpenImport(prefix, cue) abort
  let l:path = ''
  for l:line in getline(1, '$')
    let l:m = matchlist(l:line, '^import\s\+"\([^"]*\)"\s\+as\s\+\S\+')
    if !empty(l:m) && matchstr(l:line, 'as\s\+\zs\S\+') ==# a:prefix
      let l:path = l:m[1]
      break
    endif
  endfor
  if l:path ==# ''
    return 'No import named "' . a:prefix . '"'
  endif
  let l:resolved = s:ResolveResPath(l:path)
  if l:resolved ==# '' || !filereadable(l:resolved)
    return 'Cannot read ' . l:path
  endif
  if &l:modified
    " don't lose unsaved work when navigating
    execute 'split' fnameescape(l:resolved)
  else
    execute 'edit' fnameescape(l:resolved)
  endif
  call search('^\s*\~\s\=' . escape(a:cue, '\') . '\>', 'w')
  normal! zz
  return ''
endfunction

" Turn a res:// (or relative) path into something readable from the shell.
function! s:ResolveResPath(path) abort
  if a:path !~# '^res://'
    return a:path
  endif
  let l:relative = substitute(a:path, '^res://', '', '')
  " Look for project.godot upwards from the current file.
  let l:dir = expand('%:p:h')
  let l:project = findfile('project.godot', l:dir . ';')
  if l:project !=# ''
    return fnamemodify(l:project, ':p:h') . '/' . l:relative
  endif
  return l:relative
endfunction

" ---------------------------------------------------------------------------
" :DialogueCues
" ---------------------------------------------------------------------------

function! dialogue#Cues() abort
  let l:cues = []
  let l:i = 1
  for l:line in getline(1, '$')
    if dialogue#LineType(l:line) ==# 'cue'
      call add(l:cues, {'lnum': l:i, 'text': '~ ' . dialogue#CueName(l:line)})
    endif
    let l:i += 1
  endfor

  if empty(l:cues)
    echo 'No cues found in this file'
    return
  endif

  let l:qf = []
  for l:cue in l:cues
    call add(l:qf, {'filename': expand('%:p'), 'lnum': l:cue.lnum, 'text': l:cue.text})
  endfor
  call setqflist(l:qf)
  copen
  echo len(l:cues) . ' cue' . (len(l:cues) == 1 ? '' : 's')
endfunction

" Name of the cue on a "~ name" line.
function! dialogue#CueName(line) abort
  return substitute(substitute(dialogue#StripIndent(a:line), '^\~\s\=', '', ''), '\s*$', '', '')
endfunction

" ---------------------------------------------------------------------------
" :DialogueCheck — a local linter that reimplements the compiler's
" structural checks (no Godot required)
" ---------------------------------------------------------------------------

function! dialogue#Check(bang) abort
  let l:lines = getline(1, '$')
  let l:errors = []
  let l:file = expand('%:p')

  " ---- known cues, imports and static ids -------------------------------
  let l:cues = {}
  let l:imports = {}
  let l:static_ids = {}
  let l:i = 1
  for l:line in l:lines
    let l:type = dialogue#LineType(l:line)
    if l:type ==# 'cue'
      let l:name = dialogue#CueName(l:line)
      if l:name ==# ''
        call add(l:errors, s:Error(l:file, l:i, 2, 'Cue is empty'))
      elseif has_key(l:cues, l:name)
        call add(l:errors, s:Error(l:file, l:i, 2, 'Duplicate cue "' . l:name . '" (first seen on line ' . l:cues[l:name] . ')'))
      else
        let l:cues[l:name] = l:i
        if l:name =~# '^\d'
          call add(l:errors, s:Error(l:file, l:i, 2, 'Cue names cannot begin with a number'))
        elseif l:name !~# '^\k\+$'
          call add(l:errors, s:Error(l:file, l:i, 2, 'Cue "' . l:name . '" contains invalid characters'))
        endif
      endif
    elseif l:type ==# 'import'
      let l:m = matchlist(l:line, '^import\s\+"\([^"]*\)"\s\+as\s\+\(\S\+\)')
      if empty(l:m)
        call add(l:errors, s:Error(l:file, l:i, 1, 'Malformed import (expected: import "res://file.dialogue" as prefix)'))
      elseif has_key(l:imports, l:m[2])
        call add(l:errors, s:Error(l:file, l:i, 1, 'Duplicate import name "' . l:m[2] . '"'))
      else
        let l:imports[l:m[2]] = l:m[1]
      endif
    endif
    " Static line ids
    let l:id = matchstr(l:line, '\[ID:\zs[^]]*\ze\]')
    if l:id !=# ''
      if has_key(l:static_ids, l:id)
        call add(l:errors, s:Error(l:file, l:i, 1, 'Duplicate static line id "' . l:id . '" (first seen on line ' . l:static_ids[l:id] . ')'))
      else
        let l:static_ids[l:id] = l:i
      endif
      if s:Trim(dialogue#StripIndent(l:line)) ==# '[ID:' . l:id . ']'
        call add(l:errors, s:Error(l:file, l:i, 1, 'Static ids cannot be on a line with no other content'))
      endif
    endif
    let l:i += 1
  endfor

  " ---- cues from imported files ------------------------------------------
  let l:all_cues = copy(l:cues)
  let l:imported_cues = s:ImportedCues(l:imports, l:file)
  for l:key in keys(l:imported_cues)
    let l:all_cues[l:key] = l:imported_cues[l:key]
  endfor

  " ---- imports that cannot be resolved ------------------------------------
  " (matches the compiler's ERR_ERRORS_IN_IMPORTED_FILE; only checked when a
  " project.godot can be found so standalone files are not nagged)
  if s:ProjectRoot(l:file) !=# ''
    for l:prefix in keys(l:imports)
      let l:found_cues = 0
      for l:key in keys(l:imported_cues)
        if l:key =~# '^' . escape(l:prefix, '/*[]~^\$') . '/'
          let l:found_cues = 1
          break
        endif
      endfor
      if !l:found_cues
        let l:lnum = 0
        let l:i = 1
        for l:line in l:lines
          if l:line =~# '^import' && matchstr(l:line, 'as\s\+\zs\S\+') ==# l:prefix
            let l:lnum = l:i
            break
          endif
          let l:i += 1
        endfor
        call add(l:errors, s:Error(l:file, l:lnum, 0, 'Cannot read imported file "' . l:imports[l:prefix] . '"'))
      endif
    endfor
  endif

  " ---- structural walk ----------------------------------------------------
  " Mirrors build_line_tree(): nothing may be more than one indent deeper
  " than its parent, condition blocks need content, etc.
  let l:chain = [{'type': 'root', 'lnum': 0}]
  let l:prev = {'type': 'root', 'lnum': 0, 'level': 0}
  let l:n = len(l:lines)
  let l:i = 0
  while l:i < l:n
    let l:line = l:lines[l:i]
    let l:type = dialogue#LineType(l:line)

    " Collapse runs of blank/comment lines; the last one inherits the indent
    " of the next real line.
    if l:type ==# 'unknown' || l:type ==# 'comment'
      if l:i + 1 < l:n && index(['unknown', 'comment'], dialogue#LineType(l:lines[l:i + 1])) >= 0
        let l:i += 1
        continue
      endif
    endif

    let l:level = dialogue#IndentLevel(l:line)
    if l:type ==# 'unknown' || l:type ==# 'comment'
      let l:type = 'unknown'
      if l:i + 1 < l:n
        let l:level = dialogue#IndentLevel(l:lines[l:i + 1])
      endif
    endif

    if l:level > len(l:chain)
      call add(l:errors, s:Error(l:file, l:i + 1, l:level,
            \ 'Invalid indentation: ' . l:level . ' indents deep but the parent stack only allows ' . len(l:chain)))
    endif

    " Jump targets
    if l:type ==# 'goto' || ((l:type ==# 'dialogue' || l:type ==# 'response') && l:line =~# ' =>')
      let l:target = matchstr(dialogue#StripIndent(l:line), '=>\%(<\)\=\s*\zs\S\+')
      if l:target !=# '' && l:target !~# '^{{' && l:target !~# '^END!\=$'
        if !has_key(l:all_cues, l:target)
          if l:target =~# '/' && !has_key(l:imports, split(l:target, '/', 1)[0])
            call add(l:errors, s:Error(l:file, l:i + 1, 1, 'Unknown import "' . split(l:target, '/', 1)[0] . '" in jump "' . l:target . '"'))
          else
            call add(l:errors, s:Error(l:file, l:i + 1, 1, 'Unknown cue "' . l:target . '"'))
          endif
        endif
      endif
    endif

    " Condition blocks need content at a deeper indent
    if s:IsBlockOpener(l:type)
      let l:next_level = s:NextCodeLevel(l:lines, l:i + 1, dialogue#IndentLevel(l:line))
      if l:next_level >= 0 && l:next_level <= l:level
        call add(l:errors, s:Error(l:file, l:i + 1, 1, 'Condition has no content (indent the lines that belong to it)'))
      endif
    endif

    " Concurrent lines need a regular dialogue line right before them
    if dialogue#StripIndent(l:line) =~# '^| '
      let l:sibling = s:ConcurrentOrigin(l:lines, l:i, l:level)
      if l:sibling !=# 'dialogue'
        call add(l:errors, s:Error(l:file, l:i + 1, 1, 'Concurrent line has no dialogue line to run with'))
      endif
    endif

    " Update the parent chain
    if l:level > len(l:chain) - 1
      call add(l:chain, l:prev)
    elseif l:level < len(l:chain) - 1
      call s:ResizeList(l:chain, l:level + 1)
    endif

    " "when" must belong to a match (or another when)
    if l:type ==# 'when'
      let l:parent = l:chain[-1]
      if l:parent.type !=# 'match' && l:parent.type !=# 'when'
        call add(l:errors, s:Error(l:file, l:i + 1, 1, '"when" must belong to a "match" block'))
      endif
    endif

    let l:prev = {'type': l:type, 'lnum': l:i + 1, 'level': l:level}
    let l:i += 1
  endwhile

  if a:bang
    silent! cclose
  endif
  if empty(l:errors)
    echo 'Dialogue Manager: no errors found'
    return l:errors
  endif
  call sort(l:errors, function('s:ByLnum'))
  call setqflist(l:errors)
  silent! copen
  echo 'Dialogue Manager: ' . len(l:errors) . ' error' . (len(l:errors) == 1 ? '' : 's')
  return l:errors
endfunction

function! s:Error(file, lnum, col, text) abort
  return {'filename': a:file, 'lnum': a:lnum, 'col': a:col, 'text': '[Dialogue] ' . a:text}
endfunction

function! s:ByLnum(a, b) abort
  return a:a.lnum - a:b.lnum == 0 ? a:a.col - a:b.col : a:a.lnum - a:b.lnum
endfunction

function! s:Trim(text) abort
  return substitute(a:text, '^\s*\|\s*$', '', 'g')
endfunction

function! s:ResizeList(list, size) abort
  while len(a:list) > a:size
    call remove(a:list, -1)
  endwhile
endfunction

" Indent level of the next code line at/from a:index; -1 when none.
function! s:NextCodeLevel(lines, index, ...) abort
  let l:i = a:index
  let l:n = len(a:lines)
  while l:i < l:n
    let l:line = a:lines[l:i]
    if l:line !~# '^\s*$' && dialogue#LineType(l:line) !=# 'comment'
      return dialogue#IndentLevel(l:line)
    endif
    let l:i += 1
  endwhile
  return -1
endfunction

" The line a concurrent "| ..." line belongs to.
function! s:ConcurrentOrigin(lines, index, level) abort
  let l:i = a:index - 1
  while l:i >= 0
    let l:line = a:lines[l:i]
    if l:line !~# '^\s*$' && dialogue#LineType(l:line) !=# 'comment'
      if dialogue#IndentLevel(l:line) > a:level
        let l:i -= 1
        continue
      endif
      return dialogue#LineType(l:line)
    endif
    let l:i -= 1
  endwhile
  return ''
endfunction

" Read cues out of imported files. Returns { 'prefix/cue': lnum, ... }.
" Files that cannot be read are skipped silently.
function! s:ImportedCues(imports, parent_file) abort
  let l:project = s:ProjectRoot(a:parent_file)
  let l:result = {}
  let l:seen = [a:parent_file]
  for l:prefix in keys(a:imports)
    let l:path = a:imports[l:prefix]
    if l:path =~# '^res://'
      if l:project ==# ''
        continue
      endif
      let l:path = l:project . '/' . substitute(l:path, '^res://', '', '')
    endif
    let l:path = fnamemodify(l:path, ':p')
    if !filereadable(l:path) || index(l:seen, l:path) >= 0
      continue
    endif
    call add(l:seen, l:path)
    let l:i = 1
    for l:line in readfile(l:path)
      if dialogue#LineType(l:line) ==# 'cue'
        let l:result[l:prefix . '/' . dialogue#CueName(l:line)] = l:i
      endif
      let l:i += 1
    endfor
  endfor
  return l:result
endfunction

function! s:ProjectRoot(file) abort
  let l:dir = fnamemodify(a:file, ':p:h')
  let l:project = findfile('project.godot', l:dir . ';')
  if l:project ==# ''
    let l:project = findfile('project.godot', '.;')
  endif
  return l:project ==# '' ? '' : fnamemodify(l:project, ':p:h')
endfunction

" ---------------------------------------------------------------------------
" omnifunc — complete cue names after "=> "
" ---------------------------------------------------------------------------

function! dialogue#Complete(findstart, base) abort
  if a:findstart
    let l:before = strpart(getline('.'), 0, col('.') - 1)
    let l:m = matchlist(l:before, '=>\%(<\)\=\s*\%(\h\w*\/\)*\%(\h\w*\)\=$')
    if empty(l:m)
      return -1
    endif
    return strlen(l:before) - strlen(l:m[0])
  endif

  let l:targets = []
  " cues in this file
  for l:line in getline(1, '$')
    if dialogue#LineType(l:line) ==# 'cue'
      call add(l:targets, dialogue#CueName(l:line))
    endif
  endfor
  " cues from imports
  let l:imports = {}
  for l:line in getline(1, '$')
    let l:m = matchlist(l:line, '^import\s\+"\([^"]*\)"\s\+as\s\+\(\S\+\)')
    if !empty(l:m)
      let l:imports[l:m[2]] = l:m[1]
    endif
  endfor
  let l:imported = s:ImportedCues(l:imports, expand('%:p'))
  for l:key in keys(l:imported)
    call add(l:targets, l:key)
  endfor

  call add(l:targets, 'END')
  call add(l:targets, 'END!')

  call sort(uniq(l:targets))
  let l:pattern = '^' . escape(a:base, '.*[]~^$\')
  return filter(l:targets, 'v:val =~# l:pattern')
endfunction

" vim: nowrap sw=2 sts=2 ts=8 noet
