const std = @import("std");

pub fn build(b: *std.Build) void {
    b.addModule("args", .{ .root_source_file = b.path("args.zig") });
}
