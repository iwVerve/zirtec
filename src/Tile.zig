const ray = @import("raylib.zig");

const Tile = @This();

empty: bool,

pub fn draw(self: Tile, rectangle: ray.Rectangle) void {
    if (!self.empty) {
        ray.DrawRectangleRec(rectangle, ray.MAGENTA);
    }
}
