const std = @import("std");

const ray = @import("raylib.zig");
const World = @import("World.zig");
const config = @import("Config.zig");

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

fn getPositionAxis(value: anytype, x_axis: bool) f32 {
    if (x_axis) {
        return value.x;
    }
    return value.y;
}

fn getPositionAxisPtr(value: anytype, x_axis: bool) *f32 {
    if (x_axis) {
        return &value.x;
    }
    return &value.y;
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
    const sign = std.math.sign;
    const mask: ray.Vector2 = if (x_axis) .{ .x = sign(self.speed.x), .y = 0 } else .{ .x = 0, .y = sign(self.speed.y) };

    const position = getPositionAxisPtr(&self.position, x_axis);
    const speed = getPositionAxis(self.speed, x_axis);
    position.* += speed;

    const clamp = std.math.clamp;
    const bbox = self.getBbox();

    const max_x: f32 = @floatFromInt(world.tiles_width);
    const max_y: f32 = @floatFromInt(world.tiles_height);
    const left: usize = @intFromFloat(clamp(@divFloor(bbox.x, config.tile_size), 0, max_x));
    const top: usize = @intFromFloat(clamp(@divFloor(bbox.y, config.tile_size), 0, max_y));
    const right: usize = @intFromFloat(clamp(@divFloor(bbox.x + bbox.width - 1, config.tile_size) + 2, 0, max_x));
    const bottom: usize = @intFromFloat(clamp(@divFloor(bbox.y + bbox.height - 1, config.tile_size) + 2, 0, max_y));

    var collided = false;
    for (top..bottom) |tile_y| {
        for (left..right) |tile_x| {
            const tile = world.getTileAssert(tile_x, tile_y);
            if (tile.empty) {
                continue;
            }

            const player_bbox = self.getBbox();
            const tile_bbox: ray.Rectangle = .{
                .x = @as(f32, @floatFromInt(tile_x)) * config.tile_size,
                .y = @as(f32, @floatFromInt(tile_y)) * config.tile_size,
                .width = config.tile_size,
                .height = config.tile_size,
            };
            const collision = ray.GetCollisionRec(player_bbox, tile_bbox);
            if (collision.width > 0 or collision.height > 0) {
                collided = true;
                const subtract = ray.Vector2Multiply(.{ .x = collision.width, .y = collision.height }, mask);
                self.position = ray.Vector2Subtract(self.position, subtract);
            }
        }
    }

    if (collided) {
        if (x_axis) {
            self.hitWall();
        } else {
            self.hitGroundOrCeiling();
        }
    }
}

fn move(self: *Player, world: World) void {
    self.on_ground = false;
    self.moveAndCollideAxis(world, true);
    self.moveAndCollideAxis(world, false);

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
