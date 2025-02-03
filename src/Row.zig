const std = @import("std");
pub const Row = @This();

pub const ID_SIZE: usize = @sizeOf(u32);
pub const USERNAME_SIZE: usize = 32;
pub const EMAIL_SIZE: usize = 255;
pub const ROW_SIZE: usize = @sizeOf(Row);

pub const RowError = error{ PrepareSyntaxError, PrepareStringTooLong, PrepareInvalidID };

id: u32,
username: [USERNAME_SIZE]u8,
email: [EMAIL_SIZE]u8,

pub fn new(iter: *std.mem.SplitIterator(u8, std.mem.DelimiterType.sequence)) RowError!Row {
    const id = if (iter.next()) |id| blk: {
        break :blk std.fmt.parseInt(u32, id, 10) catch {
            return error.PrepareInvalidID;
        };
    } else {
        return error.PrepareSyntaxError;
    };

    const username = if (iter.next()) |u| blk: {
        if (u.len > USERNAME_SIZE) {
            return error.PrepareStringTooLong;
        }
        var username: [USERNAME_SIZE]u8 = [_]u8{0} ** USERNAME_SIZE;
        @memcpy(username[0..u.len], u);
        break :blk username;
    } else {
        return error.PrepareSyntaxError;
    };

    const email = if (iter.next()) |e| blk: {
        if (e.len > EMAIL_SIZE) {
            return error.PrepareStringTooLong;
        }
        var email: [EMAIL_SIZE]u8 = [_]u8{0} ** EMAIL_SIZE;
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

pub fn printRow(self: Row) !void {
    const writer = std.io.getStdOut().writer();
    const null_val: [1]u8 = [_]u8{0};
    const username = std.mem.trimRight(u8, &self.username, &null_val);
    const email = std.mem.trimRight(u8, &self.email, &null_val);
    try writer.print("({d}, {s}, {s})\n", .{
        self.id,
        username,
        email,
    });
}
