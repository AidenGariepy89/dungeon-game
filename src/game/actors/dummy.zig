const std = @import("std");
const rl = @import("raylib");
const assert = std.debug.assert;
const GameState = @import("../GameState.zig");
const Sprite = @import("../../2D/2d.zig").Sprite;
const Vec2 = rl.Vector2;

const TileSize: f32 = 8;

pub const Dummy = struct {
    animating: bool = false,

    moving_progress: i32 = 0,
    moving_to: ?Vec2 = null,
};

pub fn moveDummy(gs: *GameState) !void {
    var buf: [5]u32 = undefined;
    const res = try gs.ecs.query(&buf, .{ Dummy, Sprite });

    switch (gs.turn_state) {
        .player => {},
        .other => {
            for (res) |entity| {
                const dummy = gs.ecs.getComponent(Dummy, entity).?;
                const spr = gs.ecs.getComponent(Sprite, entity).?;

                assert(dummy.moving_progress != 0);
                if (dummy.moving_progress > 0) {
                    if (dummy.moving_progress > 1) {
                        dummy.moving_progress = -1;
                    } else {
                        dummy.moving_progress += 1;
                    }
                    dummy.moving_to = spr.position.add(Vec2.init(0, -TileSize));
                } else {
                    if (dummy.moving_progress < -1) {
                        dummy.moving_progress = 1;
                    } else {
                        dummy.moving_progress -= 1;
                    }
                    dummy.moving_to = spr.position.add(Vec2.init(0, TileSize));
                }

                dummy.animating = true;

                gs.actors_animating += 1;
            }
        },
        .animating => {
            for (res) |entity| {
                const dummy = gs.ecs.getComponent(Dummy, entity).?;
                const spr = gs.ecs.getComponent(Sprite, entity).?;
                if (dummy.animating) {
                    if (dummy.moving_to) |pos| {
                        spr.position = pos;
                        dummy.moving_to = null;
                    }

                    gs.actors_animating -= 1;
                    dummy.animating = false;
                }
            }
        },
    }
}

pub fn drawDummy(gs: *GameState) !void {
    // todo
    var buf: [5]u32 = undefined;
    const res = try gs.ecs.query(&buf, .{Dummy, Sprite});

    for (res) |entity| {
        const spr = gs.ecs.getComponent(Sprite, entity).?;

        const txt = if (spr.texture) |txt| txt else gs.asset_server.loadTexture(spr.img);
        spr.texture = txt;

        txt.drawV(spr.position, rl.Color.white);
    }
}
