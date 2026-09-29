" dialogue.vim — syntax highlighting for Godot Dialogue Manager files
"
" Language:	Dialogue Manager dialogue files (nathanhoad/godot_dialogue_manager)
" Maintainer:	vim-dialogue-manager contributors
" Filenames:	*.dialogue
" License:	MIT
"
" Highlights Dialogue Manager 4 syntax (cues, jumps, conditions, mutations,
" weighted random lines, tags, interpolation, imports, "using" states) as well
" as the 3.x syntax that is still supported ("~ title", "do"/"set" mutations,
" "[if condition]" response conditions, "[ID:...]" static line ids).
"
" The item patterns mirror the compiler's own regexes (see
" addons/dialogue_manager/compiler/compiler_regex.gd), so things that look
" wrong here usually look wrong to the compiler too.
"
" Configuration:			*dialogue-syntax-config*
"   g:dialogue_no_syntax_on_line_comments
"     Dialogue Manager only treats '#' comments as comments when they start
"     the line; trailing '#'s are spoken text. This is reflected here.

if exists('b:current_syntax')
  finish
endif

" The Dialogue Manager treats character names, keywords and cue names
" case-sensitively.
syn case match

" ---------------------------------------------------------------------------
" 1. Expression elements
"
" Contained items: only used inside conditions, mutations, {{...}} and jumps.
" Keeping them contained stops stray numbers/identifiers in spoken dialogue
" from being highlighted.
" ---------------------------------------------------------------------------
syn match dialogueString	    /&\?\%("[^"]*"\|'[^']*'\)/ contained
syn match dialogueNumber	    /\<\d\+\%(\.\d\+\)\=/ contained
syn keyword dialogueBoolean	    true false contained
syn keyword dialogueLogical	    and or not in contained
syn match dialogueOperator	    /==\|!=\|>=\|<=\|&&\|||\|>\|<\|+\|-\|\*\|\/\|%\|=\|\.\|,\|?\.\|!\|(\|)\|\[\|\]\|{\|}/ contained
syn match dialogueIdentifier    /\<\h\w*\>/ contained
syn match dialogueFunctionCall  /\<\h\w*\ze(/ contained
syn match dialogueExprComment   /#.*$/ contained

syn cluster dialogueExpression  contains=dialogueString,dialogueNumber,dialogueBoolean,dialogueLogical,dialogueOperator,dialogueFunctionCall,dialogueIdentifier,dialogueExprComment

" ---------------------------------------------------------------------------
" 2. Inline markup (can appear inside dialogue text and responses)
"
" These are top level so that they light up inside plain dialogue lines; the
" whole-line items further down (conditions, mutations, jumps...) keep them
" out of places where they would be false positives.
" ---------------------------------------------------------------------------
" [ID:SOME_KEY] — static translation/voice-over ids
syn match dialogueLineID	 /\[ID:[^]]*\]/

" [#happy, #mood=surprised] — tags
syn match dialogueTag		 /\[#[^]]*\]/

" [[This|Or this]] — inline random alternatives
syn match dialogueInlineRandom	 /\[\[[^]]*\]\]/

" [b] [i] [color=red] [wait=2] [next=auto] [/b] ... — BBCode-ish tags
syn match dialogueBBCode	 /\[\/\?\h\w*\%(\s*=\s*[^]]*\)\=\]/

" [if condition /] — self-closing response condition
syn match dialogueWrappedCondition /\[if\s.\{-} \/]/ contains=@dialogueExpression
syn match dialogueWrappedDelimiter /\[if\| \/]/ containedin=dialogueWrappedCondition

" [if x]once[/if] and [if x]apple[else]apples[/if] — inline conditionals
syn match dialogueInlineCondition	 /\[if\s[^]]\{-}\%\(\/\)\@<!]/
syn match dialogueInlineConditionElse	 /\[else]/
syn match dialogueInlineConditionEnd	 /\[\/if]/

" [$> wave()] — inline mutations
syn match dialogueInlineMutation	 /\[\%(\$>>\|\$>\|do!\=\|set\)[^]]*]/ contains=@dialogueExpression

" {{expression}} — interpolated values (also used for dynamic character names
" and expression jumps)
syn match dialogueInterpolation	 /{{.\{-}}}/ contains=@dialogueExpression

" ---------------------------------------------------------------------------
" 3. Character names
"
" The Dialogue Manager splits a line on the first ": " — everything before it
" is the character's name. We match that, ignoring the random/response/
" concurrent prefixes that can appear in front. The leading guard characters
" stop the name from swallowing a prefix (eg. "%2 Nathan" or "- Nathan").
" ---------------------------------------------------------------------------
syn match dialogueCharacter	 /\%(^\s*\%(%\S*\s\+\)\=\%(-\s\+\||\s\+\)\=\)\@<=\%({{.\{-}}}\|\%([-|%~#]\)\@![^:]\{-1,}\)\ze: /

" ---------------------------------------------------------------------------
" 4. Line prefixes
" ---------------------------------------------------------------------------
" % / %2 / %2.5 / % [if condition /] — weighted random line prefixes, and the
" bare "%" random block opener
syn match dialogueRandom	 /\%(^\s*\)\@<=%\%(\d\+\%(\.\d\+\)\=\)\=\%(\s*\[if\s.\{-} \/]\)\=/

" - a response
syn match dialogueResponse	 /\%(^\s*\%(%\S*\s\+\)\=\)\@<=-\s/

" | a concurrent (simultaneous) line
syn match dialogueConcurrent	 /\%(^\s*\%(%\S*\s\+\)\=\)\@<=|\s/

" \if, \do, \-, \~, \=>, \% ... — escaped keywords that are really dialogue
syn match dialogueEscape	 /\%(^\s*\)\@<=\\\%(%\|-\|\~\|=>\|if\|elif\|else\|while\|match\|when\|do\|set\|using\)/

" ==== visual separator lines
syn match dialogueSeparator	 /\%(^\s*\)\@<==\{4,}\s*$/

" ---------------------------------------------------------------------------
" 5. Jumps (=> cue, =>< cue, => END, => END!, inline "text => cue")
"
" Transparent: only the arrow, target and END are coloured.
" ---------------------------------------------------------------------------
syn cluster dialogueJump contains=dialogueJumpArrow,dialogueJumpTarget,dialogueJumpEnd,dialogueInterpolation

syn match dialogueJumpArrow	 /=>\%(<\)\=/ contained
syn match dialogueJumpTarget	 /\%(=>\%(<\)\=\s\+\)\@<=\%({{.\{-}}}\|\h\w*\%\(\/\h\w*\)\=\)/ contained
syn match dialogueJumpEnd	 /\%(=>\%(<\)\=\s\+\)\@<=END!\=/ contained

" A jump that starts a line (optionally behind a random prefix)
syn match dialogueGotoLine	 /\%(^\s*\%(%\S*\s\+\)\=\)\@<==>\%(<\)\=\s\+\S.*$/ transparent contains=@dialogueJump
" ... and one at the end of a dialogue/response line
syn match dialogueGotoInline	 /\s\zs=>\%(<\)\=\s\+\S.*$/ transparent contains=@dialogueJump

" ---------------------------------------------------------------------------
" 6. Mutations ($>, $>>, do, do!, set)
" ---------------------------------------------------------------------------
syn cluster dialogueMutation contains=dialogueMutationKeyword,@dialogueExpression

syn match dialogueMutationKeyword /\%(^\s*\%(%\S*\s\+\)\=\)\@<=\%(\$>>\|\$>\|do!\=\|set\)\ze\s/ contained
syn match dialogueMutationLine	 /\%(^\s*\%(%\S*\s\+\)\=\)\@<=\%(\$>>\|\$>\|do!\=\|set\)\s\+\S.*$/ transparent contains=@dialogueMutation

" ---------------------------------------------------------------------------
" 7. Condition blocks (if/elif/else/else if/while/match/when)
" ---------------------------------------------------------------------------
syn cluster dialogueCondition contains=dialogueConditionKeyword,@dialogueExpression

syn match dialogueConditionKeyword /\%(^\s*\%(%\S*\s\+\)\=\)\@<=\%(\%(else\s\+\)\=if\|elif\|else\|while\|match\|when\)\>/ contained
syn match dialogueConditionLine	 /\%(^\s*\%(%\S*\s\+\)\=\)\@<=\%(\%(else\s\+\)\=if\|elif\|else\|while\|match\|when\)\>.*$/ transparent contains=@dialogueCondition

" ---------------------------------------------------------------------------
" 8. File directives
" ---------------------------------------------------------------------------
syn cluster dialogueImport contains=dialogueImportKeyword,dialogueImportPath,dialogueImportAs,dialogueImportPrefix

syn match dialogueImportKeyword /\%(^\s*\)\@<=import\ze\s/ contained
syn match dialogueImportPath	 /"[^"]*"/ contained
syn match dialogueImportAs	 /\<as\>/ contained
syn match dialogueImportPrefix	 /\%(as\s\+\)\@<=\S\+/ contained
syn match dialogueImportLine	 /\%(^\s*\)\@<=import\s\+\S.*$/ transparent contains=@dialogueImport

syn match dialogueUsingKeyword	 /\%(^\s*\)\@<=using\ze\s/ contained
syn match dialogueUsingState	 /\%(using\s\+\)\@<=.*$/ contained
syn match dialogueUsingLine	 /\%(^\s*\)\@<=using\s\+\S.*$/ transparent contains=dialogueUsingKeyword,dialogueUsingState

" ---------------------------------------------------------------------------
" 9. Cues and comments
"
" Defined last so that they win any starting-position ties (eg. "##" over "#").
" ---------------------------------------------------------------------------
syn match dialogueCue		 /\%(^\s*\%(%\S*\s\+\)\=\)\@<=\~.*$/

syn match dialogueComment	 /\%(^\s*\%(%\S*\s\+\)\=\)\@<=#.*$/
syn match dialogueTranslatorNote /\%(^\s*\%(%\S*\s\+\)\=\)\@<=##.*$/

" ---------------------------------------------------------------------------
" 10. Default highlighting groups
"
" The mapping roughly follows the colours the Dialogue Manager editor picks
" from the Godot theme: cues/responses ~ node references, conditions ~
" keywords, mutations ~ functions, members ~ variables, jumps ~ dimmed node
" references, tags ~ string placeholders.
" ---------------------------------------------------------------------------
hi def link dialogueComment		 Comment
hi def link dialogueTranslatorNote	 SpecialComment
hi def link dialogueSeparator		 NonText
hi def link dialogueCue			 Title
hi def link dialogueResponse		 Label
hi def link dialogueConcurrent		 Special
hi def link dialogueRandom		 Number
hi def link dialogueInlineRandom		 Special
hi def link dialogueEscape		 Special
hi def link dialogueCharacter		 Type
hi def link dialogueImportKeyword	 Statement
hi def link dialogueImportPath		 String
hi def link dialogueImportAs		 Statement
hi def link dialogueImportPrefix	 Identifier
hi def link dialogueUsingKeyword	 Statement
hi def link dialogueUsingState		 Identifier
hi def link dialogueConditionKeyword	 Conditional
hi def link dialogueMutationKeyword	 Function
hi def link dialogueJumpArrow		 PreProc
hi def link dialogueJumpTarget		 Type
hi def link dialogueJumpEnd		 Exception
hi def link dialogueWrappedCondition	 Conditional
hi def link dialogueWrappedDelimiter	 Conditional
hi def link dialogueInlineCondition	 Conditional
hi def link dialogueInlineConditionElse	 Conditional
hi def link dialogueInlineConditionEnd	 Conditional
hi def link dialogueInlineMutation	 Function
hi def link dialogueLineID		 Underlined
hi def link dialogueTag			 Special
hi def link dialogueBBCode		 Special
hi def link dialogueInterpolation	 Special
hi def link dialogueString		 String
hi def link dialogueNumber		 Number
hi def link dialogueBoolean		 Boolean
hi def link dialogueLogical		 Conditional
hi def link dialogueOperator		 Operator
hi def link dialogueFunctionCall	 Function
hi def link dialogueIdentifier		 Identifier
hi def link dialogueExprComment	 Comment

" Everything is anchored to the start of a line, so syncing never needs to
" look far back.
syn sync minlines=1

let b:current_syntax = 'dialogue'

" vim: nowrap sw=2 sts=2 ts=8 noet
