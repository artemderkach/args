const std = @import("std");
const args = @import("args.zig");

// zig build-exe example_flags.zig && ./example_flags -d
var config = struct {
    debug: args.Flag(bool) = .{ .long = "debug", .short = 'd' },
    env: args.Flag(?[]const u8) = .{ .long = "env" },
}{};

// zig build-exe
pub fn main() !void {
    try args.parse(&config);

    std.debug.print("debug: {any}\n", .{config.debug.value});
    std.debug.print("env: {any}\n", .{config.env.value});
}
