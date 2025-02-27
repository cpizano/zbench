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

    const delimiters = [_]u8{ //.
        ' ', '\n', '.', ',', ';', '[', ']', '(', ')', '{', '}', //.
        ':', '!',  '=', '&', '*', '|', '?', '+', '-', '>', '<',
    };

    const State = enum {
        Code,
        Comment,
        String,
    };

    var state: State = .Code;
    var strings: u32 = 0;
    var comments: u32 = 0;
    var code: u32 = 0;

    var stop: u32 = 200;

    var tokens = std.mem.splitAny(u8, data, &delimiters);
    while (tokens.next()) |token| {
        if (token.len == 0)
            continue;

        if (stop > 0) {
            stop -= 1;
        } else {
            break;
        }

        sw: switch (state) {
            .Code => {
                if (token[0] == '"') {
                    state = .String;
                    continue :sw .String;
                } else if (std.mem.startsWith(u8, token, "//")) {
                    state = .Comment;
                    continue :sw .Comment;
                } else {
                    code += 1;
                    std.debug.print("{s}\n", .{token});
                }
            },
            .Comment => {
                if (tokens.rest().len != 0 and tokens.rest()[0] == '\n') {
                    state = .Code;
                    comments += 1;
                }
            },
            .String => {
                if (token[token.len - 1] == '"') {
                    state = .Code;
                    strings += 1;
                }
            },
        }
    }
    std.log.info("code: {}, comments: {}, strings {}", .{ code, comments, strings });
}

const std = @import("std");
const lib = @import("zbench_lib");
