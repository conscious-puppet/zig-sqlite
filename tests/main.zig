const std = @import("std");
const Proc = @import("Proc.zig");
const File = std.fs.File;

fn expectEqualOutput(expected_output: []const []const u8, output: [][]const u8) !void {
    try std.testing.expectEqual(expected_output.len, output.len);
    for (0..expected_output.len) |i| {
        try std.testing.expectEqualStrings(expected_output[i], output[i]);
    }
}

test "inserts and retrieves a row" {
    const input = [_][]const u8{
        "insert 1 user1 person1@example.com",
        "select",
        ".exit",
    };
    const expected_output = [_][]const u8{
        "db > Executed.",
        "db > (1, user1, person1@example.com)",
        "Executed.",
        "db > ",
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var proc = try Proc.init(allocator);
    defer proc.deinit();

    const output = try proc.spawnRustSqlite(allocator, &input);
    defer {
        for (output.items) |line| {
            allocator.free(line);
        }
        output.deinit();
    }

    try expectEqualOutput(&expected_output, output.items);
}

test "prints error message when table is full" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var input = std.ArrayList([]u8).init(allocator);
    defer {
        for (input.items) |line| {
            allocator.free(line);
        }
        input.deinit();
    }

    for (0..1401) |i| {
        const cmd = try std.fmt.allocPrint(
            allocator,
            "insert {} user{} person{}@example.com",
            .{ i, i, i },
        );
        try input.append(cmd);
    }

    const exit_cmd = try std.fmt.allocPrint(allocator, ".exit", .{});
    try input.append(exit_cmd);

    const expected_output = "db > Error: Table full.";

    var proc = try Proc.init(allocator);
    defer proc.deinit();

    const output = try proc.spawnRustSqlite(allocator, input.items);
    defer {
        for (output.items) |line| {
            allocator.free(line);
        }
        output.deinit();
    }

    try std.testing.expectEqualStrings(expected_output, output.items[output.items.len - 1]);
}

test "allows inserting strings that are the maximum length" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const long_username = [_]u8{'a'} ** 32;
    const long_email = [_]u8{'a'} ** 255;

    const insert_cmd = try std.fmt.allocPrint(
        allocator,
        "insert 1 {s} {s}",
        .{ long_username, long_email },
    );
    defer allocator.free(insert_cmd);

    const input = [_][]const u8{
        insert_cmd,
        "select",
        ".exit",
    };

    const expected_select_output = try std.fmt.allocPrint(
        allocator,
        "db > (1, {s}, {s})",
        .{ long_username, long_email },
    );
    defer allocator.free(expected_select_output);

    const expected_output = [_][]const u8{
        "db > Executed.",
        expected_select_output,
        "Executed.",
        "db > ",
    };

    var proc = try Proc.init(allocator);
    defer proc.deinit();

    const output = try proc.spawnRustSqlite(allocator, &input);
    defer {
        for (output.items) |line| {
            allocator.free(line);
        }
        output.deinit();
    }

    try expectEqualOutput(&expected_output, output.items);
}

test "prints error message if strings are too long" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const long_username = [_]u8{'a'} ** 33;
    const long_email = [_]u8{'a'} ** 256;

    const insert_cmd = try std.fmt.allocPrint(
        allocator,
        "insert 1 {s} {s}",
        .{ long_username, long_email },
    );
    defer allocator.free(insert_cmd);

    const input = [_][]const u8{
        insert_cmd,
        "select",
        ".exit",
    };

    const expected_output = [_][]const u8{
        "db > String is too long.",
        "db > Executed.",
        "db > ",
    };

    var proc = try Proc.init(allocator);
    defer proc.deinit();

    const output = try proc.spawnRustSqlite(allocator, &input);
    defer {
        for (output.items) |line| {
            allocator.free(line);
        }
        output.deinit();
    }

    try expectEqualOutput(&expected_output, output.items);
}

test "prints an error message if id is negative" {
    const input = [_][]const u8{
        "insert -1 user1 person1@example.com",
        "select",
        ".exit",
    };
    const expected_output = [_][]const u8{
        "db > Invalid ID.",
        "db > Executed.",
        "db > ",
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var proc = try Proc.init(allocator);
    defer proc.deinit();

    const output = try proc.spawnRustSqlite(allocator, &input);
    defer {
        for (output.items) |line| {
            allocator.free(line);
        }
        output.deinit();
    }

    try expectEqualOutput(&expected_output, output.items);
}
