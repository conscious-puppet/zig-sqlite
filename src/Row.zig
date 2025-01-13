const std = @import("std");
pub const Row = @This();

pub const ID_SIZE: usize = @sizeOf(u32);
pub const USERNAME_SIZE: usize = 32;
pub const EMAIL_SIZE: usize = 255;
pub const ROW_SIZE: usize = @sizeOf(Row);

id: u32,
username: [USERNAME_SIZE]u8,
email: [EMAIL_SIZE]u8,

pub const RowError = error{PrepareSyntaxError};

pub fn new(iter: *std.mem.SplitIterator(u8, std.mem.DelimiterType.sequence)) RowError!Row {
    const id = if (iter.next()) |id| blk: {
        break :blk std.fmt.parseInt(u8, id, 10) catch {
            return error.PrepareSyntaxError;
        };
    } else {
        return error.PrepareSyntaxError;
    };

    const username = if (iter.next()) |u| blk: {
        if (u.len > USERNAME_SIZE) {
            return error.PrepareSyntaxError;
        }
        var username: [USERNAME_SIZE]u8 = undefined;
        @memcpy(username[0..u.len], u);
        break :blk username;
    } else {
        return error.PrepareSyntaxError;
    };

    const email = if (iter.next()) |e| blk: {
        if (e.len > EMAIL_SIZE) {
            return error.PrepareSyntaxError;
        }
        var email: [EMAIL_SIZE]u8 = undefined;
        @memcpy(email[0..e.len], e);
        break :blk email;
    } else {
        return error.PrepareSyntaxError;
    };

    if (iter.next()) |_| {
        return error.PrepareSyntaxError;
    }

    const row = Row{
        .id = id,
        .username = username,
        .email = email,
    };

    return row;
}

pub fn serialize_row(self: Row, destination: [*]u8) void {
    const bytes = std.mem.asBytes(&self);
    @memcpy(destination, bytes);
}

pub fn deserialize_row(source: [*]u8) *Row {
    return std.mem.bytesAsValue(Row, source);
}

pub fn print_row(self: Row) !void {
    const writer = std.io.getStdOut().writer();
    try writer.print("({d}, {s}, {s})\n", .{
        self.id,
        self.username,
        self.email,
    });
}
