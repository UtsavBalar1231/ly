const std = @import("std");
const Allocator = std.mem.Allocator;
const Random = std.rand.Random;
const TerminalBuffer = @import("../tui/TerminalBuffer.zig");
const interop = @import("../interop.zig");
const termbox = interop.termbox;
const math = std.math;

pub const Starfield = @This();

pub const Star = struct {
    x: f32,
    y: f32,
    z: f32,
    color: u16,

    pub fn randomize(self: *Star, random: *Random) void {
        self.x = (random.float(f32) * 2.0) - 1.0; // [-1.0, 1.0]
        self.y = (random.float(f32) * 2.0) - 1.0; // [-1.0, 1.0]
        self.z = (random.float(f32) * 0.8) + 0.2; // [0.2, 1.0]
        self.color = random.intRangeAtMost(u16, 0, 7);
    }
};

allocator: Allocator,
terminal_buffer: *TerminalBuffer,
stars: []Star,
max_depth: f32,
star_count: usize,

pub fn init(
    allocator: Allocator,
    terminal_buffer: *TerminalBuffer,
    star_count: usize,
) !Starfield {
    const stars = try allocator.alloc(Star, star_count);

    for (stars) |*star| {
        star.randomize(&terminal_buffer.random);
    }

    return .{
        .allocator = allocator,
        .terminal_buffer = terminal_buffer,
        .stars = stars,
        .max_depth = 1.0,
        .star_count = star_count,
    };
}

pub fn deinit(self: Starfield) void {
    self.allocator.free(self.stars);
}

pub fn draw(self: *Starfield) void {
    const width: f32 = @floatFromInt(self.terminal_buffer.width); // Convert usize to f32
    const height: f32 = @floatFromInt(self.terminal_buffer.height); // Convert usize to f32

    for (self.stars) |*star| {
        // Update star's position
        star.z -= 0.02;
        if (star.z <= 0.0) {
            star.randomize(&self.terminal_buffer.random);
        }

        // Project 3D to 2D
        const sx: i32 = @as(i32, @intFromFloat((star.x / star.z) * (width / 2.0) + (width / 2.0)));
        const sy: i32 = @as(i32, @intFromFloat((star.y / star.z) * (height / 2.0) + (height / 2.0)));

        if (sx >= 0 and sx < @as(i32, @intCast(self.terminal_buffer.width)) and
            sy >= 0 and sy < @as(i32, @intCast(self.terminal_buffer.height)))
        {
            const brightness = @as(u16, @intFromFloat((1.0 - star.z / self.max_depth) * 255.0));
            const fg_color = star.color | (brightness << 8);

            _ = termbox.tb_set_cell(sx, sy, ' ', fg_color, termbox.TB_DEFAULT);
        }
    }
}

pub fn realloc(self: *Starfield) !void {
    const stars = try self.allocator.realloc(self.stars, self.star_count);

    for (stars) |*star| {
        star.randomize(&self.terminal_buffer.random);
    }

    self.stars = stars;
}
