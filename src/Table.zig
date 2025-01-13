const std = @import("std");
const Allocator = std.mem.Allocator;

const Row = @import("Row.zig");
const Page = @import("Page.zig");

pub const ExecuteError = error{ExecuteTableFull};

pub const Table = @This();

pub const PAGE_SIZE = 4096;
pub const TABLE_MAX_PAGES = 100;
pub const TABLE_MAX_ROWS = Page.ROWS_PER_PAGE * TABLE_MAX_PAGES;

num_rows: u32,
pages: [TABLE_MAX_PAGES]?*Page,
allocator: Allocator,

pub fn newTable(allocator: Allocator) !*Table {
    const table = try allocator.create(Table);
    table.*.num_rows = 0;
    table.*.allocator = allocator;
    for (0..TABLE_MAX_PAGES) |i| {
        table.*.pages[i] = null;
    }
    return table;
}

pub fn freeTable(self: *Table) void {
    for (0..TABLE_MAX_PAGES) |i| {
        if (self.*.pages[i]) |page| {
            page.freePage(self.allocator);
        }
    }
    self.allocator.destroy(self);
}

pub fn rowSlot(self: *Table, row_num: u32) ExecuteError!*?Row {
    const page_num = row_num / Page.ROWS_PER_PAGE;
    const page = self.*.pages[page_num] orelse blk: {
        // Allocate memory only when we try to access page
        const allocated_page = Page.newPage(self.*.allocator) catch {
            return ExecuteError.ExecuteTableFull;
        };
        self.*.pages[page_num] = allocated_page;
        break :blk allocated_page;
    };
    const row_offset = row_num % Page.ROWS_PER_PAGE;
    return &page.rows[row_offset];
}

pub fn executeInsert(self: *Table, row: Row) ExecuteError!void {
    if (self.*.num_rows >= TABLE_MAX_ROWS) {
        return error.ExecuteTableFull;
    }
    const row_slot = self.rowSlot(self.*.num_rows) catch {
        return error.ExecuteTableFull;
    };
    row_slot.* = row;
    self.*.num_rows += 1;
    return;
}

pub fn executeSelect(self: *Table) ExecuteError!void {
    for (0..self.*.num_rows) |i| {
        const row = self.rowSlot(@as(u32, @intCast(i))) catch {
            return error.ExecuteTableFull;
        };
        const r = row.* orelse continue;
        r.print_row() catch {
            return error.ExecuteTableFull;
        };
    }
    return;
}
