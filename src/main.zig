const std = @import("std");

const InputBuffer = @import("InputBuffer.zig");
const Statement = @import("statement.zig").Statement;
const Table = @import("Table.zig");

pub fn main() !void {
    const writer = std.io.getStdOut().writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var table = try Table.newTable(allocator);
    defer table.freeTable();

    while (true) {
        try InputBuffer.printPrompt();
        const input_buffer = try InputBuffer.readInput();

        if (input_buffer.buffer[0] == '.') {
            if (doMetaCommand(&input_buffer)) |value| switch (value) {
                .ExitSuccess => break,
            } else |err| switch (err) {
                error.MetaCommandUnrecognizedCommand => {
                    try writer.print("Unrecognized command '{s}'\n", .{input_buffer.buffer});
                    continue;
                },
            }
        }

        var statement = if (Statement.prepareStatement(&input_buffer)) |statement| statement else |err| switch (err) {
            error.PrepareUnrecognizedStatement => {
                try writer.print("Unrecognized keyword at start of '{s}'\n", .{input_buffer.buffer});
                continue;
            },
            error.PrepareSyntaxError => {
                try writer.print("Prepare Syntax error for '{s}'\n", .{input_buffer.buffer});
                continue;
            },
            error.PrepareStringTooLong => {
                try writer.print("String is too long.\n", .{});
                continue;
            },
            error.PrepareInvalidID => {
                try writer.print("Invalid ID.\n", .{});
                continue;
            },
        };

        statement.executeStatement(table) catch |err| switch (err) {
            error.ExecuteTableFull => {
                try writer.print("Error: Table full.\n", .{});
                break;
            },
        };
        try writer.print("Executed.\n", .{});
    }
}

const MetaCommandError = error{MetaCommandUnrecognizedCommand};
const MetaCommandResult = enum { ExitSuccess };

fn doMetaCommand(input_buffer: *const InputBuffer) (MetaCommandError)!MetaCommandResult {
    if (std.mem.eql(u8, input_buffer.buffer, ".exit")) {
        input_buffer.closeInputBuffer();
        return MetaCommandResult.ExitSuccess;
    } else {
        return MetaCommandError.MetaCommandUnrecognizedCommand;
    }
}
