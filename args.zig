const std = @import("std");
const builtin = @import("builtin");

const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

const Iterator = if (builtin.is_test) IteratorTest else std.process.ArgIterator;

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

pub fn Flag(comptime T: type) type {
    return struct {
        value: T = undefined,
        long: ?[]const u8 = undefined,
        short: ?u8 = undefined,
    };
}

// parse command line arguments into proivded config
// should be used if you just whant it work
// in case you need finer tuning, use parseIter
pub fn parse(cfg: anytype) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const a = gpa.allocator();
    var iter = try std.process.ArgIterator.initWithAllocator(a);
    defer iter.deinit();

    parseIter(cfg, &iter);
}

// parses command line arguments form provided iterator into provided config
pub fn parseIter(_: anytype, iter: *Iterator) void {
    while (iter.next()) |arg| {
        std.debug.print("arg: {s}\n", .{arg});
    }
}

test "parse" {
    {
        // single boolean flag
        const arguments = &.{ "main", "--trigger" };
        var iter = IteratorTest{ .args = arguments };

        var cfg = struct {
            trigger: Flag(bool) = .{ .long = "trigger" },
        }{};

        parseIter(&cfg, &iter);

        try expect(cfg.trigger.value);
    }
}

const MyFn = fn () void;

fn myfn() void {
    // std.debug.print("YEEEEE\n", .{});
}

var config = struct {
    serial: struct {
        // callback: fn () void,
    } = .{},

    help: Flag(u8) = .{ .long = "help" },
    callback: *const fn () void = myfn,
    t: usize = 1,
}{};

test "parse_struct" {
    // std.debug.print("fields: {}\n", .{@typeInfo(config)});
    // config.help.value;

    // var val: u8 = 4;
    // _ = &val;
    inline for (std.meta.fields(@TypeOf(config))) |field| {
        // std.debug.print("fields: {}\n", .{field});
        // std.debug.print("field.name: {s}, field.type: {any}\n", .{ field.name, field.type });
        // std.debug.print("field.type: {s}, type: \n", .{field.name});
        // @field(config, field.name) = val;
        if (comptime std.mem.eql(u8, field.name, "callback")) {
            @field(config, field.name)();
        }
        if (comptime std.mem.eql(u8, field.name, "t")) {
            // std.debug.print("====> {any}\n", .{@field(config, field.name)});
            // @field(config, field.name) = 2;
            // std.debug.print("field.name: {s}\n", .{field.name});
            // std.debug.print("field.name: {s}\n", .{field.name});
        }
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
