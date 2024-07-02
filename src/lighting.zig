const World = @import("World.zig");

pub fn initializeSkyLight(world: *World) void {
    for (0..world.tiles_width) |tile_x| {
        for (0..world.tiles_height) |tile_y| {
            const tile = world.getTileAssert(tile_x, tile_y);
            if (tile.isOpaque()) {
                break;
            }
            increaseSkyLight(world, tile_x, tile_y, 15);
            tile.sees_sky = true;
        }
    }
}

pub fn updateSkyLight(world: *World, tile_x: usize, tile_y: usize) void {
    var light: u4 = 0;

    const tile = world.getTileAssert(tile_x, tile_y);
    const above = world.getTile(tile_x, tile_y - 1);
    if (tile.isOpaque()) {
        tile.sees_sky = false;
    } else {
        if (above == null) {
            tile.sees_sky = true;
        } else {
            tile.sees_sky = above.?.sees_sky;
        }
    }
    if (tile.sees_sky) {
        light = 15;
    }
    setSkyLight(world, tile_x, tile_y, light);

    const below = world.getTile(tile_x, tile_y + 1);
    if (below != null) {
        if (tile.sees_sky != below.?.sees_sky) {
            updateSkyLight(world, tile_x, tile_y + 1);
        }
    }
}

fn setSkyLight(world: *World, tile_x: usize, tile_y: usize, light: u4) void {
    const tile = world.getTileAssert(tile_x, tile_y);
    if (light > tile.sky_light) {
        increaseSkyLight(world, tile_x, tile_y, light);
    } else if (light < tile.sky_light) {
        decreaseSkyLight(world, tile_x, tile_y);
    }
}

fn propagateLight(world: *World, tile_x: usize, tile_y: usize) void {
    const tile = world.getTileAssert(tile_x, tile_y);
    const level = tile.sky_light;
    if (level == 0) {
        return;
    }
    if (tile_x > 0) {
        increaseSkyLight(world, tile_x - 1, tile_y, level - 1);
    }
    if (tile_y > 0) {
        increaseSkyLight(world, tile_x, tile_y - 1, level - 1);
    }
    if (tile_x < world.tiles_width - 1) {
        increaseSkyLight(world, tile_x + 1, tile_y, level - 1);
    }
    if (tile_y < world.tiles_height - 1) {
        increaseSkyLight(world, tile_x, tile_y + 1, level - 1);
    }
}

pub fn increaseSkyLight(world: *World, tile_x: usize, tile_y: usize, level: u4) void {
    const tile = world.getTileAssert(tile_x, tile_y);
    if (tile.sky_light >= level) {
        return;
    }
    tile.sky_light = level;
    propagateLight(world, tile_x, tile_y);
}

pub fn decreaseSkyLight(world: *World, tile_x: usize, tile_y: usize) void {
    const tile = world.getTileAssert(tile_x, tile_y);
    const old_level = tile.sky_light;
    recalculateRegion(
        world,
        tile_x - @min(tile_x, old_level),
        tile_y - @min(tile_y, old_level),
        @min(tile_x + old_level, world.tiles_width),
        @min(tile_y + old_level, world.tiles_height),
    );
}

fn recalculateRegion(world: *World, from_x: usize, from_y: usize, to_x: usize, to_y: usize) void {
    for (from_y..to_y + 1) |tile_y| {
        for (from_x..to_x + 1) |tile_x| {
            const tile = world.getTileAssert(tile_x, tile_y);
            tile.sky_light = if (tile.sees_sky) 15 else 0;
        }
    }
    for (from_y - @min(from_y, 1)..to_y + 2) |tile_y| {
        for (from_x - @min(from_x, 1)..to_x + 2) |tile_x| {
            propagateLight(world, tile_x, tile_y);
        }
    }
}
