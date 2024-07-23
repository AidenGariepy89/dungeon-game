const std = @import("std");
const rl = @import("raylib");
const zigimg = @import("zigimg");
const w = @import("../window/window.zig");
const asset = @import("../asset/asset.zig");
const print = std.debug.print;
const renderTilemaps = @import("../2D/tilemap.zig").renderTilemaps;
const Tilemap = @import("../2D/tilemap.zig").Tilemap;
const AssetServer = asset.AssetServer;
const Player = @import("../actors/player.zig").Player;
const Node = @import("../2D/node.zig").Node;
const ECS = @import("../ecs/ECS.zig");
const Renderer = @import("../2D/Renderer.zig");
const GameState = @import("GameState.zig");

const TestSprite = struct {
    pos: rl.Vector2 = .{ .x = 0, .y = 0 },
    size: rl.Vector2 = .{ .x = 2, .y = 2 },
};

fn drawSystem(gs: *GameState) !void {
    var ecs = &gs.ecs;
    var buf: [32]ECS.Entity = undefined;
    const res = try ecs.query(TestSprite, &buf);

    for (res) |entity| {
        const box = ecs.getComponent(TestSprite, entity).?;
        rl.drawRectangleV(box.pos, box.size, rl.Color.red);
    }
}

fn moveSystem(gs: *GameState) !void {
    var buf: [32]ECS.Entity = undefined;
    const res = try gs.ecs.query(TestSprite, &buf);

    for (res) |entity| {
        const box = gs.ecs.getComponent(TestSprite, entity).?;
        box.pos.x += 8.0 * gs.dt;
    }
}

pub fn setup(allocator: std.mem.Allocator) !GameState {
    const cam = rl.Camera2D{
        .rotation = 0,
        .zoom = 12,
        .offset = .{ .x = @floatFromInt(w.wh()), .y = @floatFromInt(w.hh()) },
        .target = .{ .x = 0, .y = 0 },
    };

    var asset_server = AssetServer.init(allocator);

    var ecs = ECS.init(allocator);

    var tilemap = Tilemap.init(
        allocator,
        asset_server.registerImage("../resources/tilemaps/dungeon.png"),
        null,
    );
    try tilemap.loadLevel("../resources/levels/1");

    _ = try ecs.newEntity(.{tilemap});
    ecs.addSystem(&renderTilemaps);

    for (0..31) |i| {
        var box = TestSprite{};
        box.pos.y = @floatFromInt(4 * i);
        _ = try ecs.newEntity(.{box});
    }
    ecs.addSystem(&moveSystem);
    ecs.addSystem(&drawSystem);

    return GameState{
        .allocator = allocator,
        .asset_server = asset_server,
        .ecs = ecs,

        .cam = cam,
        .camSpeed = 200,
        // .assets = assetServer,
        // .tilemap = tilemap,
        // .player = player,
        // .nodes = nodes,
    };
}

pub fn deinit(gs: *GameState) void {
    var buf: [1]ECS.Entity = undefined;
    const res = gs.ecs.query(Tilemap, &buf) catch unreachable;
    for (res) |entity| {
        var tilemap = gs.ecs.getComponent(Tilemap, entity).?;
        tilemap.deinit();
    }

    gs.ecs.deinit();
    gs.asset_server.deinit();
}

pub fn run(gs: *GameState) !bool {
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
    // worldDraw(gs);
    try gs.ecs.update(gs);

    rl.endMode2D();

    uiDraw(gs);

    rl.endDrawing();

    return false;
}

fn worldDraw(gs: *GameState) void {
    _ = gs;
    // gs.tilemap.draw();
    //
    // for (gs.nodes.items) |node| {
    //     node.draw();
    // }
}

fn uiDraw(gs: *GameState) void {
    _ = gs;
}

fn camMove(gs: *GameState) void {
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
