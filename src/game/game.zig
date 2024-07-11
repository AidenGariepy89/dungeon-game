const std = @import("std");
const rl = @import("raylib");

const w = @import("../window/window.zig");

const WORLD_TILE_WIDTH: usize = 16;
const WORLD_TILE_SIZE = WORLD_TILE_WIDTH * WORLD_TILE_WIDTH;
const Tile = struct {
    pos: rl.Vector2,
    size: f32,
    color: rl.Color,

    fn draw(self: Tile) void {
        const rect = rl.Rectangle{
            .x = self.pos.x,
            .y = self.pos.y,
            .width = self.size,
            .height = self.size,
        };

        rl.drawRectangleRec(rect, self.color);
    }
};

pub const GS = struct {
    cam: rl.Camera2D,
    camSpeed: f32,
    dt: f32,
    tiles: [WORLD_TILE_SIZE]Tile,
};

pub fn setup() GS {
    const cam = rl.Camera2D{
        .rotation = 0,
        .zoom = 1,
        .offset = .{ .x = @floatFromInt(w.wh()), .y = @floatFromInt(w.hh()) },
        .target = .{ .x = 0, .y = 0 },
    };

    var tiles: [WORLD_TILE_SIZE]Tile = undefined;
    const size: f32 = 16;

    for (0..WORLD_TILE_SIZE) |i| {
        const color = if (i % 2 == 0) rl.Color.light_gray else rl.Color.dark_gray;
        const pos = rl.Vector2{
            .x = @as(f32, @floatFromInt(i % WORLD_TILE_WIDTH)) * size,
            .y = @as(f32, @floatFromInt(i / WORLD_TILE_WIDTH)) * size,
        };
        tiles[i] = Tile{
            .color = color,
            .size = size,
            .pos = pos,
        };
    }

    return GS{
        .cam = cam,
        .camSpeed = 200,
        .dt = 0,
        .tiles = tiles,
    };
}

pub fn run(gs: *GS) !bool {
    gs.dt = rl.getFrameTime();

    camMove(gs);

    // center cam
    if (rl.isWindowResized()) {
        gs.cam.offset.x = @floatFromInt(w.wh());
        gs.cam.offset.y = @floatFromInt(w.hh());
    }

    rl.beginDrawing();

    rl.clearBackground(rl.Color.white);

    rl.beginMode2D(gs.cam);
    worldDraw(gs);
    rl.endMode2D();

    uiDraw(gs);

    rl.endDrawing();

    return false;
}

fn worldDraw(gs: *GS) void {
    for (&gs.tiles) |*tile| {
        tile.draw();
    }

    rl.drawRectangle(0, 0, 2, 2, rl.Color.black);
}

fn uiDraw(gs: *GS) void {
    _ = gs;
}

fn camMove(gs: *GS) void {
    var dir = rl.Vector2.zero();

    if (rl.isKeyDown(.key_l) or rl.isKeyDown(.key_right)) {
        dir.x += 1;
    }
    if (rl.isKeyDown(.key_h) or rl.isKeyDown(.key_left)) {
        dir.x -= 1;
    }
    if (rl.isKeyDown(.key_j) or rl.isKeyDown(.key_down)) {
        dir.y += 1;
    }
    if (rl.isKeyDown(.key_k) or rl.isKeyDown(.key_up)) {
        dir.y -= 1;
    }

    var vel: rl.Vector2 = rl.Vector2.zero();
    if (dir.equals(vel) != 1) {
        vel = dir.normalize().scale(gs.camSpeed);
    }   

    gs.cam.target = gs.cam.target.add(vel.scale(gs.dt));
}
