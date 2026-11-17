class_name CmdlineArgs
extends RefCounted
## Helpers to read command-line arguments (usually `OS.get_cmdline_user_args()`).
##
## Kept free of `OS` calls so callers can pass any argument list, which makes
## the code that depends on arguments testable.


## Returns true when [param flag] (e.g. `--studio`) is present in [param args].
static func has_flag(args: PackedStringArray, flag: String) -> bool:
	return args.has(flag)


## Returns the value of the option [param option_name] (e.g. `--capture-out`).
## Accepts both `--name=value` and `--name value`. Returns [param default_value]
## when the option is missing or has no value.
static func get_value(
	args: PackedStringArray, option_name: String, default_value: String = ""
) -> String:
	var prefix: String = option_name + "="
	for i: int in args.size():
		var arg: String = args[i]
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
		if arg == option_name and i + 1 < args.size() and not args[i + 1].begins_with("--"):
			return args[i + 1]
	return default_value
