extends Node

## Leveled logger. Registered as Autoload "Log".
## Usage: Log.info("msg")  Log.debug("verbose")  Log.warn("problem")  Log.error("critical")
##
## Set Log.current_level = Log.Level.WARN to silence info/debug output in production.
##
## Path constants — single source of truth for all debug output directories.
## debug_controller and game_event_log reference these instead of hardcoding paths.

enum Level { DEBUG = 0, INFO = 1, WARN = 2, ERROR = 3 }

## F12 manual screenshots (player-initiated, kept indefinitely)
const SCREENSHOT_DIR   := "res://debug/screenshots/"
## Overwritten every automated run — always shows the latest run's screenshots
const LATEST_RUN_DIR   := "res://debug/screenshots/latest_run/"
## Overwritten every automated run — maps to what a DB upload will replace later
const LATEST_SESSION_DIR := "res://debug/sessions/latest/"

var current_level: int = Level.INFO
const BUFFER_SIZE := 500

var _buffer: Array = []


func _ready() -> void:
	# Ensure all debug output directories exist on every launch.
	for d: String in [SCREENSHOT_DIR, LATEST_RUN_DIR, LATEST_SESSION_DIR]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(d))


## Wipe a flat directory (files only, no subdirs) before writing new content.
## Used for both latest_run/ and sessions/latest/ at the start of each run.
func clear_dir(res_path: String) -> void:
	var abs := ProjectSettings.globalize_path(res_path)
	var d   := DirAccess.open(abs)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if not name.begins_with("."):
			d.remove(name)
		name = d.get_next()
	d.list_dir_end()


func debug(msg: String) -> void:
	if current_level <= Level.DEBUG:
		var line := "[DEBUG] " + msg
		_push(line)
		print(line)


func info(msg: String) -> void:
	if current_level <= Level.INFO:
		_push(msg)
		print(msg)


func warn(msg: String) -> void:
	var line := "[WARN]  " + msg
	_push(line)
	print(line)


func error(msg: String) -> void:
	var line := "[ERROR] " + msg
	_push(line)
	print(line)
	push_error(line)


## Returns the last n log lines.
func get_recent(n: int = 20) -> Array:
	return _buffer.slice(max(0, _buffer.size() - n))


func _push(line: String) -> void:
	_buffer.append(line)
	if _buffer.size() > BUFFER_SIZE:
		_buffer.pop_front()
