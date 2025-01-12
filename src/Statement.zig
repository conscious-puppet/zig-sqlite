const std = @import("std");
const InputBuffer = @import("InputBuffer.zig");
pub const Statement = @This();

pub const PrepareError = error{PrepareUnrecognizedStatement};
pub const StatementType = enum { Insert, Select };

type: StatementType,

pub fn prepareStatement(input_buffer: *const InputBuffer) PrepareError!Statement {
    if (std.mem.eql(u8, input_buffer.buffer, "select")) {
        return Statement{ .type = .Select };
    } else if (std.mem.eql(u8, input_buffer.buffer[0..6], "insert")) {
        return Statement{ .type = .Insert };
    } else {
        return error.PrepareUnrecognizedStatement;
    }
}

pub fn executeStatement(self: *Statement) void {
    const writer = std.io.getStdOut().writer();
    switch (self.*.type) {
        .Insert => {
            writer.print("This is where we would do an insert.\n", .{}) catch unreachable;
        },
        .Select => {
            writer.print("This is where we would do a select.\n", .{}) catch unreachable;
        },
    }
}
