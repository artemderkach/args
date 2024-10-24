const std = @import("std");
const builtin = @import("builtin");

const testing = std.testing;
const expectEqual = testing.expectEqual;
const expectEqualSlices = testing.expectEqualSlices;

pub const MyFn = fn () void;

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

    pub fn skip(iter: *IteratorTest) bool {
        if (iter.index >= iter.args.len) return false;
        iter.index += 1;
        return true;
    }
};

const FlagTypePrefix = "args.Flag";
/// struct representing command line flag (both short and long)
pub fn Flag(comptime T: type) type {
    return struct {
        value: T = undefined,
        long: []const u8 = undefined,
        short: u8 = undefined,
        called: bool = false,
    };
}

const ArgTypePrefix = "args.Arg";
/// struct represenging positional argument
pub fn Arg(comptime T: type) type {
    return struct {
        value: T = undefined,
        called: bool = false,
    };
}

const CmdTypePrefix = "args.Cmd";
/// struct representing subcommand
pub fn Cmd() type {
    return struct {
        name: []const u8 = undefined,
        called: bool = false,
    };
}

/// parse command line arguments into proivded config
/// should be used if you just whant it work
/// in case you need finer tuning, use parseIter
pub fn parse(config: anytype) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var iter = try std.process.ArgIterator.initWithAllocator(allocator);
    defer iter.deinit();

    try parseIter(allocator, &iter, config);
}

/// parse command line arguments with provided allocator
pub fn parseAlloc(allocator: std.mem.Allocator, config: anytype) !void {
    var iter = try std.process.ArgIterator.initWithAllocator(allocator);
    defer iter.deinit();

    try parseIter(config, &iter);
}

/// parses command line arguments that are retrieved form iterator
pub fn parseIter(allocator: std.mem.Allocator, iter: *Iterator, config: anytype) !void {
    var pa = try parseArgs(allocator, iter);
    defer pa.deinit(allocator);

    if (!pa.skip()) unreachable;

    try applyConfig(&pa, config);

    pa.reset();
    try secondPass(&pa, config);
    pa.reset();
    try thirdPass(&pa, config);
}

fn applyConfig(pa: *ParsedArgs, config: anytype) !void {
    while (pa.next()) |arg| {
        // std.debug.print("arg: {any}, {s}\n", .{ arg.Type, arg.value });
        switch (arg.Type) {
            .long, .short => {
                try applyFlag(pa, config, arg);
            },
            .arg => {
                try applyArg(pa, config, arg);
            },
        }
    }
}

fn secondPass(pa: *ParsedArgs, config: anytype) !void {
    pa.reset();
    while (pa.nextFlag()) |arg| {
        try applyFlag(pa, config, arg);
    }

    inline for (std.meta.fields(@TypeOf(config.*))) |field| blk: {
        if (comptime std.mem.startsWith(u8, @typeName(field.type), FlagTypePrefix)) break :blk;
        if (comptime std.mem.startsWith(u8, @typeName(field.type), ArgTypePrefix)) break :blk;
        if (comptime std.mem.startsWith(u8, @typeName(field.type), CmdTypePrefix)) break :blk;

        const cfg = &(@field(config, field.name));
        inline for (std.meta.fields(@TypeOf(cfg.*))) |inner_field| inner_blk: {
            if (!comptime std.mem.startsWith(u8, @typeName(inner_field.type), CmdTypePrefix)) break :inner_blk;

            try secondPass(pa, cfg);
        }
    }
}

fn thirdPass(pa: *ParsedArgs, config: anytype) !void {
    pa.reset();

    inline for (std.meta.fields(@TypeOf(config.*))) |field| {
        if (comptime std.mem.startsWith(u8, @typeName(field.type), ArgTypePrefix)) {
            if (pa.nextArg()) |arg| {
                if (!@field(config, field.name).called) {
                    pa.values[arg.index].used = true;
                    @field(config, field.name).value = arg.value;
                    @field(config, field.name).called = true;
                }
            }

            return;
        }
    }

    inline for (std.meta.fields(@TypeOf(config.*))) |field| blk: {
        if (comptime std.mem.startsWith(u8, @typeName(field.type), FlagTypePrefix)) break :blk;
        if (comptime std.mem.startsWith(u8, @typeName(field.type), ArgTypePrefix)) break :blk;
        if (comptime std.mem.startsWith(u8, @typeName(field.type), CmdTypePrefix)) break :blk;

        const cfg = &(@field(config, field.name));
        inline for (std.meta.fields(@TypeOf(cfg.*))) |inner_field| inner_blk: {
            if (!comptime std.mem.startsWith(u8, @typeName(inner_field.type), CmdTypePrefix)) break :inner_blk;

            try thirdPass(pa, cfg);
        }
    }
}

fn applyFlag(pa: *ParsedArgs, config: anytype, arg: ParsedArg) !void {
    inline for (std.meta.fields(@TypeOf(config.*))) |field| blk: {
        if (comptime !std.mem.startsWith(u8, @typeName(field.type), FlagTypePrefix)) break :blk;

        const f = @field(config, field.name);
        if (f.called) break :blk;
        if (arg.used) break :blk;
        if (arg.Type == .long and !std.mem.eql(u8, f.long, arg.value)) break :blk;
        if (arg.Type == .short and f.short != (arg.value)[0]) break :blk;

        switch (@TypeOf(f.value)) {
            bool, ?bool => {
                pa.values[arg.index].used = true;
                @field(config, field.name).value = true;
                @field(config, field.name).called = true;
            },
            []const u8, ?[]const u8 => {
                pa.values[arg.index].used = true;
                if (pa.next()) |flag_value| {
                    pa.values[flag_value.index].used = true;
                    @field(config, field.name).value = flag_value.value;
                    @field(config, field.name).called = true;
                }
            },
            i8, u8, i16, u16, i32, u32, i64, u64, i128, u128 => {
                pa.values[arg.index].used = true;
                if (pa.next()) |flag_value| {
                    pa.values[flag_value.index].used = true;
                    @field(config, field.name).value = try std.fmt.parseInt(@TypeOf(f.value), flag_value.value, 0);
                    @field(config, field.name).called = true;
                }
            },
            ?i8, ?u8, ?i16, ?u16, ?i32, ?u32, ?i64, ?u64, ?i128, ?u128 => {
                pa.values[arg.index].used = true;
                if (pa.next()) |flag_value| {
                    pa.values[flag_value.index].used = true;
                    @field(config, field.name).value = try std.fmt.parseInt(@TypeOf(f.value.?), flag_value.value, 0);
                    @field(config, field.name).called = true;
                }
            },
            f16, f32, f64, f128 => {
                pa.values[arg.index].used = true;
                if (pa.next()) |flag_value| {
                    pa.values[flag_value.index].used = true;
                    @field(config, field.name).value = try std.fmt.parseFloat(@TypeOf(f.value), flag_value.value);
                    @field(config, field.name).called = true;
                }
            },
            ?f16, ?f32, ?f64, ?f128 => {
                pa.values[arg.index].used = true;
                if (pa.next()) |flag_value| {
                    pa.values[flag_value.index].used = true;
                    @field(config, field.name).value = try std.fmt.parseFloat(@TypeOf(f.value.?), flag_value.value);
                    @field(config, field.name).called = true;
                }
            },
            else => {
                unreachable;
            },
        }
    }
}

fn applyArg(pa: *ParsedArgs, config: anytype, arg: ParsedArg) !void {
    inline for (std.meta.fields(@TypeOf(config.*))) |field| {
        if (comptime std.mem.startsWith(u8, @typeName(field.type), CmdTypePrefix)) continue;
        if (comptime std.mem.startsWith(u8, @typeName(field.type), FlagTypePrefix)) continue;

        if (comptime std.mem.startsWith(u8, @typeName(field.type), ArgTypePrefix)) {
            if (!@field(config, field.name).called) {
                pa.values[arg.index].used = true;
                @field(config, field.name).value = arg.value;
                @field(config, field.name).called = true;

                return;
            }
        } else {
            inline for (std.meta.fields(@TypeOf(@field(config, field.name)))) |inner_field| {
                if (comptime std.mem.startsWith(u8, @typeName(inner_field.type), CmdTypePrefix)) {
                    if (std.mem.eql(u8, @field(@field(config, field.name), inner_field.name).name, arg.value)) {
                        pa.values[arg.index].used = true;
                        const cfg = &(@field(config, field.name));
                        @field(@field(config, field.name), inner_field.name).called = true;

                        try applyConfig(pa, cfg);

                        return;
                    }
                }
            }
        }
    }
}

test "parseIter" {
    const allocator = std.testing.allocator;
    {
        // nothing to parse except main command
        var config = struct {}{};

        const arguments = &.{"main"};

        var iter = IteratorTest{ .args = arguments };
        try parseIter(allocator, &iter, &config);
    }
    {
        // parse only long flag
        var config = struct {
            trigger: Flag(bool) = .{ .long = "trigger" },
        }{};

        const arguments = &.{ "main", "--trigger" };

        var iter = IteratorTest{ .args = arguments };
        try parseIter(allocator, &iter, &config);

        try expectEqual(true, config.trigger.value);
        try expectEqual(true, config.trigger.called);
    }
    {
        // parse only short flag
        var config = struct {
            trigger: Flag(bool) = .{ .short = 't' },
        }{};

        const arguments = &.{ "main", "-t" };

        var iter = IteratorTest{ .args = arguments };
        try parseIter(allocator, &iter, &config);

        try expectEqual(true, config.trigger.value);
    }
    {
        // parse both short and long flags
        var config = struct {
            trigger: Flag(bool) = .{ .long = "trigger" },
            debug: Flag(bool) = .{ .short = 'd' },
        }{};

        const arguments = &.{ "main", "-d", "--trigger" };

        var iter = IteratorTest{ .args = arguments };
        try parseIter(allocator, &iter, &config);

        try expectEqual(true, config.trigger.value);
        try expectEqual(true, config.debug.value);
        try expectEqual(true, config.trigger.called);
        try expectEqual(true, config.debug.called);
    }
    {
        // optional flags
        var config = struct {
            trigger: Flag(?bool) = .{ .long = "trigger" },
            debug: Flag(?bool) = .{ .short = 'd' },
        }{};

        const arguments = &.{ "main", "--trigger" };

        var iter = IteratorTest{ .args = arguments };
        try parseIter(allocator, &iter, &config);

        try expectEqual(true, config.trigger.value);
        try expectEqual(null, config.debug.value);
        try expectEqual(true, config.trigger.called);
        try expectEqual(false, config.debug.called);
    }
    {
        // parse both short and long flags
        var config = struct {
            trigger: Flag(bool) = .{ .long = "trigger", .short = 't' },
            debug: Flag(bool) = .{ .long = "debug", .short = 'd' },
        }{};

        const arguments = &.{ "main", "-d", "--trigger" };

        var iter = IteratorTest{ .args = arguments };
        try parseIter(allocator, &iter, &config);

        try expectEqual(true, config.trigger.value);
        try expectEqual(true, config.debug.value);
        try expectEqual(true, config.trigger.called);
        try expectEqual(true, config.debug.called);
    }
    {
        // some values not provided
        var config = struct {
            trigger: Flag(bool) = .{ .long = "trigger", .short = 't' },
            debug: Flag(bool) = .{ .long = "debug", .short = 'd' },
        }{};

        const arguments = &.{ "main", "--debug" };

        var iter = IteratorTest{ .args = arguments };
        try parseIter(allocator, &iter, &config);

        try expectEqual(false, config.trigger.value);
        try expectEqual(true, config.debug.value);
        try expectEqual(false, config.trigger.called);
        try expectEqual(true, config.debug.called);
    }
    {
        // default values
        var config = struct {
            trigger: Flag(bool) = .{ .long = "trigger", .short = 't', .value = true },
            debug: Flag(bool) = .{ .long = "debug", .short = 'd', .value = false },
        }{};

        const arguments = &.{"main"};

        var iter = IteratorTest{ .args = arguments };
        try parseIter(allocator, &iter, &config);

        try expectEqual(true, config.trigger.value);
        try expectEqual(false, config.debug.value);
        try expectEqual(false, config.trigger.called);
        try expectEqual(false, config.debug.called);
    }
    {
        // empty command
        // default values should be changed
        var config = struct {
            serial: struct {} = .{},
            trigger: Flag(bool) = .{ .long = "trigger", .short = 't', .value = false },
            debug: Flag(bool) = .{ .long = "debug", .short = 'd', .value = false },
        }{};

        const arguments = &.{ "main", "--debug", "--trigger" };

        var iter = IteratorTest{ .args = arguments };
        try parseIter(allocator, &iter, &config);

        try expectEqual(true, config.trigger.value);
        try expectEqual(true, config.debug.value);
        try expectEqual(true, config.trigger.called);
        try expectEqual(true, config.debug.called);
    }
    {
        // parse positional argument
        var config = struct {
            file: Arg([]const u8) = .{},
        }{};

        const arguments = &.{ "main", "input.txt" };

        var iter = IteratorTest{ .args = arguments };
        try parseIter(allocator, &iter, &config);

        try expectEqualSlices(u8, "input.txt", config.file.value);
        try expectEqual(true, config.file.called);
    }
    {
        // parse positional argument with flags
        var config = struct {
            file: Arg([]const u8) = .{},
            trigger: Flag(bool) = .{ .long = "trigger", .short = 't' },
            debug: Flag(bool) = .{ .long = "debug", .short = 'd' },
        }{};

        const arguments = &.{ "main", "--debug", "input.txt", "-t" };

        var iter = IteratorTest{ .args = arguments };
        try parseIter(allocator, &iter, &config);

        try expectEqualSlices(u8, "input.txt", config.file.value);
        try expectEqual(true, config.trigger.value);
        try expectEqual(true, config.debug.value);
        try expectEqual(true, config.file.called);
        try expectEqual(true, config.trigger.called);
        try expectEqual(true, config.debug.called);
    }
    {
        // flag with string value
        var config = struct {
            file: Flag([]const u8) = .{ .long = "file", .short = 'f' },
            debug: Flag(bool) = .{ .long = "debug", .short = 'd' },
        }{};

        const arguments = &.{ "main", "--file", "input.txt", "-d" };

        var iter = IteratorTest{ .args = arguments };
        try parseIter(allocator, &iter, &config);

        try expectEqualSlices(u8, "input.txt", config.file.value);
        try expectEqual(true, config.debug.value);
        try expectEqual(true, config.file.called);
        try expectEqual(true, config.debug.called);
    }
    {
        // short flag with text input
        var config = struct {
            file: Flag([]const u8) = .{ .long = "file", .short = 'f' },
            debug: Flag(bool) = .{ .long = "debug", .short = 'd' },
        }{};

        const arguments = &.{ "main", "-f", "input.txt", "-d" };

        var iter = IteratorTest{ .args = arguments };
        try parseIter(allocator, &iter, &config);

        try expectEqualSlices(u8, "input.txt", config.file.value);
        try expectEqual(true, config.debug.value);
        try expectEqual(true, config.file.called);
        try expectEqual(true, config.debug.called);
    }
    {
        // flag with int value and also it can be optional
        var config = struct {
            file: Flag([]const u8) = .{ .long = "file", .short = 'f' },
            debug: Flag(bool) = .{ .long = "debug", .short = 'd' },
            number: Flag(?i32) = .{ .long = "number", .short = 'n' },
        }{};

        const arguments = &.{ "main", "--file", "input.txt", "-d", "-n", "3" };

        var iter = IteratorTest{ .args = arguments };
        try parseIter(allocator, &iter, &config);

        try expectEqualSlices(u8, "input.txt", config.file.value);
        try expectEqual(true, config.debug.value);
        try expectEqual(3, config.number.value);
        try expectEqual(true, config.file.called);
        try expectEqual(true, config.debug.called);
        try expectEqual(true, config.number.called);
    }
    {
        // float values
        var config = struct {
            file: Flag([]const u8) = .{ .long = "file", .short = 'f' },
            debug: Flag(?bool) = .{ .long = "debug", .short = 'd' },
            number: Flag(f16) = .{ .short = 'n' },
            distance: Flag(?f64) = .{ .long = "distance" },
        }{};

        const arguments = &.{ "main", "--distance", "1.2", "--file", "input.txt", "-n", "3" };

        var iter = IteratorTest{ .args = arguments };
        try parseIter(allocator, &iter, &config);

        try expectEqualSlices(u8, "input.txt", config.file.value);
        try expectEqual(null, config.debug.value);
        try expectEqual(1.2, config.distance.value);
        try expectEqual(3, config.number.value);
        try expectEqual(true, config.file.called);
        try expectEqual(false, config.debug.called);
        try expectEqual(true, config.number.called);
        try expectEqual(true, config.distance.called);
    }
    {
        // optional text input
        var config = struct {
            file: Flag(?[]const u8) = .{ .long = "file" },
            directory: Flag(?[]const u8) = .{ .short = 'd' },
        }{};

        const arguments = &.{ "main", "-d", "/home" };

        var iter = IteratorTest{ .args = arguments };
        try parseIter(allocator, &iter, &config);

        try expectEqualSlices(u8, "/home", config.directory.value.?);
        try expectEqual(null, config.file.value);
        try expectEqual(false, config.file.called);
        try expectEqual(true, config.directory.called);
    }
    {
        // subcommand randomly named but cmd got correct name
        var config = struct {
            serial333: struct {
                cmd: Cmd() = .{ .name = "serial" },
            } = .{},
        }{};

        const arguments = &.{ "main", "serial" };

        var iter = IteratorTest{ .args = arguments };
        try parseIter(allocator, &iter, &config);

        try expectEqual(true, config.serial333.cmd.called);
    }
    {
        // multiple positional arguments
        var config = struct {
            file: Arg([]const u8) = .{},
            port: Arg(?[]const u8) = .{},
            out: Arg([]const u8) = .{},
        }{};

        const arguments = &.{ "main", "file.txt", "/dev/tty", "out.txt" };

        var iter = IteratorTest{ .args = arguments };
        try parseIter(allocator, &iter, &config);

        try expectEqualSlices(u8, "file.txt", config.file.value);
        try expectEqualSlices(u8, "/dev/tty", config.port.value.?);
        try expectEqualSlices(u8, "out.txt", config.out.value);
        try expectEqual(true, config.file.called);
        try expectEqual(true, config.port.called);
        try expectEqual(true, config.out.called);
    }
    {
        // subcommand with multiple inputs
        var config = struct {
            serial: struct {
                cmd: Cmd() = .{ .name = "serial" },
                debug: Flag(?bool) = .{ .long = "debug", .short = 'd' },
                port: Arg([]const u8) = .{},
            } = .{},
            trigger: Flag(?bool) = .{ .long = "trigger", .short = 't' },
        }{};

        const arguments = &.{ "main", "-t", "serial", "/dev/tty" };

        var iter = IteratorTest{ .args = arguments };
        try parseIter(allocator, &iter, &config);

        // try expectEqualSlices(u8, "/home", config.directory.value.?);
        try expectEqual(true, config.serial.cmd.called);
        try expectEqual(null, config.serial.debug.value);
        try expectEqual(true, config.trigger.value.?);
        try expectEqualSlices(u8, "/dev/tty", config.serial.port.value);
        try expectEqual(true, config.serial.cmd.called);
        try expectEqual(false, config.serial.debug.called);
        try expectEqual(true, config.serial.port.called);
        try expectEqual(true, config.trigger.called);
    }
    {
        // subcommand with options and args
        var config = struct {
            serial: struct {
                cmd: Cmd() = .{ .name = "serial" },
                debug: Flag(?bool) = .{ .long = "debug", .short = 'd' },
                port: Arg([]const u8) = .{},
            } = .{},
            trigger: Flag(?bool) = .{ .long = "trigger", .short = 't' },
        }{};

        const arguments = &.{ "main", "serial", "/dev/tty", "-t" };

        var iter = IteratorTest{ .args = arguments };
        try parseIter(allocator, &iter, &config);

        // try expectEqualSlices(u8, "/home", config.directory.value.?);
        try expectEqual(true, config.serial.cmd.called);
        try expectEqual(null, config.serial.debug.value);
        try expectEqual(true, config.trigger.value);
        try expectEqualSlices(u8, "/dev/tty", config.serial.port.value);
        try expectEqual(true, config.serial.cmd.called);
        try expectEqual(false, config.serial.debug.called);
        try expectEqual(true, config.serial.port.called);
        try expectEqual(true, config.trigger.called);
    }
    {
        // double subcommands
        var config = struct {
            serial: struct {
                cmd: Cmd() = .{ .name = "serial" },
            } = .{},
            net: struct {
                cmd: Cmd() = .{ .name = "net" },
            } = .{},
            port: Arg([]const u8) = .{},
        }{};

        const arguments = &.{ "main", "net", "/dev/tty" };

        var iter = IteratorTest{ .args = arguments };
        try parseIter(allocator, &iter, &config);

        // try expectEqualSlices(u8, "/home", config.directory.value.?);
        try expectEqual(false, config.serial.cmd.called);
        try expectEqual(true, config.net.cmd.called);
        try expectEqualSlices(u8, "/dev/tty", config.port.value);
        try expectEqual(false, config.serial.cmd.called);
        try expectEqual(true, config.net.cmd.called);
        try expectEqual(true, config.port.called);
    }
    {
        // positional arg after subcommand
        var config = struct {
            serial: struct {
                cmd: Cmd() = .{ .name = "serial" },
                debug: Flag(?bool) = .{ .long = "debug", .short = 'd' },
            } = .{},
            port: Arg([]const u8) = .{},
        }{};

        const arguments = &.{ "main", "-t", "serial", "/dev/tty" };

        var iter = IteratorTest{ .args = arguments };
        try parseIter(allocator, &iter, &config);

        // try expectEqualSlices(u8, "/home", config.directory.value.?);
        try expectEqual(true, config.serial.cmd.called);
        try expectEqual(null, config.serial.debug.value);
        try expectEqualSlices(u8, "/dev/tty", config.port.value);
        try expectEqual(true, config.serial.cmd.called);
        try expectEqual(false, config.serial.debug.called);
        try expectEqual(true, config.port.called);
    }
}

const ArgType = enum {
    long,
    short,
    arg,
};

const ParsedArg = struct {
    Type: ArgType,
    value: []const u8,
    used: bool = false,
    index: usize,
};

const ParsedArgs = struct {
    values: []ParsedArg,
    index: usize = 0,

    pub fn next(self: *ParsedArgs) ?ParsedArg {
        // all values are already read
        if (self.index >= self.values.len) return null;

        var arg = self.values[self.index];
        _ = &arg;

        self.index += 1;
        return arg;
    }

    pub fn nextFlag(self: *ParsedArgs) ?ParsedArg {
        while (self.next()) |arg| {
            if (arg.used or arg.Type == .arg) continue;
            return arg;
        }

        return null;
    }

    pub fn nextArg(self: *ParsedArgs) ?ParsedArg {
        while (self.next()) |arg| {
            if (!arg.used and arg.Type == .arg) return arg;
        }

        return null;
    }

    pub fn skip(self: *ParsedArgs) bool {
        if (self.index >= self.values.len) return false;
        self.index += 1;
        return true;
    }

    pub fn reset(self: *ParsedArgs) void {
        self.index = 1;
    }

    pub fn deinit(self: *ParsedArgs, allocator: std.mem.Allocator) void {
        allocator.free(self.values);
    }

    fn print(self: *ParsedArgs) void {
        for (self.values) |arg| {
            std.debug.print("arg: {s} {any}\n", .{ arg.value, arg });
        }
    }
};

/// parse command line arguments into more manageble structures
/// with defined type of argument (flag or stadalone)
fn parseArgs(allocator: std.mem.Allocator, iter: *Iterator) !ParsedArgs {
    var al = std.ArrayList(ParsedArg).init(allocator);
    errdefer al.deinit();

    var i: usize = 0;
    while (iter.next()) |arg| {
        defer i += 1;

        if (arg.len > 2 and std.mem.eql(u8, arg[0..2], "--")) {
            try al.append(.{
                .Type = .long,
                .value = arg[2..arg.len],
                .index = i,
            });
            continue;
        }
        if (arg.len > 1 and std.mem.eql(u8, arg[0..1], "-")) {
            try al.append(.{
                .Type = .short,
                .value = arg[1..arg.len],
                .index = i,
            });
            continue;
        }

        try al.append(.{
            .Type = .arg,
            .value = arg,
            .index = i,
        });
    }

    return .{
        .values = try al.toOwnedSlice(),
    };
}

test "parseArgs" {
    const allocator = std.testing.allocator;

    {
        // command without other arguments
        const arguments = &.{"main"};
        var iter = IteratorTest{ .args = arguments };

        var pa = try parseArgs(allocator, &iter);
        defer pa.deinit(allocator);

        try expectEqual(0, pa.index);
        try expectEqual(1, pa.values.len);

        const arg = pa.next() orelse unreachable;
        try expectEqualSlices(u8, "main", arg.value);
        try expectEqual(ArgType.arg, arg.Type);

        // after all params are read
        try expectEqual(1, pa.index);
        try expectEqual(null, pa.next());
    }
    {
        // single parameter input as flag
        const arguments = &.{ "main", "--trigger" };
        var iter = IteratorTest{ .args = arguments };

        var pa = try parseArgs(allocator, &iter);
        defer pa.deinit(allocator);

        try expectEqual(0, pa.index);
        try expectEqual(2, pa.values.len);

        const main_arg = pa.next() orelse unreachable;
        try expectEqualSlices(u8, "main", main_arg.value);
        try expectEqual(ArgType.arg, main_arg.Type);

        try expectEqual(1, pa.index);

        const trigger_arg = pa.next() orelse unreachable;
        try std.testing.expectEqualSlices(u8, "trigger", trigger_arg.value);
        try expectEqual(ArgType.long, trigger_arg.Type);

        // after all params are read
        try expectEqual(2, pa.index);
        try expectEqual(null, pa.next());
    }
    {
        // multiple flags arguments both short and long
        const arguments = &.{ "main", "--trigger", "-h" };
        var iter = IteratorTest{ .args = arguments };

        var pa = try parseArgs(allocator, &iter);
        defer pa.deinit(allocator);

        try expectEqual(0, pa.index);
        try expectEqual(3, pa.values.len);

        const main_arg = pa.next() orelse unreachable;
        try expectEqualSlices(u8, "main", main_arg.value);
        try expectEqual(ArgType.arg, main_arg.Type);

        try expectEqual(1, pa.index);

        const trigger_arg = pa.next() orelse unreachable;
        try std.testing.expectEqualSlices(u8, "trigger", trigger_arg.value);
        try expectEqual(ArgType.long, trigger_arg.Type);

        try expectEqual(2, pa.index);

        const h_arg = pa.next() orelse unreachable;
        try std.testing.expectEqualSlices(u8, "h", h_arg.value);
        try expectEqual(ArgType.short, h_arg.Type);

        // after all params are read
        try expectEqual(3, pa.index);
        try expectEqual(null, pa.next());
    }
    {
        // setup with all types of arguments
        const arguments = &.{ "main", "--trigger", "-h", "file.txt" };
        var iter = IteratorTest{ .args = arguments };

        var pa = try parseArgs(allocator, &iter);
        defer pa.deinit(allocator);

        try expectEqual(0, pa.index);
        try expectEqual(4, pa.values.len);

        const main_arg = pa.next() orelse unreachable;
        try expectEqualSlices(u8, "main", main_arg.value);
        try expectEqual(ArgType.arg, main_arg.Type);

        try expectEqual(1, pa.index);

        const trigger_arg = pa.next() orelse unreachable;
        try std.testing.expectEqualSlices(u8, "trigger", trigger_arg.value);
        try expectEqual(ArgType.long, trigger_arg.Type);

        try expectEqual(2, pa.index);

        const h_arg = pa.next() orelse unreachable;
        try std.testing.expectEqualSlices(u8, "h", h_arg.value);
        try expectEqual(ArgType.short, h_arg.Type);

        try expectEqual(3, pa.index);

        const file_arg = pa.next() orelse unreachable;
        try std.testing.expectEqualSlices(u8, "file.txt", file_arg.value);
        try expectEqual(ArgType.arg, file_arg.Type);

        // after all params are read
        try expectEqual(4, pa.index);
        try expectEqual(null, pa.next());
    }
}
