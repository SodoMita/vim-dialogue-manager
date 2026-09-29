#!/usr/bin/env -S godot --headless --script
## dialogue_check.gd — check Dialogue Manager files from the command line.
##
## Used by the vim-dialogue-manager plugin's :make support.
##
## Setup:
##   1. Copy this file into your Godot project (next to project.godot is fine).
##   2. From vim:
##        let g:dialogue_makeprg = 'godot --headless --path . -s dialogue_check.gd -- %:p'
##        :compiler dialogue
##        :make
##
## Or run it directly:
##   godot --headless --path /path/to/project -s dialogue_check.gd -- file.dialogue [more.dialogue]
##
## Errors are printed as "path:line:column: message" (vim's errorformat).
## The exit code is 1 when any file has errors, 0 otherwise.

extends SceneTree

# Adjust if your addon lives somewhere else.
const COMPILER_PATH := "res://addons/dialogue_manager/compiler/compiler.gd"
const CONSTANTS_PATH := "res://addons/dialogue_manager/constants.gd"
const CACHE_PATH := "res://addons/dialogue_manager/utilities/dialogue_cache.gd"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("usage: godot --headless --path <project> -s dialogue_check.gd -- <file.dialogue> [...]")
		quit(0)
		return

	var compiler: Variant = load(COMPILER_PATH)
	var constants: Variant = load(CONSTANTS_PATH)
	var cache: Variant = load(CACHE_PATH)
	if compiler == null or constants == null or cache == null:
		print("error:1:1: Cannot load the Dialogue Manager addon (looked for %s)" % [COMPILER_PATH])
		quit(1)
		return

	# Prime the dialogue cache so that imports resolve outside of the editor.
	var seen := {}
	for arg in args:
		_prime_cache(cache, _resolve(arg), seen)

	var errors_found := false
	for arg in args:
		var path := _resolve(arg)
		if not FileAccess.file_exists(path):
			print("%s:1:1: File not found" % [path])
			errors_found = true
			continue

		var text := FileAccess.get_file_as_string(path)
		var result: Variant = compiler.compile_string(text, ProjectSettings.localize_path(path))
		if result.errors.is_empty():
			print("%s: OK" % [path])
		else:
			errors_found = true
			for error in result.errors:
				print("%s:%d:%d: %s" % [path, error.line_number, error.column_number, constants.get_error_message(error.error)])

	quit(1 if errors_found else 0)


## Register a file (and, recursively, its imports) with the DM cache.
func _prime_cache(cache: Variant, path: String, seen: Dictionary) -> void:
	if path == "" or seen.has(path):
		return
	seen[path] = true
	if not FileAccess.file_exists(path):
		return

	var res_path := ProjectSettings.localize_path(path)
	cache.add_file(res_path)

	var text := FileAccess.get_file_as_string(path)
	var import_regex := RegEx.create_from_string("import \"(?<path>[^\"]+)\"")
	var id_regex := RegEx.create_from_string("\\[ID:(?<id>[^\\]]+)\\]")
	for line in text.split("\n"):
		var id_found := id_regex.search(line)
		if id_found:
			cache.known_static_ids[id_found.strings[id_found.names.get("id")]] = res_path

		var import_found := import_regex.search(line)
		if import_found == null:
			continue
		var import_path: String = import_found.strings[import_found.names.get("path")]
		if import_path.begins_with("uid://"):
			import_path = ResourceUID.get_id_path(ResourceUID.text_to_id(import_path))
		if not import_path.begins_with("res://"):
			import_path = "res://" + import_path
		_prime_cache(cache, ProjectSettings.globalize_path(import_path), seen)


func _resolve(path: String) -> String:
	if path.begins_with("res://"):
		return ProjectSettings.globalize_path(path)
	if path.is_absolute_path():
		return path
	return ProjectSettings.globalize_path("res://" + path)
