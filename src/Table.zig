const std = @import("std");
const Allocator = std.mem.Allocator;

const Row = @import("Row.zig");
const Page = @import("Page.zig");
const Pager = @import("Pager.zig");

pub const ExecuteError = error{ExecuteTableFull};

pub const Table = @This();

num_rows: u32,
pager: *Pager,
allocator: Allocator,

pub fn dbOpen(allocator: Allocator, filename: []const u8) !*Table {
    const pager = try Pager.pagerOpen(allocator, filename);
    const num_rows = pager.file_length / Row.ROW_SIZE;

    const table = try allocator.create(Table);
    table.* = .{
        .num_rows = @as(u32, @intCast(num_rows)),
        .pager = pager,
        .allocator = allocator,
    };
    return table;
}

pub fn dbClose(self: *Table) void {
    defer self.allocator.destroy(self);
    defer self.pager.pagerClose();

    const num_full_pages = self.num_rows / Page.ROWS_PER_PAGE;

    for (0..num_full_pages) |i| {
        self.pager.pagerFlush(@as(u32, @intCast(i))) catch {
            std.debug.print("Ignoring the error while flushing the page.", .{});
        };
    }

    // There may be a partial page to write to the end of the file
    // This should not be needed after we switch to a B-tree
    const num_additional_rows = self.num_rows % Page.ROWS_PER_PAGE;
    if (num_additional_rows > 0) {
        const page_num = num_full_pages;
        self.pager.pagerFlush(@as(u32, @intCast(page_num))) catch {
            std.debug.print("Ignoring the error while flushing the page.", .{});
        };
    }
}

pub fn rowSlot(self: *Table, row_num: u32) !*?Row {
    const page_num = row_num / Page.ROWS_PER_PAGE;
    const page = try self.pager.getPage(@as(u32, @intCast(page_num)));
    const row_offset = row_num % Page.ROWS_PER_PAGE;
    return &page.rows[row_offset];
}

pub fn executeInsert(self: *Table, row: Row) !void {
    if (self.num_rows >= Pager.TABLE_MAX_ROWS) {
        return ExecuteError.ExecuteTableFull;
    }
    const row_slot = self.rowSlot(self.num_rows) catch {
        return ExecuteError.ExecuteTableFull;
    };
    row_slot.* = row;
    self.num_rows += 1;
    return;
}

pub fn executeSelect(self: *Table) !void {
    for (0..self.num_rows) |i| {
        const row = self.rowSlot(@as(u32, @intCast(i))) catch {
            return ExecuteError.ExecuteTableFull;
        };
        const r = row.* orelse continue;
        r.printRow() catch {
            return ExecuteError.ExecuteTableFull;
        };
    }
    return;
}
