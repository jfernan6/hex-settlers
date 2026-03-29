extends Node

## Lightweight test framework for Hex Settlers.
## Run with:  godot -- --run-tests
##
## Each test suite is a RefCounted script in scripts/tests/ named test_*.gd.
## It must expose func run() and store _runner = self before assertions.

var _pass_count: int = 0
var _fail_count: int = 0
var _current_suite: String = ""

const SUITES := [
	"res://scripts/tests/test_hex_grid.gd",
	"res://scripts/tests/test_dev_cards.gd",
	"res://scripts/tests/test_player.gd",
	"res://scripts/tests/test_game_state.gd",
	"res://scripts/tests/test_ai_player.gd",
	"res://scripts/tests/test_gameplay_action_controller.gd",
]


func run_all() -> void:
	print("\n" + "=".repeat(60))
	print("  HEX SETTLERS — UNIT TEST SUITE")
	print("=".repeat(60))

	for path in SUITES:
		_run_suite(path)

	print("\n" + "=".repeat(60))
	var status := "ALL PASS" if _fail_count == 0 else "%d FAILURES" % _fail_count
	print("  RESULTS:  PASS=%d  FAIL=%d  — %s" % [_pass_count, _fail_count, status])
	print("=".repeat(60) + "\n")

	if _fail_count > 0:
		Log.error("Tests FAILED — %d failure(s) detected" % _fail_count)
	else:
		Log.info("[TESTS] All %d tests passed" % _pass_count)


func _run_suite(path: String) -> void:
	var script = load(path)
	if script == null:
		print("  [SKIP] %s — not found" % path.get_file())
		return
	_current_suite = path.get_file().trim_suffix(".gd")
	print("\n  [SUITE] %s" % _current_suite)
	var instance: RefCounted = script.new()
	instance.set("_runner", self)
	instance.run()


# ---------------------------------------------------------------
# Assertion helpers — called by test suites via _runner.assert_*
# ---------------------------------------------------------------

func assert_eq(actual, expected, label: String) -> void:
	if actual == expected:
		_pass(label)
	else:
		_fail(label, "got=%s  expected=%s" % [str(actual), str(expected)])


func assert_true(condition: bool, label: String) -> void:
	if condition:
		_pass(label)
	else:
		_fail(label, "expected true, got false")


func assert_false(condition: bool, label: String) -> void:
	if not condition:
		_pass(label)
	else:
		_fail(label, "expected false, got true")


func assert_gt(a, b, label: String) -> void:
	if a > b:
		_pass(label)
	else:
		_fail(label, "%s is not > %s" % [str(a), str(b)])


func assert_ge(a, b, label: String) -> void:
	if a >= b:
		_pass(label)
	else:
		_fail(label, "%s is not >= %s" % [str(a), str(b)])


func _pass(label: String) -> void:
	_pass_count += 1
	print("    PASS  %s :: %s" % [_current_suite, label])


func _fail(label: String, detail: String = "") -> void:
	_fail_count += 1
	print("    FAIL  %s :: %s  (%s)" % [_current_suite, label, detail])
