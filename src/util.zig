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
    const position_from_offset = ray.Vector2Subtract(position, camera.offset);
    const scaled_position = ray.Vector2Divide(position_from_offset, .{ .x = camera.zoom, .y = camera.zoom });
    return ray.Vector2Add(camera.target, scaled_position);
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
