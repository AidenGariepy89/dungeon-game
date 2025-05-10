const std = @import("std");
const rl = @import("raylib");
const zigimg = @import("zigimg");
const w = @import("../window/window.zig");
const asset = @import("../asset/asset.zig");
const print = std.debug.print;
const renderTilemaps = @import("../2D/tilemap.zig").renderTilemaps;
const player = @import("actors/player.zig");
const dummy = @import("actors/dummy.zig");
const tm = @import("../2D/tilemap.zig");
const AssetServer = asset.AssetServer;
const ECS = @import("../ecs/ECS.zig");
const GameState = @import("GameState.zig");
const Camera = @import("Camera.zig");
const Sprite = @import("../2D/2d.zig").Sprite;

fn uiDraw(gs: *GameState) !void {
    var buf: [128]u8 = undefined;
    const text = try std.fmt.bufPrintZ(&buf, "TurnState: {} | Waiting: {} | FPS: {d}", .{gs.turn_state, gs.actors_animating, 1 / gs.dt});

    rl.drawText(text, 10, 10, 20, rl.Color.white);
}

pub fn setup(allocator: std.mem.Allocator) !GameState {
    var asset_server = AssetServer.init(allocator);

    var ecs = ECS.init(allocator);

    var tilemap = tm.Tilemap.init(
        allocator,
        asset_server.registerImage("../resources/tilemaps/dungeon.png"),
        null,
    );
    try tilemap.loadLevel("../resources/levels/1");
    _ = try ecs.newEntity(.{tilemap});
    ecs.addSystem(&tm.renderTilemaps, .s2);
    ecs.addSystem(&tm.cleanupTilemaps, .shutdown);

    const player_init_pos = rl.Vector2.init(40, 40);
    const cam_init_pos = player_init_pos.add(rl.Vector2.init(4, 4));
    const camera = Camera.init(cam_init_pos.x, cam_init_pos.y);

    try player.package(&ecs, &asset_server, player_init_pos);

    const img_tag = asset_server.registerImage("../resources/sprites/dummy.png");

    for (0..5) |i| {
        _ = try ecs.newEntity(.{
            dummy.Dummy{ .moving_progress = if (i % 2 == 0) 1 else -1 },
            Sprite{
                .position = rl.Vector2.init(48 + (16 * @as(f32, @floatFromInt(i))), 40),
                .img = img_tag,
            },
        });
    }

    ecs.addSystem(&dummy.moveDummy, .s1);
    ecs.addSystem(&dummy.drawDummy, .s2);

    ecs.addSystem(&uiDraw, .s3);

    var game_state = GameState{
        .allocator = allocator,
        .asset_server = asset_server,
        .ecs = ecs,
        .camera = camera,
    };

    try ecs.update(&game_state, .startup);

    return game_state;
}

pub fn deinit(gs: *GameState) void {
    gs.ecs.update(gs, .shutdown) catch unreachable;

    gs.ecs.deinit();
    gs.asset_server.deinit();
}

pub fn run(gs: *GameState) !bool {
    gs.dt = rl.getFrameTime();

    gs.camera.resize();
    try gs.ecs.update(gs, .s1);

    rl.beginDrawing();

    rl.clearBackground(rl.Color.black);

    rl.beginMode2D(gs.camera.cam);
    // world draw
    try gs.ecs.update(gs, .s2);

    rl.endMode2D();

    // ui draw
    try gs.ecs.update(gs, .s3);

    rl.endDrawing();

    return false;
}
