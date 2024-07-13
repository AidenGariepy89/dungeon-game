const std = @import("std");
const rl = @import("raylib");
const zigimg = @import("zigimg");

const w = @import("../window/window.zig");
const asset = @import("../asset/asset.zig");

const Tilemap = @import("../2D/tilemap.zig").Tilemap;
const AssetServer = asset.AssetServer;

pub const GS = struct {
    alloc: std.mem.Allocator,
    assets: AssetServer,
    cam: rl.Camera2D,
    camSpeed: f32,
    dt: f32,
    tilemap: Tilemap(8),
};

pub fn setup(alloc: std.mem.Allocator) !GS {
    const cam = rl.Camera2D{
        .rotation = 0,
        .zoom = 12,
        .offset = .{ .x = @floatFromInt(w.wh()), .y = @floatFromInt(w.hh()) },
        .target = .{ .x = 0, .y = 0 },
    };

    var assetServer = AssetServer.init(alloc);

    var tilemap = Tilemap(8).init(
        alloc,
        rl.Vector2.zero(),
        14,
        assetServer.registerImage("../resources/tilemaps/dungeon.png"),
        &assetServer,
    );

    tilemap.loadLevel("../resources/levels/1");

    return GS{
        .alloc = alloc,
        .assets = assetServer,
        .cam = cam,
        .camSpeed = 200,
        .dt = 0,
        .tilemap = tilemap,
    };
}

pub fn deinit(gs: *GS) void {
    gs.tilemap.deinit();
    gs.assets.deinit();
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
    gs.tilemap.draw();
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
