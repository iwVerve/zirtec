const World = @import("World.zig");

pub fn initializeSkyLight(world: *World) void {
    for (0..world.tiles_width) |tile_x| {
        for (0..world.tiles_height) |tile_y| {
            const tile = world.getTileAssert(tile_x, tile_y);
            if (tile.isOpaque()) {
                continue;
            }
            increaseSkyLight(world, tile_x, tile_y, 15);
        }
    }
}

pub fn updateSkyLight(world: *World, tile_x: usize, tile_y: usize) void {
    const tile = world.getTileAssert(tile_x, tile_y);
    const light: u4 = if (tile.isOpaque()) 0 else 15;
    setSkyLight(world, tile_x, tile_y, light);
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

const InfluenceArea = struct {
    from_x: usize,
    from_y: usize,
    to_x: usize,
    to_y: usize,
};

fn findInfluence(world: *World, tile_x: usize, tile_y: usize, area: *InfluenceArea, level: u4) void {
    const tile = world.getTile(tile_x, tile_y);
    if (tile == null or tile.?.sky_light > level) {
        return;
    }
    area.from_x = @min(area.from_x, tile_x);
    area.from_y = @min(area.from_y, tile_y);
    area.to_x = @max(area.to_x, tile_x);
    area.to_y = @max(area.to_y, tile_y);
    if (level == 0) {
        return;
    }
    if (tile_x > 0) {
        findInfluence(world, tile_x - 1, tile_y, area, level - 1);
    }
    findInfluence(world, tile_x + 1, tile_y, area, level - 1);
    if (tile_y > 0) {
        findInfluence(world, tile_x, tile_y - 1, area, level - 1);
    }
    findInfluence(world, tile_x, tile_y + 1, area, level - 1);
}

pub fn decreaseSkyLight(world: *World, tile_x: usize, tile_y: usize) void {
    const tile = world.getTileAssert(tile_x, tile_y);
    const old_level = tile.sky_light;

    var area: InfluenceArea = .{ .from_x = tile_x, .from_y = tile_y, .to_x = tile_x, .to_y = tile_y };
    findInfluence(world, tile_x, tile_y, &area, old_level);

    recalculateRegion(
        world,
        area.from_x,
        area.from_y,
        area.to_x,
        area.to_y,
    );
}

fn recalculateRegion(world: *World, from_x: usize, from_y: usize, to_x: usize, to_y: usize) void {
    for (from_y..to_y + 1) |tile_y| {
        for (from_x..to_x + 1) |tile_x| {
            const tile = world.getTileAssert(tile_x, tile_y);
            tile.sky_light = if (tile.isOpaque()) 0 else 15;
        }
    }
    var tally: u16 = 0;
    for (from_y - @min(from_y, 1)..@min(to_y + 2, world.tiles_height)) |tile_y| {
        for (from_x - @min(from_x, 1)..@min(to_x + 2, world.tiles_width)) |tile_x| {
            propagateLight(world, tile_x, tile_y);
            tally += 1;
        }
    }
}
