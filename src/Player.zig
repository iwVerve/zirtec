const std = @import("std");

const ray = @import("raylib.zig");
const World = @import("World.zig");
const config = @import("Config.zig");
const Chunk = @import("chunk.zig").Chunk(config.chunk_size, config.chunk_size);

const Player = @This();

const acceleration = 0.3;
const deceleration = 0.6;
const max_run_speed = 3;
const jump_speed = 5;
const max_fall_speed = 12;

position: ray.Vector2,
speed: ray.Vector2 = .{ .x = 0, .y = 0 },
gravity: ray.Vector2 = .{ .x = 0, .y = 0.2 },
on_ground: bool = false,

size: ray.Vector2 = .{ .x = 14, .y = 20 },
origin: ray.Vector2 = .{ .x = 7, .y = 10 },

fn getRelativeBbox(self: Player) ray.Rectangle {
    return .{
        .x = -self.origin.x,
        .y = -self.origin.y,
        .width = self.size.x,
        .height = self.size.y,
    };
}

fn getBbox(self: Player) ray.Rectangle {
    var bbox = self.getRelativeBbox();
    bbox.x += self.position.x;
    bbox.y += self.position.y;
    return bbox;
}

fn hitWall(self: *Player) void {
    self.speed.x = 0;
}

fn hitGroundOrCeiling(self: *Player) void {
    if (self.speed.y > 0) {
        self.on_ground = true;
    }
    self.speed.y = 0;
}

fn collideWithChunk(self: *Player, chunk: *Chunk, dir_x: f32, dir_y: f32, callback: ?fn (*Player) void) void {
    var collided = false;

    var bbox = self.getBbox();
    bbox.x -= chunk.position.x;
    bbox.y -= chunk.position.y;
    const clamp = std.math.clamp;
    const left_index: usize = @intFromFloat(clamp(@divFloor(bbox.x, config.tile_size) - 1, 0, config.chunk_size - 1));
    const top_index: usize = @intFromFloat(clamp(@divFloor(bbox.y, config.tile_size) - 1, 0, config.chunk_size - 1));
    const right_index: usize = @intFromFloat(clamp(@divFloor(bbox.x + bbox.width - 1, config.tile_size) + 2, 0, config.chunk_size));
    const bottom_index: usize = @intFromFloat(clamp(@divFloor(bbox.y + bbox.height - 1, config.tile_size) + 2, 0, config.chunk_size));

    for (top_index..bottom_index) |tile_y| {
        for (left_index..right_index) |tile_x| {
            const tile = chunk.getTileAssert(tile_x, tile_y);
            if (tile.empty) {
                continue;
            }
            const player_bbox = self.getBbox();
            const tile_bbox: ray.Rectangle = .{
                .x = chunk.position.x + @as(f32, @floatFromInt(tile_x)) * config.tile_size,
                .y = chunk.position.y + @as(f32, @floatFromInt(tile_y)) * config.tile_size,
                .width = config.tile_size,
                .height = config.tile_size,
            };
            const collision = ray.GetCollisionRec(player_bbox, tile_bbox);
            if (collision.width != 0 and collision.height != 0) {
                self.position.x -= dir_x * collision.width;
                self.position.y -= dir_y * collision.height;
                collided = true;
            }
        }
    }
    if (collided and callback != null) {
        callback.?(self);
    }
}

fn getPositionAxis(value: anytype, x_axis: bool) f32 {
    if (x_axis) {
        return value.x;
    }
    return value.y;
}

fn getSizeAxis(value: anytype, x_axis: bool) f32 {
    if (x_axis) {
        return value.width;
    }
    return value.height;
}

fn getPositionAxisPtr(value: anytype, x_axis: bool) *f32 {
    if (x_axis) {
        return &value.x;
    }
    return &value.y;
}

fn moveAxis(self: *Player, world: World, comptime x_axis: bool) void {
    const position = getPositionAxisPtr(&self.position, x_axis);
    const speed = getPositionAxis(self.speed, x_axis);
    position.* += speed;

    const sign = std.math.sign(speed);
    const moving_positive = (sign == 1);
    const bbox = self.getBbox();
    const bbox_pos = getPositionAxis(bbox, x_axis);
    const bbox_other_pos = getPositionAxis(bbox, !x_axis);
    const bbox_size = getSizeAxis(bbox, x_axis);
    const bbox_other_size = getSizeAxis(bbox, !x_axis);

    const chunk_pixels: f32 = @floatFromInt(config.chunk_size * config.tile_size);
    const first_chunk_index: isize = @intFromFloat(bbox_other_pos / chunk_pixels);
    const second_chunk_index: isize = @intFromFloat((bbox_other_pos + bbox_other_size) / chunk_pixels);
    const primary_index: isize = @intFromFloat((bbox_pos + @as(f32, @floatFromInt(@intFromBool(moving_positive))) * bbox_size) / chunk_pixels);

    if (x_axis) {
        const top_chunk = world.getChunk(primary_index, first_chunk_index) orelse return;
        self.collideWithChunk(top_chunk, sign, 0, hitWall);
    } else {
        const left_chunk = world.getChunk(first_chunk_index, primary_index) orelse return;
        self.collideWithChunk(left_chunk, 0, sign, hitGroundOrCeiling);
    }

    if (second_chunk_index != first_chunk_index) {
        if (x_axis) {
            const bottom_chunk = world.getChunk(primary_index, second_chunk_index) orelse return;
            self.collideWithChunk(bottom_chunk, sign, 0, hitWall);
        } else {
            const right_chunk = world.getChunk(second_chunk_index, primary_index) orelse return;
            self.collideWithChunk(right_chunk, 0, sign, hitGroundOrCeiling);
        }
    }
}

fn inRange(value: anytype, from: anytype, to: anytype) bool {
    return value >= from and value <= to;
}

fn stayInsideWorld(self: *Player, world: World) void {
    const min_x: f32 = self.size.x - self.origin.x;
    const min_y: f32 = self.size.y - self.origin.y;
    const max_x: f32 = @as(f32, @floatFromInt(world.tiles_width * config.tile_size)) - self.size.x + self.origin.x;
    const max_y: f32 = @as(f32, @floatFromInt(world.tiles_height * config.tile_size)) - self.size.y + self.origin.y;

    const clamp = std.math.clamp;
    if (!inRange(self.position.x, min_x, max_x)) {
        hitWall(self);
        self.position.x = clamp(self.position.x, min_x, max_x);
    }
    if (!inRange(self.position.y, min_y, max_y)) {
        hitGroundOrCeiling(self);
        self.position.y = clamp(self.position.y, min_y, max_y);
    }
}

fn moveAndCollideAxis(self: *Player, world: World, comptime x_axis: bool) void {
    _ = world;
    const mask: ray.Vector2 = if (x_axis) .{ .x = 1, .y = 0 } else .{ .x = 0, .y = 1 };
    _ = mask;

    const position = getPositionAxisPtr(self.position, x_axis);
    const speed = getPositionAxis(self.speed, x_axis);
    position.* += speed;
}

fn move(self: *Player, world: World) void {
    self.on_ground = false;
    self.moveAxis(world, true);
    self.moveAxis(world, false);

    // self.moveAndCollideAxis(world, true);
    // self.moveAndCollideAxis(world, false);

    self.stayInsideWorld(world);
}

pub fn update(self: *Player, world: World) void {
    const h_input: f32 = @floatFromInt(@as(i8, @intCast(@intFromBool(ray.IsKeyDown(ray.KEY_RIGHT)))) - @as(i8, @intCast(@intFromBool(ray.IsKeyDown(ray.KEY_LEFT)))));
    const sign = std.math.sign(self.speed.x);
    if (h_input == sign or sign == 0) {
        self.speed.x += acceleration * h_input;
        self.speed.x = std.math.sign(self.speed.x) * @min(@abs(self.speed.x), max_run_speed);
    } else if (self.speed.x != 0) {
        self.speed.x += -sign * @min(@abs(self.speed.x), deceleration);
    }

    if (ray.IsKeyPressed(ray.KEY_SPACE) and self.on_ground) {
        self.speed.y = -jump_speed;
    }
    if (ray.IsKeyReleased(ray.KEY_SPACE)) {
        if (self.speed.y < 0) {
            self.speed.y *= 0.5;
        }
    }

    self.speed = ray.Vector2Add(self.speed, self.gravity);
    self.speed.y = @min(self.speed.y, max_fall_speed);
    self.move(world);
}

pub fn draw(self: Player) void {
    const bbox = self.getBbox();
    ray.DrawRectangleRec(bbox, ray.RED);
}
