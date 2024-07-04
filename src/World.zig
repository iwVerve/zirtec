const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const ray = @import("raylib.zig");
const znoise = @import("znoise");
const Tile = @import("Tile.zig");
const config = @import("config.zig");
const lighting = @import("lighting.zig");

const World = @This();

allocator: Allocator,

tile_map: ArrayList(ArrayList(Tile)),
tiles_width: usize,
tiles_height: usize,

time: u32 = 0,

const WorldOptions = struct {
    tile_width: usize = 2048,
    tile_height: usize = 256,
    seed: i32 = 0,
};

fn generate(world: *World, options: WorldOptions) void {
    const gen = znoise.FnlGenerator{
        .seed = options.seed,
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
                tile.block = .dirt;
                dirt_blocks -= 1;
            } else {
                tile.block = .stone;
                tile.wall = .stone;
            }
        }
    }
}

pub fn init(allocator: Allocator, options: WorldOptions) !World {
    var tile_map = ArrayList(ArrayList(Tile)).init(allocator);
    for (0..options.tile_height) |_| {
        var tile_row = ArrayList(Tile).init(allocator);
        for (0..options.tile_width) |_| {
            const tile: Tile = .{};
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
    lighting.initializeSkyLight(&world);

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

pub const DrawOptions = struct {
    walls: bool = false,
    blocks: bool = false,
    lighting: bool = false,
};

pub fn findPlayerSpawn(self: World) ray.Vector2 {
    const left = @divFloor(self.tiles_width, 2);
    const right = left + 1;
    const spawn_x: f32 = @as(f32, @floatFromInt(config.tile_size)) * (@as(f32, @floatFromInt(left)) + @as(f32, @floatFromInt(right + 1))) / 2;
    for (0..self.tiles_height) |tile_y| {
        for (left..right + 1) |tile_x| {
            const tile = self.getTileAssert(tile_x, tile_y);
            if (tile.block != .empty) {
                return .{
                    .x = spawn_x,
                    .y = @floatFromInt(config.tile_size * tile_y),
                };
            }
        }
    }
    return .{
        .x = spawn_x,
        .y = @floatFromInt(self.tiles_height * config.tile_size),
    };
}

pub fn update(self: *World) void {
    self.time += 1;
    if (self.time >= 3600) {
        self.time = 0;
    }
}

pub fn draw(self: World, camera: ray.Camera2D, comptime options: DrawOptions) void {
    const math = std.math;
    const cos = @cos(2 * math.pi * @as(f32, @floatFromInt(self.time)) / 3600);
    const squared = math.sign(cos) * math.pow(f32, @abs(cos), 0.75);
    const daylight_ratio: f32 = squared / 2 + 0.5;
    const daylight_level: u4 = @intFromFloat(math.lerp(0, 15, math.clamp(daylight_ratio, 0, 1)));

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
            tile.draw(rectangle, options, daylight_level);
        }
    }
}

pub fn drawSmoothLighting(self: World, camera: ray.Camera2D) void {
    self.draw(camera, .{ .lighting = true });
    // const camera_bounds: ray.Rectangle = .{
    //     .x = camera.target.x - camera.offset.x,
    //     .y = camera.target.y - camera.offset.y,
    //     .width = config.window_width,
    //     .height = config.window_height,
    // };
    //
    // const clamp = std.math.clamp;
    //
    // const left_index: usize = @intFromFloat(clamp(@divFloor(camera_bounds.x, config.tile_size), 0, @as(f32, @floatFromInt(self.tiles_width))));
    // const top_index: usize = @intFromFloat(clamp(@divFloor(camera_bounds.y, config.tile_size), 0, @as(f32, @floatFromInt(self.tiles_height))));
    // const right_index: usize = @intFromFloat(clamp(@divFloor(camera_bounds.x + camera_bounds.width - 1, config.tile_size) + 1, 0, @as(f32, @floatFromInt(self.tiles_width))));
    // const bottom_index: usize = @intFromFloat(clamp(@divFloor(camera_bounds.y + camera_bounds.height - 1, config.tile_size) + 1, 0, @as(f32, @floatFromInt(self.tiles_height))));
}
