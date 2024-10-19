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
pub fn Flag(comptime T: type) type {
    return struct {
        value: T = undefined,
        long: []const u8 = undefined,
        short: u8 = undefined,
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
        std.debug.print("arg: {any}, {s}\n", .{ arg.Type, arg.value });
        switch (arg.Type) {
            .long => {
                inline for (std.meta.fields(@TypeOf(config.*))) |field| {
                    const f = @field(config, field.name);

                    if (std.mem.eql(u8, f.long, arg.value) and
                        std.mem.startsWith(u8, @typeName(field.type), FlagTypePrefix))
                    {
                        switch (@TypeOf(f.value)) {
                            bool => {
                                @field(config, field.name).value = true;
                            },
                            else => {},
                        }
                    }
                }
            },
            .short => {
                inline for (std.meta.fields(@TypeOf(config.*))) |field| {
                    const f = @field(config, field.name);

                    if (f.short == arg.value[0] and
                        std.mem.startsWith(u8, @typeName(field.type), FlagTypePrefix))
                    {
                        switch (@TypeOf(f.value)) {
                            bool => {
                                @field(config, field.name).value = true;
                            },
                            else => {},
                        }
                    }
                }
            },
            .arg => {},
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
