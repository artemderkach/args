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
    };
}

const ArgTypePrefix = "args.Arg";
/// struct represenging positional argument
pub fn Arg(comptime T: type) type {
    return struct {
        value: T = undefined,
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

    try parseIter(allocator, config, &iter);
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

    // skip root command
    if (!pa.skip()) unreachable;

    while (pa.next()) |arg| {
        // std.debug.print("arg: {any}, {s}\n", .{ arg.Type, arg.value });
        switch (arg.Type) {
            .long => {
                inline for (std.meta.fields(@TypeOf(config.*))) |field| blk: {
                    const f = @field(config, field.name);

                    if (comptime !std.mem.startsWith(u8, @typeName(field.type), FlagTypePrefix)) break :blk;
                    if (!std.mem.eql(u8, f.long, arg.value)) break :blk;

                    switch (@TypeOf(f.value)) {
                        bool, ?bool => {
                            @field(config, field.name).value = true;
                        },
                        []const u8, ?[]const u8 => {
                            if (pa.next()) |flag_value| {
                                @field(config, field.name).value = flag_value.value;
                            }
                        },
                        i8, u8, i16, u16, i32, u32, i64, u64, i128, u128 => {
                            if (pa.next()) |flag_value| {
                                @field(config, field.name).value = try std.fmt.parseInt(@TypeOf(f.value), flag_value.value, 0);
                            }
                        },
                        ?i8, ?u8, ?i16, ?u16, ?i32, ?u32, ?i64, ?u64, ?i128, ?u128 => {
                            if (pa.next()) |flag_value| {
                                @field(config, field.name).value = try std.fmt.parseInt(@TypeOf(f.value.?), flag_value.value, 0);
                            }
                        },
                        f16, f32, f64, f128 => {
                            if (pa.next()) |flag_value| {
                                @field(config, field.name).value = try std.fmt.parseFloat(@TypeOf(f.value), flag_value.value);
                            }
                        },
                        ?f16, ?f32, ?f64, ?f128 => {
                            if (pa.next()) |flag_value| {
                                @field(config, field.name).value = try std.fmt.parseFloat(@TypeOf(f.value.?), flag_value.value);
                            }
                        },
                        else => {},
                    }
                }
            },
            .short => {
                inline for (std.meta.fields(@TypeOf(config.*))) |field| blk: {
                    const f = @field(config, field.name);

                    if (comptime !std.mem.startsWith(u8, @typeName(field.type), FlagTypePrefix)) break :blk;
                    if (f.short != arg.value[0]) break :blk;

                    switch (@TypeOf(f.value)) {
                        bool, ?bool => {
                            @field(config, field.name).value = true;
                        },
                        []const u8, ?[]const u8 => {
                            if (pa.next()) |flag_value| {
                                @field(config, field.name).value = flag_value.value;
                            }
                        },
                        i8, u8, i16, u16, i32, u32, i64, u64, i128, u128 => {
                            if (pa.next()) |flag_value| {
                                @field(config, field.name).value = try std.fmt.parseInt(@TypeOf(f.value), flag_value.value, 0);
                            }
                        },
                        ?i8, ?u8, ?i16, ?u16, ?i32, ?u32, ?i64, ?u64, ?i128, ?u128 => {
                            if (pa.next()) |flag_value| {
                                @field(config, field.name).value = try std.fmt.parseInt(@TypeOf(f.value.?), flag_value.value, 0);
                            }
                        },
                        f16, f32, f64, f128 => {
                            if (pa.next()) |flag_value| {
                                @field(config, field.name).value = try std.fmt.parseFloat(@TypeOf(f.value), flag_value.value);
                            }
                        },
                        ?f16, ?f32, ?f64, ?f128 => {
                            if (pa.next()) |flag_value| {
                                @field(config, field.name).value = try std.fmt.parseFloat(@TypeOf(f.value.?), flag_value.value);
                            }
                        },
                        else => {},
                    }
                }
            },
            .arg => {
                inline for (std.meta.fields(@TypeOf(config.*))) |field| blk: {
                    if (comptime !std.mem.startsWith(u8, @typeName(field.type), ArgTypePrefix)) break :blk;
                    @field(config, field.name).value = arg.value;
                }
            },
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
    }
    {
        // some values not provided
        var config = struct {
            trigger: Flag(bool) = .{ .long = "trigger", .short = 't' },
            debug: Flag(bool) = .{ .long = "debug", .short = 'd' },
        }{};

        const arguments = &.{ "main", "--debug", "wrong_value" };

        var iter = IteratorTest{ .args = arguments };
        try parseIter(allocator, &iter, &config);

        try expectEqual(false, config.trigger.value);
        try expectEqual(true, config.debug.value);
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
    }
}

pub fn parseStruct(cfg: anytype, _: []const u8) void {
    std.debug.print("type: {any}\n", .{@TypeOf(cfg)});
    // std.debug.print("type: {any}\n", .{std.meta.fields(@TypeOf(cfg.*))});
    inline for (std.meta.fields(@TypeOf(cfg.*))) |field| {
        std.debug.print("field: {}\n", .{field});
        std.debug.print("field.name: {s}\n", .{field.name});
        // if (comptime std.mem.eql(u8, field.name, "callback")) {
        //     @field(config, field.name)();
        // }
    }
}

test "parse_struct" {
    // std.debug.print("fields: {}\n", .{@typeInfo(config)});
    // config.help.value;

    // var val: u8 = 4;
    // _ = &val;
    // inline for (std.meta.fields(@TypeOf(config))) |field| {
    // std.debug.print("fields: {}\n", .{field});
    // std.debug.print("field.name: {s}, field.type: {any}\n", .{ field.name, field.type });
    // std.debug.print("field.type: {s}, type: \n", .{field.name});
    // @field(config, field.name) = val;
    // if (comptime std.mem.eql(u8, field.name, "callback")) {
    //     @field(config, field.name)();
    // }
    // if (comptime std.mem.eql(u8, field.name, "t")) {
    // std.debug.print("====> {any}\n", .{@field(config, field.name)});
    // @field(config, field.name) = 2;
    // std.debug.print("field.name: {s}\n", .{field.name});
    // std.debug.print("field.name: {s}\n", .{field.name});
    // }
    // }

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

const ArgType = enum {
    long,
    short,
    arg,
};

const ParsedArg = struct {
    Type: ArgType,
    value: []const u8,
};

const ParsedArgs = struct {
    values: []ParsedArg,
    index: usize = 0,

    pub fn next(self: *ParsedArgs) ?ParsedArg {
        // all values are already read
        if (self.index >= self.values.len) return null;

        const arg = self.values[self.index];
        self.index += 1;
        return arg;
    }

    pub fn skip(self: *ParsedArgs) bool {
        if (self.index >= self.values.len) return false;
        self.index += 1;
        return true;
    }

    pub fn deinit(self: *ParsedArgs, allocator: std.mem.Allocator) void {
        allocator.free(self.values);
    }
};

/// parse command line arguments into more manageble structures
/// with defined type of argument (flag or stadalone)
fn parseArgs(allocator: std.mem.Allocator, iter: *Iterator) !ParsedArgs {
    var al = std.ArrayList(ParsedArg).init(allocator);
    errdefer al.deinit();

    while (iter.next()) |arg| {
        if (arg.len > 2 and std.mem.eql(u8, arg[0..2], "--")) {
            try al.append(.{
                .Type = .long,
                .value = arg[2..arg.len],
            });
            continue;
        }
        if (arg.len > 1 and std.mem.eql(u8, arg[0..1], "-")) {
            try al.append(.{
                .Type = .short,
                .value = arg[1..arg.len],
            });
            continue;
        }

        try al.append(.{
            .Type = .arg,
            .value = arg,
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
