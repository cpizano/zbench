/// Written by carlos.pizano@gmail.com
///
///
const Allocator = std.mem.Allocator;

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    defer bw.flush() catch |err| {
        std.debug.print("error flushing stdout: {}\n", .{err});
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        _ = gpa.deinit();
    }

    try stdout.print("benchmarking zig std library:\n", .{});

    try staticStringMapBench(allocator);
}

pub fn readFile(allocator: Allocator, filename: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();
    const stat = try file.stat();
    return try file.readToEndAlloc(allocator, stat.size);
}

pub fn staticStringMapBench(allocator: Allocator) !void {
    const data = try readFile(allocator, "input/cat_lib_00.txt");
    defer allocator.free(data);

    const delimiters = [_]u8{ ' ', '\n', '.', ',', '"', ';', '[', ']', '(', ')', '{', '}', ':', '!', '=', '&', '*', '|' };

    var tokens = std.mem.splitAny(u8, data, &delimiters);
    while (tokens.next()) |token| {
        if (!std.mem.eql(u8, token, "")) {
            std.debug.print("{s}\n", .{token});
        }
    }
}

const std = @import("std");
const lib = @import("zbench_lib");
