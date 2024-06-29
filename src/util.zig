const std = @import("std");

const ray = @import("raylib.zig");
const World = @import("World.zig");
const config = @import("config.zig");

pub const UVector2 = struct {
    x: usize,
    y: usize,

    pub fn fromVector2(vec: ray.Vector2) ?UVector2 {
        if (vec.x < 0 or vec.x > std.math.maxInt(usize)) {
            return null;
        }
        if (vec.y < 0 or vec.y > std.math.maxInt(usize)) {
            return null;
        }
        return .{
            .x = @intFromFloat(vec.x),
            .y = @intFromFloat(vec.y),
        };
    }
};

pub fn screenSpaceToWorldSpace(position: ray.Vector2, camera: ray.Camera2D) ray.Vector2 {
    // const scaled_offset = ray.Vector2Multiply(camera.offset, .{ .x = camera.zoom, .y = camera.zoom });
    const scaled_offset = camera.offset;
    const add = ray.Vector2Subtract(camera.target, scaled_offset);
    return ray.Vector2Add(position, add);
}

pub fn worldSpaceToTile(position: ray.Vector2, world: World) ?UVector2 {
    const world_width_px: f32 = @floatFromInt(config.tile_size * world.tiles_width);
    const world_height_px: f32 = @floatFromInt(config.tile_size * world.tiles_height);

    if (position.x >= world_width_px or position.y >= world_height_px) {
        return null;
    }
    const tile_coord = ray.Vector2Divide(position, .{ .x = config.tile_size, .y = config.tile_size });
    return UVector2.fromVector2(tile_coord);
}
