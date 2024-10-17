const std = @import("std");
const args = @import("args.zig");

pub fn main() !void {
    var subcommand = [_]args.Command{.{
        .name = "serial",
    }};
    var command = args.Command{
        .name = "main",
        .commands = &subcommand,
    };

    args.parse(&command);
}
