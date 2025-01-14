const std = @import("std");
const Allocator = std.mem.Allocator;
const TerminalBuffer = @import("../tui/TerminalBuffer.zig");
const interop = @import("../interop.zig");
const termbox = interop.termbox;

const Raindrops = @This();

// Character for raindrop
pub const DROP_CHAR: u32 = '!';
// Character for splash effect
pub const SPLASH_CHAR: u32 = '*';
// Frame delay for the animation
pub const FRAME_DELAY: u64 = 5;
// Frames to display the splash
pub const SPLASH_DURATION: u64 = 6;

pub const Drop = struct {
    x: usize,
    y: usize,
    active: bool,
    splash_timer: u64,
};

allocator: Allocator,
terminal_buffer: *TerminalBuffer,
drops: []Drop,
frame_count: u64,

pub fn init(allocator: Allocator, terminal_buffer: *TerminalBuffer) !Raindrops {
    const drops = try allocator.alloc(Drop, terminal_buffer.width);
    for (drops) |*drop| {
        drop.x = 0;
        drop.y = 0;
        drop.active = false;
        drop.splash_timer = 0;
    }

    return .{
        .allocator = allocator,
        .terminal_buffer = terminal_buffer,
        .drops = drops,
        .frame_count = 0,
    };
}

pub fn deinit(self: Raindrops) void {
    self.allocator.free(self.drops);
}

pub fn realloc(self: *Raindrops) !void {
    const drops = try self.allocator.realloc(self.drops, self.terminal_buffer.width);
    for (drops) |*drop| {
        drop.x = 0;
        drop.y = 0;
        drop.active = false;
        drop.splash_timer = 0;
    }
    self.drops = drops;
}

pub fn draw(self: *Raindrops) void {
    self.frame_count += 1;
    if (self.frame_count % FRAME_DELAY != 0) return;

    const width = self.terminal_buffer.width;
    const height = self.terminal_buffer.height;

    for (self.drops) |*drop| {
        if (drop.splash_timer > 0) {
            drop.splash_timer -= 1;
            if (drop.splash_timer == 0) {
                _ = termbox.tb_set_cell(@intCast(drop.x), @intCast(height - 1), ' ', termbox.TB_DEFAULT, termbox.TB_DEFAULT);
            }
            continue;
        }

        if (!drop.active) {
            if (self.terminal_buffer.random.int(u16) % (FRAME_DELAY * FRAME_DELAY) == 0) {
                drop.x = self.terminal_buffer.random.int(u16) % width;
                drop.y = 0;
                drop.active = true;
            }
        } else {
            // Clear current position
            _ = termbox.tb_set_cell(@intCast(drop.x), @intCast(drop.y), ' ', termbox.TB_DEFAULT, termbox.TB_DEFAULT);

            // Move drop down
            drop.y += 1;

            if (drop.y >= height - 1) {
                // Show splash effect at the bottom
                _ = termbox.tb_set_cell(@intCast(drop.x), @intCast(height - 1), SPLASH_CHAR, termbox.TB_WHITE, termbox.TB_DEFAULT);
                drop.active = false;
                drop.splash_timer = SPLASH_DURATION;
            } else {
                // Draw drop in new position with color gradient
                const fg_color = termbox.TB_DEFAULT | ((@as(u16, @intCast(drop.y)) * 2) % 8);
                _ = termbox.tb_set_cell(@intCast(drop.x), @intCast(drop.y), DROP_CHAR, @intCast(fg_color), termbox.TB_DEFAULT);
            }
        }
    }

    // Add randomized wind effect
    if (self.terminal_buffer.random.int(u16) % (FRAME_DELAY * 2) == 0) {
        for (self.drops) |*drop| {
            if (drop.active and drop.y > 0 and drop.y < height - 1) {
                if (self.terminal_buffer.random.int(u16) % 2 == 0 and drop.x > 0) {
                    drop.x -= 1;
                } else if (drop.x < width - 1) {
                    drop.x += 1;
                }
            }
        }
    }
}
