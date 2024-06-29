const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const ray = @import("raylib.zig");
const Tile = @import("Tile.zig");
const config = @import("config.zig");

const World = @This();

tile_map: ArrayList(ArrayList(Tile)),
tiles_width: usize,
tiles_height: usize,

allocator: Allocator,

const WorldOptions = struct {
    tile_width: usize = 128,
    tile_height: usize = 128,
};

pub fn init(allocator: Allocator, options: WorldOptions) !World {
    var tile_map = ArrayList(ArrayList(Tile)).init(allocator);
    for (0..options.tile_height) |_| {
        var tile_row = ArrayList(Tile).init(allocator);
        for (0..options.tile_width) |_| {
            const tile: Tile = .{ .empty = true };
            try tile_row.append(tile);
        }
        try tile_map.append(tile_row);
    }

    var world: World = .{
        .tile_map = tile_map,
        .tiles_width = options.tile_width,
        .tiles_height = options.tile_height,

        .allocator = allocator,
    };

    var prng = std.Random.DefaultPrng.init(0);
    const rand = prng.random();
    for (0..options.tile_height) |y| {
        for (0..options.tile_width) |x| {
            const tile = world.getTileAssert(x, y);
            if (rand.int(u4) == 0) {
                tile.empty = false;
            }
        }
    }
    for (0..@min(options.tile_width, options.tile_height)) |i| {
        const tile = world.getTileAssert(i, options.tile_height - i - 1);
        tile.empty = false;
    }

    return world;
}

pub fn deinit(self: *World) void {
    for (self.tile_map.items) |tile_row| {
        tile_row.deinit();
    }
    self.tile_map.deinit();
}

pub fn getTileAssert(self: World, tile_x: usize, tile_y: usize) *Tile {
    return &self.tile_map.items[tile_y].items[tile_x];
}

pub fn getTile(self: World, tile_x: usize, tile_y: usize) ?*Tile {
    if (tile_x >= self.tiles_width or tile_y >= self.tiles_height) {
        return null;
    }
    return self.getTileAssert(tile_x, tile_y);
}

pub fn draw(self: World, camera: ray.Camera2D) void {
    const camera_bounds: ray.Rectangle = .{
        .x = camera.target.x - camera.zoom * camera.offset.x,
        .y = camera.target.y - camera.zoom * camera.offset.y,
        .width = config.window_width,
        .height = config.window_height,
    };

    const clamp = std.math.clamp;

    const left_index: usize = @intFromFloat(clamp(@divFloor(camera_bounds.x, config.tile_size), 0, @as(f32, @floatFromInt(self.tiles_width))));
    const top_index: usize = @intFromFloat(clamp(@divFloor(camera_bounds.y, config.tile_size), 0, @as(f32, @floatFromInt(self.tiles_height))));
    const right_index: usize = @intFromFloat(clamp(@divFloor(camera_bounds.x + camera_bounds.width - 1, config.tile_size) + 1, 0, @as(f32, @floatFromInt(self.tiles_width))));
    const bottom_index: usize = @intFromFloat(clamp(@divFloor(camera_bounds.y + camera_bounds.height - 1, config.tile_size) + 1, 0, @as(f32, @floatFromInt(self.tiles_height))));

    for (top_index..bottom_index) |tile_y| {
        for (left_index..right_index) |tile_x| {
            const tile = self.getTileAssert(tile_x, tile_y);
            const rectangle: ray.Rectangle = .{
                .x = @floatFromInt(tile_x * config.tile_size),
                .y = @floatFromInt(tile_y * config.tile_size),
                .width = config.tile_size,
                .height = config.tile_size,
            };
            tile.draw(rectangle);
        }
    }
}
