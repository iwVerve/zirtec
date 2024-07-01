const ray = @import("raylib.zig");

pub var stone: ray.Texture2D = undefined;
pub var dirt: ray.Texture2D = undefined;
pub var wood: ray.Texture2D = undefined;

pub fn load() void {
    stone = ray.LoadTexture("asset/sprite/stone.png");
    dirt = ray.LoadTexture("asset/sprite/dirt.png");
    wood = ray.LoadTexture("asset/sprite/wood.png");
}

pub fn unload() void {
    ray.UnloadTexture(stone);
    ray.UnloadTexture(dirt);
    ray.UnloadTexture(wood);
}
