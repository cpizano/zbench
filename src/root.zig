/// Written by carlos.pizano@gmail.com
///
///
const std = @import("std");
const testing = std.testing;

pub fn StatsFilter(comptime T: type, comptime capacity: usize) type {
    switch (@typeInfo(T)) {
        .int, .float => {},
        else => {
            @compileError("Needs a numeric type\n");
        },
    }

    return struct {
        const Self = @This();
        samples: std.BoundedArray(T, capacity),
        sum: T,

        pub fn init() !Self {
            return .{
                .samples = try std.BoundedArray(T, capacity).init(0),
                .sum = 0,
            };
        }

        pub fn add_sample(self: *Self, sample: T) void {
            switch (self.samples.slice().len) {
                0...capacity - 1 => {
                    self.samples.append(sample) catch @panic("err");
                    self.sum += sample;
                },
                capacity => {
                    self.maybe_replace_sample(sample);
                },
                else => @panic("whoa!"),
            }
        }

        pub fn get_stats(self: *Self) struct { mean: f64, sdev: f64, uncert: f64 } {
            const count: f64 = @floatFromInt(self.samples.slice().len);
            const mean = @as(f64, @floatFromInt(self.sum)) / count;
            var sum_d_sqr: f64 = 0;
            for (self.samples.slice()) |s| {
                const delta = (@as(f64, @floatFromInt(s)) - mean);
                sum_d_sqr += delta * delta;
            }
            const deviation = @sqrt(sum_d_sqr / count);
            return .{
                .mean = mean,
                .sdev = deviation,
                .uncert = deviation / @sqrt(count),
            };
        }

        // Replace the sample that has the largest variance compared with
        // the variance of the new sample.
        fn maybe_replace_sample(self: *Self, new_sample: T) void {
            const average = self.sum / self.samples.slice().len;
            var nsd: T = @abs(average - new_sample);
            var nsd_ix: ?usize = null;
            for (self.samples.slice(), 0..) |s, i| {
                const dev = @abs(average - s);
                if (dev > nsd) {
                    nsd = dev;
                    nsd_ix = i;
                }
            }
            if (nsd_ix) |ix| {
                self.sum += new_sample - self.samples.slice()[ix];
                self.samples.slice()[ix] = new_sample;
            }
        }

        pub fn dump(self: *Self, writer: anytype) !void {
            for (self.samples.slice()) |s| {
                try writer.print("= {}\n", .{s});
            }
        }
    };
}
