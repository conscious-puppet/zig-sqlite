const std = @import("std");
const InputBuffer = @import("InputBuffer.zig");
const Statement = @import("Statement.zig");

pub fn main() !void {
    const writer = std.io.getStdOut().writer();

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
        };

        statement.executeStatement();
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
