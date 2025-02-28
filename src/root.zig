/// Written by carlos.pizano@gmail.com
///
///
const std = @import("std");
const testing = std.testing;

pub fn StatsFilter(comptime T: type) type {
    switch (@typeInfo(T)) {
        .int, .float => {},
        else => {
            @compileError("Needs a numeric type\n");
        },
    }

    return struct {
        const capacity = 7;
        const Self = @This();
        samples: std.BoundedArray(T, capacity),

        pub fn init() !Self {
            return .{ .samples = try std.BoundedArray(T, capacity).init(0) };
        }

        pub fn add_sample(self: *Self, sample: T) void {
            switch (self.samples.slice().len) {
                0...capacity - 1 => {
                    self.samples.append(sample) catch @panic("err");
                },
                capacity => {
                    self.replace_sample(sample);
                },
                else => @panic("whoa!"),
            }
        }

        pub fn calc_average(self: *Self) f64 {
            var sum: T = 0;
            for (self.samples.constSlice()) |s| {
                sum += s;
            }
            return @as(f64, @floatFromInt(sum)) / @as(f64, @floatFromInt(self.samples.slice().len));
        }

        fn replace_sample(self: *Self, sample: T) void {
            var max_dev: T = 0;
            var max_dev_ix: ?usize = null;
            for (self.samples.slice(), 0..) |s, i| {
                const dev = @abs(sample - s);
                if (dev > max_dev) {
                    max_dev = dev;
                    max_dev_ix = i;
                }
            }
            if (max_dev_ix) |ix| {
                self.samples.slice()[ix] = sample;
            }
        }

        pub fn dump(self: *Self, writer: anytype) !void {
            for (self.samples.slice()) |s| {
                try writer.print("= {}\n", .{s});
            }
        }
    };
}
