# vim-dialogue-manager

Vim/Neovim support for dialogue files written with [Nathan Hoad's Dialogue
Manager](https://github.com/nathanhoad/godot_dialogue_manager) for Godot.

```
~ start                                             ← folds per cue

Nathan: Hey, welcome to the Dialogue Manager! [ID:WELCOME]
Nathan: You have {{GameState.apples}} apples.
% Nathan: I might say this
%3 Nathan: ...or three times this

if GameState.has_met_nathan == false
    $> GameState.animate("Nathan", "Wave")
    Nathan: Hi, I'm Nathan.

- Tell me more [if not GameState.asked /]
    Nathan: You write dialogue like a script...
    =>< snippets/banter
- Nothing, thanks => END
```

## Features

- **Syntax highlighting** for Dialogue Manager 4 (cues `~`, jumps `=>`/`=><`,
  condition blocks `if`/`elif`/`else`/`while`/`match`/`when`, mutations `$>`,
  weighted random lines `%`, `%3`, tags `[#happy]`, `{{interpolation}}`,
  imports, `using` states, `| concurrent` lines, `[ID:...]` translation ids,
  BBCode tags) plus the supported 3.x syntax (`do`/`set` mutations,
  `[if condition]` response conditions).
  The patterns mirror the compiler's own regexes, so what looks wrong in Vim
  is usually wrong in Godot too.
- **Indenting** that follows the compiler's rules: children under responses
  and condition blocks, sibling alignment for `- ` responses, `elif`/`else`
  line up with their `if`, cues at the left margin. Re-indenting a valid
  file (`gg=G`) is a no-op — indents are only corrected when they are
  structurally impossible. Tab / 4-space / 2-space styles are detected from
  the file.
- **Folding** — one fold per `~ cue`, nested folds for response branches and
  condition blocks.
- **Navigation** — `]]`/`[[` between cues, `gd` to jump from `=> cue` to its
  definition (even into imported files).
- **Completion** — `CTRL-X CTRL-O` completes cue names after `=> `, including
  `prefix/cue` names from imports, plus `END`/`END!`.
- **Linting** — `:DialogueCheck` re-implements the compiler's structural
  checks in plain Vimscript: unknown jump targets, invalid indentation,
  condition blocks with no content, duplicate cues, `when` outside `match`,
  orphaned `[ID:...]`s, and more. No Godot needed.
- **`:make` support** — plug in the real compiler through
  `tools/dialogue_check.gd` if you want the full set of errors.

Works with Vim 8.0+ and Neovim (both run the same 140-assertion test suite
in CI), no dependencies.

The line classification, indentation counting and linter checks were written
against the Dialogue Manager compiler's own source and verified with the real
compiler (Dialogue Manager 4.1 on Godot 4.7): the linter reports the same
structural errors, and `examples/example.dialogue` compiles cleanly.

`examples/` contains that example file plus a tiny Godot project (drop the
`addons/dialogue_manager` addon into it to open it in the editor), and
`syntax-preview.html` — a self-contained rendering of the highlighting.

## Installation

**vim-plug**

```vim
Plug 'nathanhoad/godot_dialogue_manager'  " (optional, in your game repo as a submodule)"
Plug 'yourname/vim-dialogue-manager'
```

**packer.nvim**

```lua
use { 'yourname/vim-dialogue-manager' }
```

**lazy.nvim**

```lua
{ 'yourname/vim-dialogue-manager', ft = 'dialogue' }
```

**Vim 8+ packages**

```sh
git clone https://github.com/yourname/vim-dialogue-manager \
  ~/.vim/pack/plugins/start/vim-dialogue-manager
```

**Manual**: copy the `ftdetect`, `ftplugin`, `indent`, `syntax`,
`compiler`, `autoload` and `doc` directories into your runtime path, then
run `:helptags ALL` for `:h dialogue.txt`.

## Usage

Open any `*.dialogue` file — everything below is automatic.

| Key / Command      | What it does                                       |
|--------------------|----------------------------------------------------|
| `]]` / `[[`        | Jump to the next / previous `~ cue`                |
| `gd`               | Jump to the definition of the cue under `=> ...`   |
| `CTRL-X CTRL-O`    | Complete cue names after `=> `                     |
| `:DialogueCues`    | List every cue in the quickfix window              |
| `:DialogueCheck`   | Lint the file with the built-in checks             |
| `:make`            | Run the configured external checker (see below)    |
| `zM` / `zR`        | Fold away everything / unfold (per-cue folds)      |

### Checking with the real compiler

`:DialogueCheck` catches structural mistakes without Godot. For the full
compiler, copy `tools/dialogue_check.gd` into your Godot project and add to
your vimrc:

```vim
let g:dialogue_makeprg = 'godot --headless --path . -s dialogue_check.gd -- %:p'
```

then `:compiler dialogue` and `:make` from a dialogue buffer.

## Options

```vim
let g:dialogue_no_mappings = 1   " don't create [[ ]] gd mappings
let g:dialogue_folding = 0       " don't set up cue folding
let g:dialogue_indent = 0        " keep your own tabstop/shiftwidth
```

See `:h dialogue.txt` for the full documentation, including all
highlighting groups (e.g. `highlight link dialogueCharacter Comment`).

## Development

Run the test suite with Vim or Neovim:

```sh
sh tests/run.sh        # or: sh tests/run.sh nvim
```

`examples/example.dialogue` exercises every supported construct.

## License

MIT — see [LICENSE](LICENSE). This plugin is not affiliated with the
Dialogue Manager project; it just reads its excellent file format.
