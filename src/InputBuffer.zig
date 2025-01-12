const std = @import("std");
pub const InputBuffer = @This();

buffer: []const u8,

pub fn readInput() !InputBuffer {
    const reader = std.io.getStdIn().reader();
    const bare_line = try reader.readUntilDelimiterAlloc(
        std.heap.page_allocator,
        '\n',
        4096,
    );
    const line = std.mem.trim(u8, bare_line, "\r");
    return InputBuffer{ .buffer = line };
}

pub fn printPrompt() !void {
    const writer = std.io.getStdOut().writer();
    try writer.print("db > ", .{});
}

pub fn closeInputBuffer(self: InputBuffer) void {
    std.heap.page_allocator.free(self.buffer);
}
