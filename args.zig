const std = @import("std");
const builtin = @import("builtin");

const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

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

pub const Command = struct {
    name: ?[]const u8,
    arguments: ?[][]const u8 = null,
    commands: ?[]Command = null,
    options: ?[]Option = null,
};

const Type = union {
    int: i64,
    uint: u64,
    float: f64,
    string: []const u8,
};

const Option = struct {
    found: ?bool = false,
    long: ?[]const u8 = null,
    short: ?[]const u8 = null,
};

pub fn parse(c: *Command) !void {
    const allocator = std.heap.GeneralPurposeAllocator(.{});
    var iter = try std.process.ArgIterator.initWithAllocator(allocator);
    defer iter.deinit();

    parseIter(c, iter);
}

pub fn parseIter(_: *Command, _: *Iterator) void {
    // while (iter.next()) |arg| {
    //     std.debug.print("==> arg: {s}, @TypeOf(arg): {any}\n", .{ arg, @TypeOf(arg) });
    // }

    // c.options.?[0].value = 1;

    // for (arguments) |arg| {
    //     std.debug.print("==> {s}, {any}\n", .{ arg, @TypeOf(arg) });
    // }
    // std.debug.print("hello! argument: {any}, command: {any}\n", .{ arguments, iter });
}

fn hmm(c: []Command) []Command {
    return c;
}

test "parse" {
    {
        const arguments = &.{ "main", "serial" };
        var iter = IteratorTest{ .args = arguments };

        var subcommands = [_]Command{.{ .name = "serial" }};
        var c = Command{
            .name = "main",
            .commands = &subcommands,
        };

        parseIter(&c, &iter);

        // try expect(c.found);
    }

    var commands = [_]Command{
        Command{ .name = "dfd" },
    };
    var c = Command{
        .name = "",
        // .arguments = null,
        .commands = &commands,
        .options = &.{},
    };

    // var com = Command{ .name = "serial" };
    // _ = &com;

    const arguments = &.{
        "main",
        "lo",
        "!",
    };
    var iter = IteratorTest{ .args = arguments };

    parseIter(&c, &iter);

    var s = [_]u4{ 1, 2, 3 };
    _ = &s;
    // std.debug.print("+++> {}\n", .{@TypeOf(s)});
}

// pub fn parse_struct(s: type) type {
//     return s;
// }

const serial_com = struct {
    commands: struct {} = .{},
    options: struct {
        port: Option = .{},
    } = .{},
};

var config = struct {
    serial: struct {
        port: Option = .{},
    } = .{},

    help: Option = .{ .long = "ff" },
    t: u8 = 1,
}{};

// fn opt(o: anytype) opaque {
//     return o;
// }

fn cmd(c: anytype) void {
    std.debug.print("typeof: {}\n", .{@TypeOf(c)});

    // std.debug.print("fields: {}\n", .{std.meta.fields(c)});
    // inline for (c) |field| {
    //     std.debug.print("filed: {}\n", .{@TypeOf(field)});
    // }
}

test "parse_struct" {
    // std.debug.print("fields: {}\n", .{@typeInfo(config)});

    var val: u8 = 4;
    _ = &val;
    inline for (std.meta.fields(@TypeOf(config))) |field| {
        if (std.mem.eql(u8, field.name, "t")) {
            std.debug.print("field.name: {s}\n", .{field.name});
            @field(config, field.name) = val;
        }
        std.debug.print("name: {s}, type: \n", .{field.name});
        std.debug.print("fields: {}\n", .{field});
    }

    // var opts = @field(config, "options");
    // var help = @field(&opts, "help");
    // _ = &help;
    // std.debug.print("fields: {}\n", .{help});
    // std.debug.print("fields: {}\n", .{@typeInfo(&opts)});
    // std.debug.print("fields: {}\n", .{@typeInfo(&help)});

    // std.debug.print("fields: {}\n", .{@field(config, "options")});
    // std.debug.print("fields: {}\n", .{std.meta.fields(config)});

    // cmd(&config);
}
