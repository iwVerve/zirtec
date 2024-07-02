const ray = @import("raylib.zig");
const asset = @import("asset.zig");
const World = @import("World.zig");

const Tile = @This();

const BlockType = enum {
    empty,
    dirt,
    stone,
    wood,
};

const WallType = enum {
    empty,
    stone,
};

block: BlockType = .empty,
wall: WallType = .empty,
sky_light: u4 = 0,

pub fn isSolid(self: Tile) bool {
    return switch (self.block) {
        .empty => false,
        .stone, .dirt, .wood => true,
    };
}

pub fn isOpaque(self: Tile) bool {
    return self.isSolid() or self.wall != .empty;
}

fn getBlockTexture(block: BlockType) ?ray.Texture2D {
    return switch (block) {
        .empty => null,
        .dirt => asset.blocks.dirt,
        .stone => asset.blocks.stone,
        .wood => asset.blocks.wood,
    };
}

fn getWallTexture(wall: WallType) ?ray.Texture2D {
    return switch (wall) {
        .empty => null,
        .stone => asset.walls.stone,
    };
}

pub fn draw(self: Tile, rectangle: ray.Rectangle, comptime options: World.DrawOptions) void {
    if (options.walls) {
        const wall_texture = getWallTexture(self.wall);
        if (wall_texture != null) {
            ray.DrawTexture(wall_texture.?, @intFromFloat(rectangle.x), @intFromFloat(rectangle.y), ray.WHITE);
        }
    }

    if (options.blocks) {
        const block_texture = getBlockTexture(self.block);
        if (block_texture != null) {
            ray.DrawTexture(block_texture.?, @intFromFloat(rectangle.x), @intFromFloat(rectangle.y), ray.WHITE);
        }
    }

    if (options.lighting) {
        const darkness_alpha = 17 * @as(u8, @intCast(15 - self.sky_light));
        ray.DrawRectangleRec(rectangle, .{ .r = 0, .g = 0, .b = 0, .a = darkness_alpha });
    }
}
