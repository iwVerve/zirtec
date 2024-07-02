const std = @import("std");

const ray = @import("raylib.zig");
const World = @import("World.zig");
const Player = @import("Player.zig");
const config = @import("config.zig");
const util = @import("util.zig");
const asset = @import("asset.zig");
const lighting = @import("lighting.zig");

var world: World = undefined;
var camera: ray.Camera2D = undefined;
var player: Player = undefined;

fn updateCamera() void {
    camera.target = player.position;

    const left_edge: f32 = config.window_width / (2 * camera.zoom);
    const right_edge: f32 = @as(f32, @floatFromInt(world.tiles_width)) * config.tile_size - config.window_width / (2 * camera.zoom);
    const top_edge: f32 = config.window_height / (2 * camera.zoom);
    const bottom_edge: f32 = @as(f32, @floatFromInt(world.tiles_height)) * config.tile_size - config.window_height / (2 * camera.zoom);

    const clamp = std.math.clamp;
    camera.target.x = clamp(camera.target.x, left_edge, @max(left_edge, right_edge));
    camera.target.y = clamp(camera.target.y, top_edge, @max(top_edge, bottom_edge));
}

fn update() !void {
    const mouse_world_pos = util.screenSpaceToWorldSpace(.{ .x = @floatFromInt(ray.GetMouseX()), .y = @floatFromInt(ray.GetMouseY()) }, camera);
    const tile_coord = util.worldSpaceToTile(mouse_world_pos, world);

    if (tile_coord != null) {
        const tile = world.getTile(tile_coord.?.x, tile_coord.?.y);
        if (tile != null) {
            if (ray.IsMouseButtonDown(ray.MOUSE_BUTTON_LEFT)) {
                tile.?.type = .wood;
                lighting.updateSkyLight(&world, tile_coord.?.x, tile_coord.?.y);
            }
            if (ray.IsMouseButtonDown(ray.MOUSE_BUTTON_RIGHT)) {
                tile.?.type = .empty;
                lighting.updateSkyLight(&world, tile_coord.?.x, tile_coord.?.y);
            }
        }
    }

    player.update(world);
    updateCamera();

    try draw();
}

fn draw() !void {
    ray.BeginDrawing();
    defer ray.EndDrawing();

    ray.ClearBackground(ray.BLUE);

    ray.BeginMode2D(camera);
    player.draw();
    world.draw(camera);
    ray.EndMode2D();
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    world = try World.init(allocator, .{});
    defer world.deinit();

    player = .{ .position = .{ .x = 64, .y = 64 } };

    const zoom = 2;
    camera = .{
        .target = .{ .x = 0, .y = 0 },
        .offset = .{ .x = config.window_width / 2, .y = config.window_height / 2 },
        .zoom = zoom,
        .rotation = 0,
    };

    ray.InitWindow(config.window_width, config.window_height, "hello, raylib!");
    defer ray.CloseWindow();
    ray.SetTargetFPS(60);

    asset.load();
    defer asset.unload();

    while (!ray.WindowShouldClose()) {
        try update();
    }
}
