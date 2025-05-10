const std = @import("std");
const rl = @import("raylib");
const t = std.testing;
const asset = @import("../../asset/asset.zig");
const sprite = @import("../../2D/2d.zig");
const Allocator = std.mem.Allocator;
const GameState = @import("../GameState.zig");
const AssetServer = asset.AssetServer;
const ECS = @import("../../ecs/ECS.zig");
const Vec2 = rl.Vector2;
const Camera = @import("../Camera.zig");

const TileSizeF: f32 = 8.0;

pub fn package(ecs: *ECS, asset_server: *AssetServer, position: Vec2) !void {
    ecs.addSystem(&updatePlayer, .s1);
    ecs.addSystem(&drawPlayer, .s2);

    _ = try ecs.newEntity(.{
        Player{},
        sprite.Sprite{
            .img = asset_server.registerImage("../resources/sprites/player.png"),
            .position = position,
        },
    });
}

pub const Player = struct {
    const WalkingTime: u32 = 5;
    const SprintingTime: u32 = 2;
    const SneakingTime: u32 = 10;

    /// true if still animating turn
    animating: bool = false,

    /// coordinate to move to during animation
    moving_to: ?Vec2 = null,

    /// time it takes for one move or wait
    current_movement_speed: u32 = WalkingTime,
};

fn updatePlayer(gs: *GameState) !void {
    const entity = gs.ecs.one(.{Player, sprite.Sprite}).?;
    const spr = gs.ecs.getComponent(sprite.Sprite, entity).?;
    const player = gs.ecs.getComponent(Player, entity).?;

    switch (gs.turn_state) {
        .player => {
            const finished = try playerTurn(gs, spr, player);

            // Player decided move, now let other entities decide move.
            if (finished) {
                gs.actors_animating += 1;
                player.animating = true;

                gs.turn_state = .other;
            }
        },
        .other => {
            // All actors should have decided their move by now.
            gs.turn_state = .animating;
        },
        .animating => {
            if (player.animating) {
                if (player.moving_to) |pos| {
                    spr.position = pos;
                    gs.camera.cam.target = spr.position.add(Vec2.init(4, 4));
                }

                gs.actors_animating -= 1;
                player.animating = false;
            }

            // All actors done animating, so back to player's turn.
            if (gs.actors_animating == 0) {
                gs.turn_state = .player;
            }
        },
    }
}

/// Returns true if finished turn.
fn playerTurn(gs: *GameState, spr: *sprite.Sprite, player: *Player) !bool {
    var dir = Vec2.zero();
    if (rl.isKeyPressed(.key_right) or rl.isKeyPressed(.key_l)) {
        dir.x = 1;
    } else if (rl.isKeyPressed(.key_left) or rl.isKeyPressed(.key_h)) {
        dir.x = -1;
    } else if (rl.isKeyPressed(.key_up) or rl.isKeyPressed(.key_k)) {
        dir.y = -1;
    } else if (rl.isKeyPressed(.key_down) or rl.isKeyPressed(.key_j)) {
        dir.y = 1;
    }

    if (dir.equals(Vec2.zero()) != 1) {
        player.moving_to = spr.position.add(dir.scale(TileSizeF));
        return true;
    }

    if (rl.isKeyPressed(.key_space)) {
        gs.time_passed = player.current_movement_speed;

        return true;
    }

    return false;
}

fn drawPlayer(gs: *GameState) !void {
    const player = gs.ecs.one(.{Player, sprite.Sprite}).?;
    const spr: *sprite.Sprite = gs.ecs.getComponent(sprite.Sprite, player).?;

    const texture: rl.Texture2D = if (spr.texture) |txtr| txtr else gs.asset_server.loadTexture(spr.img);
    spr.texture = texture;

    texture.drawV(spr.position, rl.Color.white);
}
