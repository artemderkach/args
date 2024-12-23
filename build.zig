const std = @import("std");

pub fn build(b: *std.Build) void {
    _ = b.addModule("args", .{
        .root_source_file = b.path("args.zig"),
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    });
}
