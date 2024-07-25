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

const TestSprite = struct {
    pos: rl.Vector2 = .{ .x = 0, .y = 0 },
    size: rl.Vector2 = .{ .x = 2, .y = 2 },
};

fn uiDraw(gs: *GameState) !void {
    var buf: [32]u8 = undefined;
    const text = try std.fmt.bufPrintZ(&buf, "FPS: {d}", .{1 / gs.dt});

    rl.drawText(text, 10, 10, 20, rl.Color.black);
}

fn drawSystem(gs: *GameState) !void {
    var ecs = &gs.ecs;
    var buf: [32]ECS.Entity = undefined;
    const res = try ecs.query(&buf, .{TestSprite});

    for (res) |entity| {
        const box = ecs.getComponent(TestSprite, entity).?;
        rl.drawRectangleV(box.pos, box.size, rl.Color.red);
    }
}

fn moveSystem(gs: *GameState) !void {
    var buf: [32]ECS.Entity = undefined;
    const res = try gs.ecs.query(&buf, .{TestSprite});

    for (res) |entity| {
        const box = gs.ecs.getComponent(TestSprite, entity).?;
        box.pos.x += 8.0 * gs.dt;
    }
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
    ecs.addSystem(&renderTilemaps, null);

    for (0..31) |i| {
        var box = TestSprite{};
        box.pos.y = @floatFromInt(4 * i);
        _ = try ecs.newEntity(.{box});
    }
    ecs.addSystem(&moveSystem, 0);
    ecs.addSystem(&drawSystem, 0);
    ecs.addSystem(&uiDraw, 1);

    try player.package(&ecs, &asset_server);

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

    rl.beginDrawing();

    rl.clearBackground(rl.Color.white);

    rl.beginMode2D(gs.camera.cam);
    // world draw
    try gs.ecs.update(gs, 0);

    rl.endMode2D();

    // ui draw
    try gs.ecs.update(gs, 1);

    rl.endDrawing();

    return false;
}
