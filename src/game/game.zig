const std = @import("std");
const rl = @import("raylib");
const zigimg = @import("zigimg");
const w = @import("../window/window.zig");
const asset = @import("../asset/asset.zig");
const print = std.debug.print;
const renderTilemaps = @import("../2D/tilemap.zig").renderTilemaps;
const player = @import("player.zig");
const AssetServer = asset.AssetServer;
const Tilemap = @import("../2D/tilemap.zig").Tilemap;
const ECS = @import("../ecs/ECS.zig");
const GameState = @import("GameState.zig");
const Camera = @import("Camera.zig");

fn uiDraw(gs: *GameState) !void {
    var buf: [32]u8 = undefined;
    const text = try std.fmt.bufPrintZ(&buf, "FPS: {d}", .{1 / gs.dt});

    rl.drawText(text, 10, 10, 20, rl.Color.black);
}

pub fn setup(allocator: std.mem.Allocator) !GameState {
    var asset_server = AssetServer.init(allocator);

    var ecs = ECS.init(allocator);

    var tilemap = Tilemap.init(
        allocator,
        asset_server.registerImage("../resources/tilemaps/dungeon.png"),
        null,
    );
    try tilemap.loadLevel("../resources/levels/1");

    _ = try ecs.newEntity(.{tilemap});
    ecs.addSystem(&renderTilemaps, .s2);

    try player.package(&ecs, &asset_server);

    ecs.addSystem(&uiDraw, .s3);

    return GameState{
        .allocator = allocator,
        .asset_server = asset_server,
        .ecs = ecs,
        .camera = Camera.init(0, 0),
    };
}

pub fn deinit(gs: *GameState) void {
    var buf: [1]ECS.Entity = undefined;
    const res = gs.ecs.query(&buf, .{Tilemap}) catch unreachable;
    for (res) |entity| {
        var tilemap = gs.ecs.getComponent(Tilemap, entity).?;
        tilemap.deinit();
    }

    gs.ecs.deinit();
    gs.asset_server.deinit();
}

pub fn run(gs: *GameState) !bool {
    gs.dt = rl.getFrameTime();

    gs.camera.update(gs.dt);
    try gs.ecs.update(gs, .s1);

    rl.beginDrawing();

    rl.clearBackground(rl.Color.white);

    rl.beginMode2D(gs.camera.cam);
    // world draw
    try gs.ecs.update(gs, .s2);

    rl.endMode2D();

    // ui draw
    try gs.ecs.update(gs, .s3);

    rl.endDrawing();

    return false;
}
