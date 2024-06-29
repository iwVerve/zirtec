const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const ray = @import("raylib.zig");
const Tile = @import("Tile.zig");

const World = @This();

const config = @import("config.zig");
const Chunk = @import("chunk.zig").Chunk(config.chunk_size, config.chunk_size);

// tile_map: ArrayList(ArrayList(Tile)),
tiles_width: usize,
tiles_height: usize,
chunk_map: ArrayList(ArrayList(Chunk)),
chunks_width: usize,
chunks_height: usize,

allocator: Allocator,

const WorldOptions = struct {
    tile_width: usize = 128,
    tile_height: usize = 128,
};

pub fn init(allocator: Allocator, options: WorldOptions) !World {
    var chunk_map = ArrayList(ArrayList(Chunk)).init(allocator);
    const chunks_width = @divFloor(options.tile_width - 1, config.chunk_size) + 1;
    const chunks_height = @divFloor(options.tile_height - 1, config.chunk_size) + 1;

    for (0..chunks_height) |chunk_y| {
        var chunk_row = ArrayList(Chunk).init(allocator);
        for (0..chunks_width) |chunk_x| {
            const x: f32 = @floatFromInt(chunk_x * config.chunk_size * config.tile_size);
            const y: f32 = @floatFromInt(chunk_y * config.chunk_size * config.tile_size);
            const position: ray.Vector2 = .{ .x = x, .y = y };
            const chunk = Chunk.init(position);
            try chunk_row.append(chunk);
        }
        try chunk_map.append(chunk_row);
    }

    var world: World = .{
        .chunk_map = chunk_map,
        .chunks_width = chunks_width,
        .chunks_height = chunks_height,

        .tiles_width = config.chunk_size * chunks_width,
        .tiles_height = config.chunk_size * chunks_height,

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
    for (self.chunk_map.items) |chunk_row| {
        chunk_row.deinit();
    }
    self.chunk_map.deinit();
}

pub fn getChunkAssert(self: World, chunk_x: usize, chunk_y: usize) *Chunk {
    return &self.chunk_map.items[chunk_y].items[chunk_x];
}

pub fn getChunk(self: World, chunk_x: anytype, chunk_y: anytype) ?*Chunk {
    if (chunk_x < 0 or chunk_y < 0) {
        return null;
    }
    if (chunk_x >= self.chunks_width or chunk_y >= self.chunks_height) {
        return null;
    }
    return self.getChunkAssert(@intCast(chunk_x), @intCast(chunk_y));
}

pub fn getTileAssert(self: World, tile_x: usize, tile_y: usize) *Tile {
    const chunk_x = @divFloor(tile_x, config.chunk_size);
    const chunk_y = @divFloor(tile_y, config.chunk_size);
    const chunk_tile_x = @mod(tile_x, config.chunk_size);
    const chunk_tile_y = @mod(tile_y, config.chunk_size);

    const chunk = self.getChunkAssert(chunk_x, chunk_y);
    return chunk.getTileAssert(chunk_tile_x, chunk_tile_y);
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

    const chunk_pixels = config.tile_size * config.chunk_size;
    const clamp = std.math.clamp;

    const left_index: usize = @intFromFloat(clamp(@divFloor(camera_bounds.x, chunk_pixels), 0, @as(f32, @floatFromInt(self.chunks_width))));
    const top_index: usize = @intFromFloat(clamp(@divFloor(camera_bounds.y, chunk_pixels), 0, @as(f32, @floatFromInt(self.chunks_height))));
    const right_index: usize = @intFromFloat(clamp(@divFloor(camera_bounds.x + camera_bounds.width - 1, chunk_pixels) + 1, 0, @as(f32, @floatFromInt(self.chunks_width))));
    const bottom_index: usize = @intFromFloat(clamp(@divFloor(camera_bounds.y + camera_bounds.height - 1, chunk_pixels) + 1, 0, @as(f32, @floatFromInt(self.chunks_height))));

    for (top_index..bottom_index) |chunk_row| {
        for (left_index..right_index) |chunk_column| {
            const chunk: Chunk = self.chunk_map.items[chunk_row].items[chunk_column];
            chunk.draw();
        }
    }
}
