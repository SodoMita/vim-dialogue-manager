" ftdetect/dialogue.vim — detect Godot Dialogue Manager files
"
" The Dialogue Manager names its dialogue resources *.dialogue.

autocmd BufRead,BufNewFile *.dialogue setfiletype dialogue
