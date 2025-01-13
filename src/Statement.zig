const std = @import("std");

const InputBuffer = @import("InputBuffer.zig");
const Row = @import("Row.zig");
const Table = @import("Table.zig");

const RowError = Row.RowError;
pub const PrepareError = error{PrepareUnrecognizedStatement};

pub const Statement = union(enum) {
    Select,
    Insert: Row,

    pub fn prepareStatement(input_buffer: *const InputBuffer) (PrepareError || RowError)!Statement {
        if (std.mem.eql(u8, input_buffer.buffer, "select")) {
            return Statement.Select;
        } else if (input_buffer.buffer.len > 6 and std.mem.eql(u8, input_buffer.buffer[0..6], "insert")) {
            var it = std.mem.split(u8, input_buffer.buffer[7..], " ");
            const row = try Row.new(&it);
            return Statement{ .Insert = row };
        } else {
            return error.PrepareUnrecognizedStatement;
        }
    }

    pub fn executeStatement(self: *Statement, table: *Table) Table.ExecuteError!void {
        switch (self.*) {
            .Insert => |row| {
                return table.executeInsert(row);
            },
            .Select => {
                return table.executeSelect();
            },
        }
    }
};
