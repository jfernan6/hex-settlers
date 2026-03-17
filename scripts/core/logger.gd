extends Node

## Leveled logger. Registered as Autoload "Log".
## Usage: Log.info("msg")  Log.debug("verbose")  Log.warn("problem")  Log.error("critical")
##
## Set Log.current_level = Log.Level.WARN to silence info/debug output in production.

enum Level { DEBUG = 0, INFO = 1, WARN = 2, ERROR = 3 }

var current_level: int = Level.INFO
const BUFFER_SIZE := 500

var _buffer: Array = []


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
