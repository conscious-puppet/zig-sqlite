const std = @import("std");
const Allocator = std.mem.Allocator;

const Row = @import("Row.zig");

pub const Page = @This();

pub const PAGE_SIZE = 4096;
pub const ROWS_PER_PAGE = PAGE_SIZE / Row.ROW_SIZE;

rows: [ROWS_PER_PAGE]?Row,

pub fn newPage(allocator: Allocator) !*Page {
    const page = try allocator.create(Page);
    for (0..ROWS_PER_PAGE) |i| {
        page.rows[i] = null;
    }
    return page;
}

pub fn freePage(self: *Page, allocator: Allocator) void {
    allocator.destroy(self);
}
