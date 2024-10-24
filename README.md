# ARGS
library for parsing command line arguments, flags and env variables  
inspired by https://github.com/jessevdk/go-flags  

## examples
```zig
const args = @import("args");

var config = struct {
    serial: struct {
        cmd: args.Cmd() = .{ .name = "serial" },
        debug: args.Flag(?bool) = .{ .long = "debug", .short = 'd' },
        port: args.Arg([]const u8) = .{},
    } = .{},
    trigger: args.Flag(bool) = .{ .long = "trigger", .short = 't' },
    debug: args.Flag(?bool) = .{ .long = "debug", .short = 'd' },
    number: args.Flag(f16) = .{ .short = 'n' },
    distance: args.Flag(?f64) = .{ .long = "distance" },
    file: args.Flag([]const u8) = .{ .long = "file", .short = 'f' },
}{};

args.parse(&config);

// do business logic
if (config.trigger) {
    // ...
}

```

## TODO list
DONE:
- top-level parsing flags (short, long)
- top-level parsing positional arguments
- added all variable types for flag values
- optional flag values
- support for top-level subcommands
- add possibility for nesting (subcommands and flags/positional arguments for them)

TODO:
- parse environment variables into flags (add property `.env` to `Flag`)
- add callback function to subcommand that will be called when subcommand is used
- add more sophisticated parsing possibilities for flags `-abc` as 3 short flags
- add more sophisticated parsing possibilities for flags `--fl=123`
- add possibility for negative flag values (currently will be parsed as shourt flag)
- add possible enum inputs
- add tests for invalid flag (without .short and .long)

