const std = @import("std");
const Allocator = std.mem.Allocator;
const Random = std.rand.Random;
const TerminalBuffer = @import("../tui/TerminalBuffer.zig");
const interop = @import("../interop.zig");
const termbox = interop.termbox;
const math = std.math;

pub const Starfield = @This();
const CHARACTERS = &[_]u32{
    '★', // Black star
    '☆', // White star
    '✧', // Sparkles
    '✦', // Black four-pointed star
    '✶', // Six-pointed black star
    '✴', // Eight-pointed black star
    '✹', // Heavy twelve-pointed star
};

pub const Star = struct {
    x: f32,
    y: f32,
    z: f32,
    character: u32, // Unicode character for the star

    pub fn randomize(self: *Star, random: *Random, characters: []const u32) void {
        self.x = (random.float(f32) * 2.0) - 1.0; // [-1.0, 1.0]
        self.y = (random.float(f32) * 2.0) - 1.0; // [-1.0, 1.0]
        self.z = (random.float(f32) * 0.8) + 0.2; // [0.2, 1.0]
        self.character = characters[random.intRangeAtMost(usize, 0, characters.len - 1)]; // Randomly select a character
    }
};

allocator: Allocator,
terminal_buffer: *TerminalBuffer,
stars: []Star,
max_depth: f32,
prev_x: []i32,
prev_y: []i32,
rotation_angle: f32,
characters: []const u32,

pub fn init(
    allocator: Allocator,
    terminal_buffer: *TerminalBuffer,
) !Starfield {
    // Calculate the number of stars based on terminal width and height
    const star_count = calculateStarCount(terminal_buffer.width, terminal_buffer.height);

    const stars = try allocator.alloc(Star, star_count);
    const prev_x = try allocator.alloc(i32, star_count);
    const prev_y = try allocator.alloc(i32, star_count);

    for (stars) |*star| {
        star.randomize(&terminal_buffer.random, CHARACTERS);
    }

    return .{
        .allocator = allocator,
        .terminal_buffer = terminal_buffer,
        .stars = stars,
        .max_depth = 1.0,
        .prev_x = prev_x,
        .prev_y = prev_y,
        .rotation_angle = 0.0,
        .characters = CHARACTERS,
    };
}

pub fn deinit(self: Starfield) void {
    self.allocator.free(self.stars);
    self.allocator.free(self.prev_x);
    self.allocator.free(self.prev_y);
}

pub fn draw(self: *Starfield) void {
    const width: f32 = @floatFromInt(self.terminal_buffer.width);
    const height: f32 = @floatFromInt(self.terminal_buffer.height);
    const half_width = width / 2.0;
    const half_height = height / 2.0;

    // Update rotation angle for camera effect
    self.rotation_angle += 0.01;

    for (self.stars, 0..) |*star, i| {
        // Erase the previous star position
        if (self.prev_x[i] >= 0 and self.prev_x[i] < @as(i32, @intCast(self.terminal_buffer.width)) and
            self.prev_y[i] >= 0 and self.prev_y[i] < @as(i32, @intCast(self.terminal_buffer.height)))
        {
            _ = termbox.tb_set_cell(self.prev_x[i], self.prev_y[i], ' ', 0, termbox.TB_DEFAULT);
        }

        // Update star's position
        star.z -= 0.02;
        if (star.z <= 0.0) {
            star.randomize(&self.terminal_buffer.random, self.characters);
        }

        // Rotate star in 3D space (camera rotation effect)
        const cos_angle = math.cos(self.rotation_angle);
        const sin_angle = math.sin(self.rotation_angle);
        const rotated_x = star.x * cos_angle - star.y * sin_angle;
        const rotated_y = star.x * sin_angle + star.y * cos_angle;

        // Project 3D to 2D
        const sx: i32 = @as(i32, @intFromFloat((rotated_x / star.z) * half_width + half_width));
        const sy: i32 = @as(i32, @intFromFloat((rotated_y / star.z) * half_height + half_height));

        // Store current position for motion blur
        self.prev_x[i] = sx;
        self.prev_y[i] = sy;

        // Draw the star if it's within the terminal bounds
        if (sx >= 0 and sx < @as(i32, @intCast(self.terminal_buffer.width)) and
            sy >= 0 and sy < @as(i32, @intCast(self.terminal_buffer.height)))
        {
            // Draw motion blur (line from previous position to current position)
            if (self.prev_x[i] != sx or self.prev_y[i] != sy) {
                drawLine(self.prev_x[i], self.prev_y[i], sx, sy);
            }

            // Draw the star using its Unicode character
            _ = termbox.tb_set_cell(sx, sy, star.character, termbox.TB_DEFAULT, termbox.TB_DEFAULT);
        }
    }
}

fn drawLine(x0: i32, y0: i32, x1: i32, y1: i32) void {
    const dx = @abs(x1 - x0);
    const dy = @abs(y1 - y0);
    const sx = if (x0 < x1) @as(i32, 1) else @as(i32, -1); // Explicitly cast to i32
    const sy = if (y0 < y1) @as(i32, 1) else @as(i32, -1); // Explicitly cast to i32
    var err = @as(i32, @intCast(dx - dy)); // Cast to i32 to handle signed arithmetic

    var x = x0;
    var y = y0;

    while (true) {
        _ = termbox.tb_set_cell(x, y, ' ', termbox.TB_DEFAULT, termbox.TB_DEFAULT);

        if (x == x1 and y == y1) break;

        const e2 = 2 * err;
        if (e2 > -@as(i32, @intCast(dy))) { // Cast dy to i32 before negation
            err -= @as(i32, @intCast(dy)); // Cast dy to i32
            x += sx;
        }
        if (e2 < @as(i32, @intCast(dx))) { // Cast dx to i32
            err += @as(i32, @intCast(dx)); // Cast dx to i32
            y += sy;
        }
    }
}

pub fn realloc(self: *Starfield) !void {
    // Recalculate the number of stars based on the current terminal size
    const new_star_count = calculateStarCount(self.terminal_buffer.width, self.terminal_buffer.height);

    const stars = try self.allocator.realloc(self.stars, new_star_count);
    const prev_x = try self.allocator.realloc(self.prev_x, new_star_count);
    const prev_y = try self.allocator.realloc(self.prev_y, new_star_count);

    // Initialize new stars if the array size increased
    if (new_star_count > self.stars.len) {
        for (stars[self.stars.len..new_star_count]) |*star| {
            star.randomize(&self.terminal_buffer.random, self.characters);
        }
    }

    self.stars = stars;
    self.prev_x = prev_x;
    self.prev_y = prev_y;
}

fn calculateStarCount(width: usize, height: usize) usize {
    // Adjust the number of stars based on the terminal size
    const base_star_count = 100;
    const scale_factor = (width * height) / (80 * 24);
    return base_star_count * scale_factor;
}
