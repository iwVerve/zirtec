const ray = @import("raylib.zig");

const Blocks = struct {
    stone: ray.Texture2D = undefined,
    dirt: ray.Texture2D = undefined,
    wood: ray.Texture2D = undefined,
};

const Walls = struct {
    stone: ray.Texture2D = undefined,
};

pub var blocks: Blocks = .{};
pub var walls: Walls = .{};

pub fn load() void {
    blocks.stone = ray.LoadTexture("asset/sprite/stone.png");
    blocks.dirt = ray.LoadTexture("asset/sprite/dirt.png");
    blocks.wood = ray.LoadTexture("asset/sprite/wood.png");
    walls.stone = ray.LoadTexture("asset/sprite/stone_wall.png");
}

pub fn unload() void {
    ray.UnloadTexture(blocks.stone);
    ray.UnloadTexture(blocks.dirt);
    ray.UnloadTexture(blocks.wood);
    ray.UnloadTexture(walls.stone);
}
