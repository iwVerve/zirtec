const ray = @import("raylib.zig");
const Texture2D = ray.Texture2D;

const Blocks = struct {
    stone: Texture2D = undefined,
    dirt: Texture2D = undefined,
    wood: Texture2D = undefined,
    platform: Texture2D = undefined,
};

const Walls = struct {
    stone: Texture2D = undefined,
    wood: Texture2D = undefined,
};

pub var blocks: Blocks = .{};
pub var walls: Walls = .{};

pub fn load() void {
    blocks.stone = ray.LoadTexture("asset/sprite/stone.png");
    blocks.dirt = ray.LoadTexture("asset/sprite/dirt.png");
    blocks.wood = ray.LoadTexture("asset/sprite/wood.png");
    blocks.platform = ray.LoadTexture("asset/sprite/platform.png");
    walls.stone = ray.LoadTexture("asset/sprite/stone_wall.png");
    walls.wood = ray.LoadTexture("asset/sprite/wood_wall.png");
}

pub fn unload() void {
    ray.UnloadTexture(blocks.stone);
    ray.UnloadTexture(blocks.dirt);
    ray.UnloadTexture(blocks.wood);
    ray.UnloadTexture(blocks.platform);
    ray.UnloadTexture(walls.stone);
    ray.UnloadTexture(walls.wood);
}
