const std = @import("std");

const command = struct {
    name: []const u8,
    commands: ?[]command,
    options: ?[]option,
};

const option = struct {
    long: []u8,
    short: []u8,
    type: type,
};

pub fn parse(arguments: [][]u8, _: command) void {
    std.debug.print("hello! \n", .{});
}

test "parse" {
    // const name = "serial";
    const c = command{
        .name = "serial",
        .commands = null,
        .options = null,
    };

    std.process.ArgIteratorGeneral()


    parse(c);
}
