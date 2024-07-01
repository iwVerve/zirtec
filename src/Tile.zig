const ray = @import("raylib.zig");
const asset = @import("asset.zig");

const Tile = @This();

const TileType = enum {
    empty,
    dirt,
    stone,
    wood,
};

type: TileType,
light: u4 = 0,
sees_sky: bool = false,

pub fn isSolid(self: Tile) bool {
    return switch (self.type) {
        .empty => false,
        .stone, .dirt, .wood => true,
    };
}

pub fn isOpaque(self: Tile) bool {
    return self.isSolid();
}

pub fn draw(self: Tile, rectangle: ray.Rectangle) void {
    const texture: ?ray.Texture2D = switch (self.type) {
        .empty => null,
        .dirt => asset.dirt,
        .stone => asset.stone,
        .wood => asset.wood,
    };
    if (texture != null) {
        ray.DrawTexture(texture.?, @intFromFloat(rectangle.x), @intFromFloat(rectangle.y), ray.WHITE);
    }
    const darkness_alpha = 17 * @as(u8, @intCast(15 - self.light));
    ray.DrawRectangleRec(rectangle, .{ .r = 0, .g = 0, .b = 0, .a = darkness_alpha });
}
