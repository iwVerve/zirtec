const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const ray = @import("raylib.zig");
const znoise = @import("znoise");
const Tile = @import("Tile.zig");
const config = @import("config.zig");

const World = @This();

tile_map: ArrayList(ArrayList(Tile)),
tiles_width: usize,
tiles_height: usize,

allocator: Allocator,

const WorldOptions = struct {
    tile_width: usize = 2048,
    tile_height: usize = 256,
};

fn generate(world: *World, options: WorldOptions) void {
    _ = options;
    const gen = znoise.FnlGenerator{
        .seed = 0,
        .frequency = 0.02,
        .fractal_type = .fbm,
    };

    const base_height = 48;
    const variation = 16;
    for (0..world.tiles_width) |tile_x| {
        const value = gen.noise2(@floatFromInt(tile_x), 0);
        const height: usize = @intFromFloat(@max(base_height + value * variation, 0));
        var dirt_blocks: u8 = @intFromFloat(8 + 4 * gen.noise2(@floatFromInt(tile_x), 32));
        for (height..world.tiles_height) |tile_y| {
            const tile = world.getTileAssert(tile_x, tile_y);
            if (dirt_blocks > 0) {
                tile.type = .dirt;
                dirt_blocks -= 1;
            } else {
                tile.type = .stone;
            }
        }
    }
}

fn initialize_light(self: *World) void {
    for (0..self.tiles_width) |tile_x| {
        for (0..self.tiles_height) |tile_y| {
            const tile = self.getTileAssert(tile_x, tile_y);
            if (tile.isOpaque()) {
                break;
            }
            self.setLightLevelAssert(tile_x, tile_y, 15);
            tile.sees_sky = true;
        }
    }
}

pub fn init(allocator: Allocator, options: WorldOptions) !World {
    var tile_map = ArrayList(ArrayList(Tile)).init(allocator);
    for (0..options.tile_height) |_| {
        var tile_row = ArrayList(Tile).init(allocator);
        for (0..options.tile_width) |_| {
            const tile: Tile = .{ .type = .empty };
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

    world.generate(options);
    world.initialize_light();

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
    if (!self.tileExists(tile_x, tile_y)) {
        return null;
    }
    return self.getTileAssert(tile_x, tile_y);
}

pub fn tileExists(self: World, tile_x: usize, tile_y: usize) bool {
    return tile_x < self.tiles_width and tile_y < self.tiles_height;
}

pub fn setLightLevelAssert(self: *World, tile_x: usize, tile_y: usize, light: u4) void {
    const tile = self.getTileAssert(tile_x, tile_y);
    if (light > tile.light) {
        tile.light = light;
        if (tile_x > 0) {
            self.setLightLevelAssert(tile_x - 1, tile_y, light - 1);
        }
        if (tile_y > 0) {
            self.setLightLevelAssert(tile_x, tile_y - 1, light - 1);
        }
        self.setLightLevel(tile_x + 1, tile_y, light - 1);
        self.setLightLevel(tile_x, tile_y + 1, light - 1);
    }
}

pub fn setLightLevel(self: *World, tile_x: usize, tile_y: usize, light: u4) void {
    if (self.tileExists(tile_x, tile_y)) {
        self.setLightLevelAssert(tile_x, tile_y, light);
    }
}

pub fn updateLightLevel(self: *World, tile_x: usize, tile_y: usize) void {
    if (!self.tileExists(tile_x, tile_y)) unreachable;
    var light: u4 = 0;

    const tile = self.getTileAssert(tile_x, tile_y);
    const above = self.getTile(tile_x, tile_y - 1);
    if (!tile.isOpaque() and above != null and above.?.sees_sky) {
        tile.sees_sky = true;
        light = 15;
    }

    const below = self.getTile(tile_x, tile_y + 1);
    if (below != null) {
        if (tile.sees_sky != !below.?.sees_sky) {
            self.updateLightLevel(tile_x, tile_y + 1);
        }
    }

    if (tile_x > 0) {
        light = @max(light, self.getTileAssert(tile_x - 1, tile_y).light);
    }
    if (tile_y > 0) {
        light = @max(light, self.getTileAssert(tile_x, tile_y - 1).light);
    }
    if (tile_x < self.tiles_width - 1) {
        light = @max(light, self.getTileAssert(tile_x + 1, tile_y).light);
    }
    if (tile_y < self.tiles_height - 1) {
        light = @max(light, self.getTileAssert(tile_x, tile_y + 1).light);
    }
    if (light > 0) {
        light -= 1;
    }
    self.setLightLevelAssert(tile_x, tile_y, light);
}

pub fn draw(self: World, camera: ray.Camera2D) void {
    const camera_bounds: ray.Rectangle = .{
        .x = camera.target.x - camera.offset.x,
        .y = camera.target.y - camera.offset.y,
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
