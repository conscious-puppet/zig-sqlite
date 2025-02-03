const std = @import("std");
const Proc = @import("Proc.zig");
const File = std.fs.File;

fn expectEqualOutput(expected_output: []const []const u8, output: [][]const u8) !void {
    try std.testing.expectEqual(expected_output.len, output.len);
    for (0..expected_output.len) |i| {
        try std.testing.expectEqualStrings(expected_output[i], output[i]);
    }
}

fn testInput(input: []const []const u8, expected_output: []const []const u8) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var proc = try Proc.init(allocator);
    defer proc.deinit();

    const output = try proc.spawnRustSqlite(allocator, input);
    defer {
        for (output.items) |line| {
            allocator.free(line);
        }
        output.deinit();
    }

    try expectEqualOutput(expected_output, output.items);
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

    try testInput(&input, &expected_output);
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

    try std.testing.expectEqualStrings(expected_output, output.items[output.items.len - 2]);
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

    try testInput(&input, &expected_output);
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

    try testInput(&input, &expected_output);
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

    try testInput(&input, &expected_output);
}

test "keeps data after closing connection" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var proc = try Proc.init(allocator);
    defer proc.deinit();

    const input1 = [_][]const u8{
        "insert 1 user1 person1@example.com",
        ".exit",
    };

    const expected_output1 = [_][]const u8{
        "db > Executed.",
        "db > ",
    };

    const output1 = try proc.spawnRustSqlite(allocator, &input1);
    defer {
        for (output1.items) |line| {
            allocator.free(line);
        }
        output1.deinit();
    }

    try expectEqualOutput(&expected_output1, output1.items);

    const input2 = [_][]const u8{
        "select",
        ".exit",
    };

    const expected_output2 = [_][]const u8{
        "db > (1, user1, person1@example.com)",
        "Executed.",
        "db > ",
    };

    const output2 = try proc.spawnRustSqlite(allocator, &input2);
    defer {
        for (output2.items) |line| {
            allocator.free(line);
        }
        output2.deinit();
    }

    try expectEqualOutput(&expected_output2, output2.items);
}
