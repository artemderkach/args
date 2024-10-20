# ARGS
library for parsing command line arguments, flags and env variables  
inspired by https://github.com/jessevdk/go-flags  

## examples
```zig
const args = @import("args");

var config = struct {
    file: args.Arg([]const u8) = .{},
    trigger: args.Flag(bool) = .{ .long = "trigger", .short = 't' },
    debug: args.Flag(bool) = .{ .long = "debug", .short = 'd' },
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

TODO:
- add all variable types for flag values
- add support for top-level subcommands
- parse environment variables into flags (add property `.env` to `Flag`)
- add possibility for nesting (subcommands and flags/positional arguments for them)
- add callback function to subcommand that will be called when subcommand is used
- add more sophisticated parsing possibilities for flags `-abc` as 3 short flags
- add more sophisticated parsing possibilities for flags `--fl=123`
