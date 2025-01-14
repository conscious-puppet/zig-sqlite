const std = @import("std");
const Allocator = std.mem.Allocator;
const File = std.fs.File;
const TmpDir = std.testing.TmpDir;
const Child = std.process.Child;

pub const Proc = @This();

db_name: []u8,
tmp_dir: TmpDir,
allocator: Allocator,

pub fn init(allocator: Allocator) !Proc {
    const out: struct { []u8, TmpDir } = try Proc.tempFile(allocator);

    const db_name = out[0];
    const tmp_dir = out[1];

    return Proc{
        .allocator = allocator,
        .db_name = db_name,
        .tmp_dir = tmp_dir,
    };
}

pub fn deinit(self: *Proc) void {
    self.allocator.free(self.db_name);
    self.tmp_dir.cleanup();
}

pub fn spawnRustSqlite(
    self: Proc,
    output_allocator: Allocator,
    input: []const []const u8,
) !std.ArrayList([]const u8) {
    const path = try std.process.getEnvVarOwned(self.allocator, "ZIG_SQLITE_EXE_PATH");
    defer self.allocator.free(path);

    const db_file = try self.tmp_dir.dir.realpathAlloc(self.allocator, self.db_name);
    defer self.allocator.free(db_file);
    const argv = [_][]const u8{ path, db_file };

    var proc = Child.init(&argv, self.allocator);
    proc.stdin_behavior = .Pipe;
    proc.stdout_behavior = .Pipe;
    proc.stderr_behavior = .Ignore;

    try proc.spawn();
    const writer = proc.stdin.?.writer();
    for (input) |i| {
        try writer.writeAll(i);
        try writer.writeAll("\n");
    }

    const reader = proc.stdout.?.reader();

    var output_lines = std.ArrayList([]const u8).init(output_allocator);
    while (true) {
        if (try reader.readUntilDelimiterOrEofAlloc(
            output_allocator,
            '\n',
            4096,
        )) |bare_line| {
            const line = std.mem.trim(u8, bare_line, "\n\r");
            try output_lines.append(line);
        } else {
            break;
        }
    }

    const term = try proc.wait();
    try std.testing.expectEqual(term, std.process.Child.Term{ .Exited = 0 });

    return output_lines;
}

fn tempFile(allocator: Allocator) !struct { []u8, TmpDir } {
    const tmp_dir = std.testing.tmpDir(std.fs.Dir.OpenDirOptions{});
    const rand_num = std.crypto.random.int(u128);
    const db_name = try std.fmt.allocPrint(
        allocator,
        "test_{d}.db",
        .{rand_num},
    );
    _ = try tmp_dir.dir.createFile(db_name, .{});
    return .{ db_name, tmp_dir };
}
