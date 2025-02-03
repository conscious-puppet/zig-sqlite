const std = @import("std");
const Allocator = std.mem.Allocator;
const File = std.fs.File;

const Page = @import("Page.zig");
const Row = @import("Row.zig");

pub const Pager = @This();

pub const PagerError = error{ OpenFileError, CreateFileError, MetadataError };
pub const GetPageError = error{PageNumberOutOfBound};
pub const PagerFlushError = error{ NullPageFlush, FileSeekError, FileWriteError };

pub const PAGE_SIZE = 4096;
pub const TABLE_MAX_PAGES = 100;
pub const TABLE_MAX_ROWS = Page.ROWS_PER_PAGE * TABLE_MAX_PAGES;

file: File,
file_length: u64,
pages: [TABLE_MAX_PAGES]?*Page,
allocator: Allocator,

pub fn pagerOpen(allocator: Allocator, filename: []const u8) !*Pager {
    const writer = std.io.getStdOut().writer();

    blk: {
        const create_file = std.fs.cwd().createFile(filename, .{ .exclusive = true }) catch |err| {
            switch (err) {
                error.PathAlreadyExists => {
                    break :blk;
                },
                else => {
                    try writer.print("Unable to create file.\n", .{});
                    return PagerError.CreateFileError;
                },
            }
        };
        defer create_file.close();
    }

    const open_file = std.fs.cwd().openFile(filename, .{
        .mode = .read_write,
    }) catch {
        try writer.print("Unable to open file.\n", .{});
        return PagerError.OpenFileError;
    };

    const file_metadata = open_file.metadata() catch {
        try writer.print("Unable to read file metadata.\n", .{});
        return PagerError.MetadataError;
    };

    const file_length = file_metadata.size();

    const pager = try allocator.create(Pager);
    pager.file = open_file;
    pager.file_length = file_length;
    pager.allocator = allocator;

    for (0..TABLE_MAX_PAGES) |i| {
        pager.pages[i] = null;
    }

    return pager;
}

pub fn pagerClose(self: *Pager) void {
    defer self.allocator.destroy(self);
    defer self.file.close();

    for (0..TABLE_MAX_PAGES) |i| {
        if (self.pages[i]) |page| {
            page.freePage(self.allocator);
        }
    }
}

pub fn getPage(self: *Pager, page_num: u32) !*Page {
    const writer = std.io.getStdOut().writer();
    if (page_num > TABLE_MAX_PAGES) {
        try writer.print(
            "Tried to fetch page number out of bounds. {} > {}\n",
            .{ page_num, TABLE_MAX_PAGES },
        );
        return GetPageError.PageNumberOutOfBound;
    }
    const page = self.pages[page_num] orelse blk: {
        // Cache miss. Allocate memory and load from file.
        const allocated_page = try Page.newPage(self.allocator);
        var num_pages = self.file_length / PAGE_SIZE;

        // We might save a partial page at the end of the file
        if (self.file_length % PAGE_SIZE == 0) {
            num_pages += 1;
        }

        if (page_num <= num_pages) {
            try self.file.seekTo(page_num * PAGE_SIZE);
            var page_buffer = [_]u8{0} ** PAGE_SIZE;
            const bytes_read = self.file.read(&page_buffer) catch |err| {
                try writer.print("Error reading file: {}\n", .{err});
                return err;
            };

            for (0..Page.ROWS_PER_PAGE) |i| {
                const start = i * Row.ROW_SIZE;
                const end = (i + 1) * Row.ROW_SIZE;
                if (end > bytes_read) {
                    break;
                }
                const row = std.mem.bytesToValue(Row, page_buffer[start..end]);
                allocated_page.rows[i] = row;
            }
        }
        self.pages[page_num] = allocated_page;
        break :blk allocated_page;
    };
    return page;
}

pub fn pagerFlush(self: *Pager, page_num: u32) !void {
    const writer = std.io.getStdOut().writer();
    if (self.pages[page_num]) |page| {
        self.file.seekTo(page_num * PAGE_SIZE) catch {
            try writer.print("Error seeking database file.\n", .{});
            return PagerFlushError.FileSeekError;
        };

        var bytes = std.ArrayList(u8).init(self.allocator);
        defer bytes.deinit();

        for (0..Page.ROWS_PER_PAGE) |i| {
            if (page.rows[i]) |row| {
                try bytes.appendSlice(std.mem.asBytes(&row));
            }
        }

        _ = self.file.write(bytes.items) catch {
            try writer.print("Error writing to database file.\n", .{});
            return PagerFlushError.FileWriteError;
        };
    } else {
        try writer.print("Tried to flush null page\n", .{});
        return PagerFlushError.NullPageFlush;
    }
}
