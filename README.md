
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
