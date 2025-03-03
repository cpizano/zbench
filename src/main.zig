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

    try stdout.print("benchmarking zig code.\n  toolchain : {}\n", .{builtin.zig_version});

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

    for (0..200) |_| {
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
        stats_filter.add_sample(duration);
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

//  So far:
//  zig build run -Doptimize=ReleaseFast
//
// benchmarking zig std library (3MiB of it):
// staticStringMap: wall = 3923 uS,  per item = 17 nS, miss/hit = 3
//
// benchmarking zig std library:
// staticStringMap: wall = 4340 uS,  per item = 19 nS, miss/hit = 3
//
// Notes
// The current input dataset:
// - zero hits:
//   anyframe, async, await, export, resume, linksection, suspend and usingnamespace.
// - less than 10:
//   addrsspace, allowzero, noinline, nosuspend, opaque, threadlocal
// - const vs var
//   var 1672 and cost 10644 times
// - most common
//   const 10k, pub 7.5k, return 5.5k, try 5.3k, fn 3.3k, if 2.7k, error 2.1k, else 1.8k.

// feb 28
// Clearly we need to somehow control external factors, like cpu affinity and others:
//
// staticStringMap: wall avg = 3288.69 uS,  per item = 15.04 nS, miss/hit ratio = 3
// staticStringMap: wall avg = 3200.31 uS,  per item = 14.63 nS, miss/hit ratio = 3
// staticStringMap: wall avg = 2893.39 uS,  per item = 13.23 nS, miss/hit ratio = 3
// staticStringMap: wall avg = 2786.88 uS,  per item = 12.74 nS, miss/hit ratio = 3
// staticStringMap: wall avg = 2806.07 uS,  per item = 12.83 nS, miss/hit ratio = 3
// staticStringMap: wall avg = 2824.52 uS,  per item = 12.91 nS, miss/hit ratio = 3
// staticStringMap: wall avg = 2849.57 uS,  per item = 13.03 nS, miss/hit ratio = 3
// staticStringMap: wall avg = 2833.65 uS,  per item = 12.96 nS, miss/hit ratio = 3
// staticStringMap: wall avg = 2785.65 uS,  per item = 12.74 nS, miss/hit ratio = 3
//
// march 1
//

// ~/src/zbench main $ zig build -Doptimize=ReleaseFast  --zig-lib-dir /Users/cpu/src/zig/lib

// ~/src/zbench main $ sudo cpulimit --verbose -l 100 zig-out/bin/zbench
// ~/src/zbench main $ taskpolicy -c background zig-out/bin/zbench

//  ~/src/zbench main $ zig build run -Doptimize=ReleaseFast
// benchmarking zig std library:
// staticStringMap:
//   mean = 2405.54 uS,  per item = 11.00 nS
//   stdev 410.06 uS, uncertainty 102.52 uS
//
// staticStringMap:
//   mean = 2407.57 uS,  per item = 11.01 nS
//   stdev 412.18 uS, uncertainty 103.05 uS
//
// staticStringMap:
//   mean = 2446.21 uS,  per item = 11.18 nS
//   stdev 476.07 uS, uncertainty 119.02 uS
//
// staticStringMap:
//   mean = 2384.10 uS,  per item = 10.90 nS
//   stdev 354.07 uS, uncertainty 88.52 uS
//

//  ~/src/zbench main $ zig build run -Doptimize=ReleaseFast  --zig-lib-dir /Users/cpu/src/zig/lib
// benchmarking zig std library:
// staticStringMap:
//   mean = 2435.52 uS,  per item = 11.14 nS
//   stdev 468.45 uS, uncertainty 117.11 uS
//  ~/src/zbench main $ zig build run -Doptimize=ReleaseFast  --zig-lib-dir /Users/cpu/src/zig/lib
//
// staticStringMap:
//   mean = 2280.83 uS,  per item = 10.43 nS
//   stdev 23.28 uS, uncertainty 5.82 uS
//  ~/src/zbench main $ zig build run -Doptimize=ReleaseFast  --zig-lib-dir /Users/cpu/src/zig/lib
//
// staticStringMap:
//   mean = 2304.81 uS,  per item = 10.54 nS
//   stdev 107.30 uS, uncertainty 26.83 uS
