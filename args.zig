const std = @import("std");
const builtin = @import("builtin");

const IteratorTest = struct {
    args: [][:0]u8,

    pub fn next(_: *IteratorTest) ?([:0]const u8) {
        return null;
    }
};

const Iterator = if (builtin.is_test) IteratorTest else std.process.ArgIterator;

const Command = struct {
    name: []const u8,
    arguments: ?[][]const u8,
    commands: ?[]Command,
    options: ?[]Option,
};

const Option = struct {
    long: []u8,
    short: []u8,
    type: type,
};

pub fn parse(arguments: []const [:0]const u8, iter: Iterator) void {
    for (arguments) |arg| {
        std.debug.print("==> {s}, {any}\n", .{ arg, @TypeOf(arg) });
    }
    std.debug.print("hello! argument: {any}, command: {any}\n", .{ arguments, iter });
}

test "parse" {
    // const name = "serial";
    // const c = Command{
    //     .name = "serial",
    //     .arguments = null,
    //     .commands = null,
    //     .options = null,
    // };

    const allocator = std.testing.allocator;
    var iter = try std.process.ArgIterator.initWithAllocator(allocator);
    defer iter.deinit();

    while (iter.next()) |arg| {
        std.debug.print("++> {s}, {any}\n", .{ arg, @TypeOf(arg) });
    }
    std.debug.print("--> {any}, {}\n", .{ std.os.argv, @TypeOf(std.os.argv) });

    // const inp: [std.os.argv.len][:0]const u8 = undefined;
    // std.debug.print("00000> {any}\n", .{@TypeOf(inp)});

    // const a = [_:0]u8{ 'h', 'e', 'l', 'l' };
    // std.debug.print("==> {s}, {any}\n", .{ a, @TypeOf(a) });
    //
    // const b = "hell";
    // std.debug.print("==> {s}, {any}\n", .{ b, @TypeOf(b) });
    //
    // const c: []const u8 = "hell";
    // std.debug.print("==> {s}, {any}\n", .{ c, @TypeOf(c) });

    const e: []const [:0]const u8 = &.{
        "aaa",
        "-h",
        "--hello",
    };
    std.debug.print("--> {any}, {}\n", .{ std.os.argv, @TypeOf(std.os.argv) });
    std.debug.print("--> {any}, {}\n", .{ @TypeOf(e), @TypeOf(&e) });
    std.debug.print("--> {any}\n", .{@TypeOf(e[0..])});

    for (e) |arg| {
        std.debug.print("==> {s}, {any}\n", .{ arg, @TypeOf(arg) });
    }

    parse(e, iter);
    //
    // const t = [_][:0]const u8{
    //     [:0]u8{"some"},
    // };
    // for (t) |arg| {
    //     std.debug.print("==> {s}, {any}\n", .{ arg, @TypeOf(arg) });
    // }

    // parse(c);
}
