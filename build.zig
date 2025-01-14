const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const exe_name = "zig-sqlite";
    const exe = b.addExecutable(.{
        .name = exe_name,
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest(.{
        .root_source_file = b.path("tests/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe_ext = comptime std.Target.exeFileExt(builtin.target);
    const exe_name_ext = exe_name ++ exe_ext;
    const run_exe_tests = b.addRunArtifact(exe_tests);
    run_exe_tests.step.dependOn(b.getInstallStep());
    const exe_paths = [2][]const u8{ b.getInstallPath(.bin, ".")[0..], exe_name_ext[0..] };
    const exe_path = b.pathJoin(exe_paths[0..]);
    run_exe_tests.setEnvironmentVariable("ZIG_SQLITE_EXE_PATH", exe_path);

    const test_step = b.step("test", "Run integration tests");
    test_step.dependOn(&run_exe_tests.step);
}
