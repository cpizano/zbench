// Copyright 2025 Carlos Pizano Uribe. All rights reserved.
// Use of this source code is governed by the MIT license that can be
// found in the LICENSE file.

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

    try stdout.print("Zbench 0.1. Toolchain : {}\n", .{builtin.zig_version});

    if (builtin.mode != .ReleaseFast) {
        try stdout.print("!! not a release-fast build\n", .{});
    }

    try staticStringMapBench(allocator, &stdout);
}

pub fn readFile(allocator: Allocator, filename: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();
    const stat = try file.stat();
    return try file.readToEndAlloc(allocator, stat.size);
}

pub fn generateTokens(allocator: Allocator, data: []const u8) !std.ArrayList([]const u8) {
    var final_tokens = std.ArrayList([]const u8).init(allocator);

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

    var tokens = std.mem.splitAny(u8, data, &delimiters);
    while (tokens.next()) |token| {
        if (token.len == 0)
            continue;

        sw: switch (state) {
            .Code => {
                if (token[0] == '"') {
                    state = .String;
                    continue :sw .String;
                } else if (std.mem.startsWith(u8, token, "//")) {
                    state = .Comment;
                    continue :sw .Comment;
                } else {
                    try final_tokens.append(token);
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
    std.log.info("code: {}, comments: {}, strings {}", .{ final_tokens.items.len, comments, strings });
    return final_tokens;
}

pub fn staticStringMapBench(allocator: Allocator, writer: anytype) !void {
    const data = try readFile(allocator, "input/cat_lib_00.txt");
    defer allocator.free(data);

    var tokens = try generateTokens(allocator, data);
    defer tokens.deinit();

    const Tag = enum(u32) {
        keyword_addrspace,
        keyword_align,
        keyword_allowzero,
        keyword_and,
        keyword_anyframe,
        keyword_anytype,
        keyword_asm,
        keyword_async,
        keyword_await,
        keyword_break,
        keyword_callconv,
        keyword_catch,
        keyword_comptime,
        keyword_const,
        keyword_continue,
        keyword_defer,
        keyword_else,
        keyword_enum,
        keyword_errdefer,
        keyword_error,
        keyword_export,
        keyword_extern,
        keyword_fn,
        keyword_for,
        keyword_if,
        keyword_inline,
        keyword_noalias,
        keyword_noinline,
        keyword_nosuspend,
        keyword_opaque,
        keyword_or,
        keyword_orelse,
        keyword_packed,
        keyword_pub,
        keyword_resume,
        keyword_return,
        keyword_linksection,
        keyword_struct,
        keyword_suspend,
        keyword_switch,
        keyword_test,
        keyword_threadlocal,
        keyword_try,
        keyword_union,
        keyword_unreachable,
        keyword_usingnamespace,
        keyword_var,
        keyword_volatile,
        keyword_while,
    };

    const keywords = std.StaticStringMap(Tag).initComptime(.{
        .{ "addrspace", .keyword_addrspace },
        .{ "align", .keyword_align },
        .{ "allowzero", .keyword_allowzero },
        .{ "and", .keyword_and },
        .{ "anyframe", .keyword_anyframe },
        .{ "anytype", .keyword_anytype },
        .{ "asm", .keyword_asm },
        .{ "async", .keyword_async },
        .{ "await", .keyword_await },
        .{ "break", .keyword_break },
        .{ "callconv", .keyword_callconv },
        .{ "catch", .keyword_catch },
        .{ "comptime", .keyword_comptime },
        .{ "const", .keyword_const },
        .{ "continue", .keyword_continue },
        .{ "defer", .keyword_defer },
        .{ "else", .keyword_else },
        .{ "enum", .keyword_enum },
        .{ "errdefer", .keyword_errdefer },
        .{ "error", .keyword_error },
        .{ "export", .keyword_export },
        .{ "extern", .keyword_extern },
        .{ "fn", .keyword_fn },
        .{ "for", .keyword_for },
        .{ "if", .keyword_if },
        .{ "inline", .keyword_inline },
        .{ "noalias", .keyword_noalias },
        .{ "noinline", .keyword_noinline },
        .{ "nosuspend", .keyword_nosuspend },
        .{ "opaque", .keyword_opaque },
        .{ "or", .keyword_or },
        .{ "orelse", .keyword_orelse },
        .{ "packed", .keyword_packed },
        .{ "pub", .keyword_pub },
        .{ "resume", .keyword_resume },
        .{ "return", .keyword_return },
        .{ "linksection", .keyword_linksection },
        .{ "struct", .keyword_struct },
        .{ "suspend", .keyword_suspend },
        .{ "switch", .keyword_switch },
        .{ "test", .keyword_test },
        .{ "threadlocal", .keyword_threadlocal },
        .{ "try", .keyword_try },
        .{ "union", .keyword_union },
        .{ "unreachable", .keyword_unreachable },
        .{ "usingnamespace", .keyword_usingnamespace },
        .{ "var", .keyword_var },
        .{ "volatile", .keyword_volatile },
        .{ "while", .keyword_while },
    });

    // The keywords strings is about 850 bytes if densely packed, but the SSM
    // stores them as  `keys: [*]const []const u8` so it is unclear how this data
    // is stored at comptime, or for that matter, at runtime.

    var hits: u32 = 0;
    var misses: u32 = 0;
    var kw_histogram = std.mem.zeroes([@typeInfo(Tag).@"enum".fields.len]u32);

    var stats_filter = try lib.StatsFilter(u64, 16).init();
    var timer = std.time.Timer.start() catch @panic("need timer to work");

    for (0..200) |ix| {
        const start = timer.read();

        for (tokens.items) |token| {
            if (keywords.get(token)) |kw| {
                hits += 1;
                kw_histogram[@intFromEnum(kw)] += 1;
            } else {
                misses += 1;
            }
        }
        const duration = timer.read() - start;
        if (ix > 5) {
            // skip the first 5 runs.
            stats_filter.add_sample(duration);
        }
    }

    // The historgram, besides giving interesting data, blocks the compiler from optimizing
    // the code under test down to nothing.
    for (kw_histogram, 0..) |count, i| {
        if (count > 1000) {
            const kw: Tag = @enumFromInt(i);
            std.log.info("keyword {} used {} times\n", .{ kw, count });
        }
    }
    std.log.info("keyword:  hits {}, misses {}", .{ hits, misses });

    const results = stats_filter.get_stats();
    const mean_per_item_ns = (results.mean) / @as(f64, @floatFromInt(tokens.items.len));

    try writer.print("staticStringMap:\n" ++ //.
        "  mean = {d:.2} uS,  per item = {d:.2} nS\n", //.
        .{ to_uSeconds(results.mean), mean_per_item_ns });
    try writer.print("  stdev {d:.2} uS, uncertainty {d:.2} uS\n", //.
        .{ to_uSeconds(results.sdev), to_uSeconds(results.uncert) });
}

fn to_uSeconds(nS: f64) f64 {
    return nS / 1000.0;
}

const std = @import("std");
const lib = @import("zbench_lib");
const builtin = @import("builtin");
