const std = @import("std");

const InputBuffer = struct {
    buffer: []const u8,

    fn read_input() !InputBuffer {
        const reader = std.io.getStdIn().reader();
        const bare_line = try reader.readUntilDelimiterAlloc(
            std.heap.page_allocator,
            '\n',
            4096,
        );
        const line = std.mem.trim(u8, bare_line, "\r");
        return InputBuffer{ .buffer = line };
    }

    fn print_prompt() !void {
        const writer = std.io.getStdOut().writer();
        try writer.print("db > ", .{});
    }

    fn close_input_buffer(self: InputBuffer) void {
        std.heap.page_allocator.free(self.buffer);
    }
};

pub fn main() !void {
    const writer = std.io.getStdOut().writer();

    while (true) {
        try InputBuffer.print_prompt();
        const input_buffer = try InputBuffer.read_input();

        if (std.mem.eql(u8, input_buffer.buffer, ".exit")) {
            input_buffer.close_input_buffer();
            return;
        } else {
            try writer.print("Unrecognized command '{s}'.\n", .{input_buffer.buffer});
        }
    }
}
