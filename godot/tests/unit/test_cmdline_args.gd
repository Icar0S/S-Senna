extends GdUnitTestSuite
## CmdlineArgs: flags and `--name=value` / `--name value` options.

const ARGS: PackedStringArray = [
	"--studio", "--capture-out=/tmp/a b.png", "--capture-frames", "12", "--empty=", "--last"
]


func test_has_flag() -> void:
	assert_bool(CmdlineArgs.has_flag(ARGS, "--studio")).is_true()
	assert_bool(CmdlineArgs.has_flag(ARGS, "--last")).is_true()
	assert_bool(CmdlineArgs.has_flag(ARGS, "--stud")).is_false()
	assert_bool(CmdlineArgs.has_flag(PackedStringArray(), "--studio")).is_false()


func test_get_value_with_equals() -> void:
	assert_str(CmdlineArgs.get_value(ARGS, "--capture-out")).is_equal("/tmp/a b.png")
	assert_str(CmdlineArgs.get_value(ARGS, "--empty", "fallback")).is_equal("")


func test_get_value_with_space() -> void:
	assert_str(CmdlineArgs.get_value(ARGS, "--capture-frames")).is_equal("12")


func test_get_value_missing_returns_default() -> void:
	assert_str(CmdlineArgs.get_value(ARGS, "--nope")).is_equal("")
	assert_str(CmdlineArgs.get_value(ARGS, "--nope", "30")).is_equal("30")
	# A flag followed by another option (or by nothing) has no value.
	assert_str(CmdlineArgs.get_value(ARGS, "--studio", "none")).is_equal("none")
	assert_str(CmdlineArgs.get_value(ARGS, "--last", "none")).is_equal("none")


func test_option_name_must_match_exactly() -> void:
	assert_str(CmdlineArgs.get_value(ARGS, "--capture", "none")).is_equal("none")
