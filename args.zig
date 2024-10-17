const std = @import("std");
const builtin = @import("builtin");

const IteratorTest = struct {
    args: []const []const u8,
    index: usize = 0,

    pub fn next(iter: *IteratorTest) ?[]const u8 {
        if (iter.index >= iter.args.len) return null;
        const arg = iter.args[iter.index];
        iter.index += 1;
        return arg;
    }
};

const Iterator = if (builtin.is_test) IteratorTest else std.process.ArgIterator;

const Command = struct {
    name: []const u8,
    arguments: ?[][]const u8 = null,
    commands: ?[]Command = null,
    options: ?[]Option = null,
};

const Option = struct {
    long: []const u8,
    short: []const u8,
    type: type,
    value: u8,
};

pub fn parse(c: *Command, iter: *Iterator) void {
    while (iter.next()) |arg| {
        std.debug.print("==> arg: {s}, @TypeOf(arg): {any}\n", .{ arg, @TypeOf(arg) });
    }

    c.options.?[0].value = 1;

    // for (arguments) |arg| {
    //     std.debug.print("==> {s}, {any}\n", .{ arg, @TypeOf(arg) });
    // }
    // std.debug.print("hello! argument: {any}, command: {any}\n", .{ arguments, iter });
}

test "parse" {
    // const name = "serial";
    var c = Command{
        .name = "",
        // .arguments = null,
        // .commands = null,
        .options = &[_]Option{
            Option{ .short = "-h", .long = "--help", .type = []const u8, .value = 1 },
        },
    };

    // c.commands = &[_]Command{
    //     Command{ .name = "serial" },
    // };

    const arguments = &.{
        "main",
        "lo",
        "!",
    };

    var iter = IteratorTest{ .args = arguments };

    parse(&c, &iter);

    // const allocator = std.testing.allocator;
    // var iter = try std.process.ArgIterator.initWithAllocator(allocator);
    // defer iter.deinit();
    //
    // while (iter.next()) |arg| {
    //     std.debug.print("++> {s}, {any}\n", .{ arg, @TypeOf(arg) });
    // }
    // std.debug.print("--> {any}, {}\n", .{ std.os.argv, @TypeOf(std.os.argv) });

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

    // const e: []const [:0]const u8 = &.{
    //     "aaa",
    //     "-h",
    //     "--hello",
    // };
    // std.debug.print("--> {any}, {}\n", .{ std.os.argv, @TypeOf(std.os.argv) });
    // std.debug.print("--> {any}, {}\n", .{ @TypeOf(e), @TypeOf(&e) });
    // std.debug.print("--> {any}\n", .{@TypeOf(e[0..])});
    //
    // for (e) |arg| {
    //     std.debug.print("==> {s}, {any}\n", .{ arg, @TypeOf(arg) });
    // }
    //
    // parse(e, iter);
    //
    // const t = [_][:0]const u8{
    //     [:0]u8{"some"},
    // };
    // for (t) |arg| {
    //     std.debug.print("==> {s}, {any}\n", .{ arg, @TypeOf(arg) });
    // }
    //

    // parse(c);
    // std.os.ar
    //
    // const str_literal = "hello";
    // var str_literal_var = "hello";
    // _ = &str_literal_var;
    // str_literal_var[2] = 'h';
    // const str_literal_ptr: []u8 = std.mem.sliceTo(&.{"hello?"}, 5);

    // var str_var = [_]u8{ 'h', 'e', 'o' };
    // _ = &str_var;
    // var i: usize = 0;
    // _ = &i;
    // str_var[i..]

    // std.debug.print("str_literal: {}\n", .{@TypeOf(str_literal)});
    // std.debug.print("str_literal_var: {}\n", .{@TypeOf(str_literal_var)});
    // std.debug.print("str_literal_type: {}\n", .{@TypeOf(str_literal_ptr)});
    // std.debug.print("str_var: {}\n", .{@TypeOf(str_var)});
    // std.debug.print("str_var_slice: {}\n", .{@TypeOf(str_var[i..])});

    // std.debug.print("str_var_slice: {}\n", .{@TypeOf(std.os.argv)});
}
