const std = @import("std");
const rl = @import("raylib");
const t = std.testing;
const asset = @import("../asset/asset.zig");
const sprite = @import("../2D/2d.zig");
const Allocator = std.mem.Allocator;
const GameState = @import("GameState.zig");
const AssetServer = asset.AssetServer;
const ECS = @import("../ecs/ECS.zig");
const Vec2 = rl.Vector2;

pub fn package(ecs: *ECS, asset_server: *AssetServer) !void {
    ecs.addSystem(&updatePlayer, 0);
    ecs.addSystem(&drawPlayer, 0);

    _ = try ecs.newEntity(.{
        Player{},
        sprite.Sprite{
            .img = asset_server.registerImage("../resources/sprites/player.png"),
            .position = Vec2.zero(),
        },
    });
}

pub const Player = struct {
};

fn updatePlayer(gs: *GameState) !void {
    const player = gs.ecs.one(.{Player, sprite.Sprite}).?;
    const spr: *sprite.Sprite = gs.ecs.getComponent(sprite.Sprite, player).?;

    spr.position = spr.position.add(Vec2.init(0, 1).scale(20.0 * gs.dt));
}

fn drawPlayer(gs: *GameState) !void {
    const player = gs.ecs.one(.{Player, sprite.Sprite}).?;
    const spr: *sprite.Sprite = gs.ecs.getComponent(sprite.Sprite, player).?;

    const texture: rl.Texture2D = if (spr.texture) |txtr| txtr else gs.asset_server.loadTexture(spr.img);
    spr.texture = texture;

    texture.drawV(spr.position, rl.Color.white);
}
