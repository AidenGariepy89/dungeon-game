const std = @import("std");
const rl = @import("raylib");
const zigimg = @import("zigimg");

const w = @import("../window/window.zig");
const tm = @import("tilemap.zig");
const asset = @import("../asset/asset.zig");

pub const GS = struct {
    alloc: std.mem.Allocator,
    assets: asset.AssetServer,
    cam: rl.Camera2D,
    camSpeed: f32,
    dt: f32,
    // tiles: []const tm.Tile,
    // tilemap: rl.Texture2D,
    tilemapAsset: asset.Asset,
    textureTest: rl.Texture2D,
    png: zigimg.Image,
};

pub fn setup(alloc: std.mem.Allocator) !GS {
    const cam = rl.Camera2D{
        .rotation = 0,
        .zoom = 12,
        .offset = .{ .x = @floatFromInt(w.wh()), .y = @floatFromInt(w.hh()) },
        .target = .{ .x = 0, .y = 0 },
    };

    // const rawTiles = tm.loadTilemap();
    // const tiles: []const tm.Tile = rawTiles.*[0..];
    //
    // const path = "./src/resources/tilemaps/dungeon.png";
    //
    // const tilemap = try tm.openTexture(path);

    var assetServer = asset.AssetServer.init(alloc);
    const handle = try assetServer.registerAsset("../resources/tilemaps/dungeon.png");
    const png: zigimg.Image = try assetServer.openPng(handle);
    const img = rl.Image{
        .width = @intCast(png.width),
        .height = @intCast(png.height),
        .mipmaps = 1,
        .format = .pixelformat_uncompressed_r8g8b8a8,
        .data = @constCast(png.rawBytes().ptr),
    };
    const texture = rl.loadTextureFromImage(img);

    return GS{
        .alloc = alloc,
        .assets = assetServer,
        .cam = cam,
        .camSpeed = 200,
        .dt = 0,
        // .tiles = tiles,
        // .tilemap = tilemap,
        .tilemapAsset = handle,
        .textureTest = texture,
        .png = png,
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

pub fn deinit(gs: *GS) void {
    // gs.tilemap.unload();
    gs.textureTest.unload();
    gs.png.deinit();
    gs.assets.deinit();
}

fn worldDraw(gs: *GS) void {
    // for (gs.tiles) |tile| {
    //     tile.draw(&gs.tilemap);
    // }

    rl.drawRectangle(0, 0, 1, 1, rl.Color.black);

    // gs.tilemap.draw(0, -20, rl.Color.white);
    gs.textureTest.draw(0, -30, rl.Color.white);
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
