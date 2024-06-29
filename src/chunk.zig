const ray = @import("raylib.zig");
const Tile = @import("Tile.zig");
const config = @import("config.zig");

pub fn Chunk(comptime width: usize, comptime height: usize) type {
    return struct {
        const Self = @This();

        tile_map: [height][width]Tile,
        position: ray.Vector2,

        pub fn init(position: ray.Vector2) Self {
            var tile_map: [height][width]Tile = undefined;
            for (0..height) |y| {
                for (0..width) |x| {
                    const tile = &tile_map[y][x];
                    tile.* = .{ .empty = true };
                }
            }
            return .{ .tile_map = tile_map, .position = position };
        }

        pub fn getTileAssert(self: *Self, tile_x: usize, tile_y: usize) *Tile {
            return &self.tile_map[tile_y][tile_x];
        }

        pub fn getTile(self: *Self, tile_x: usize, tile_y: usize) ?*Tile {
            if (tile_x >= width or tile_y >= height) {
                return null;
            }
            return self.getTileAssert(tile_x, tile_y);
        }

        pub fn draw(self: Self) void {
            for (0..height) |y| {
                for (0..width) |x| {
                    const tile = self.tile_map[y][x];
                    const rectangle: ray.Rectangle = .{
                        .x = @as(f32, @floatFromInt(config.tile_size * x)) + self.position.x,
                        .y = @as(f32, @floatFromInt(config.tile_size * y)) + self.position.y,
                        .width = config.tile_size,
                        .height = config.tile_size,
                    };
                    tile.draw(rectangle);
                }
            }
        }
    };
}
