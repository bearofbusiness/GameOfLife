const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "hello",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const mibu_dep = b.dependency("mibu", .{
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("mibu", mibu_dep.module("mibu"));

    b.installArtifact(exe);
}
