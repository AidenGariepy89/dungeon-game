const std = @import("std");
const rl = @import("raylib");
const t = std.testing;
const asset = @import("../asset/asset.zig");

const Node = @import("../2D/node.zig").Node;
const Actor = @import("../2D/actor.zig").Actor;
const Vec2 = rl.Vector2;

pub const Player = struct {
    const Self = @This();
    const GridSize = 8;

    assetServer: *asset.AssetServer,
    textureTag: asset.ImageTag,
    texture: ?rl.Texture2D = null,

    pos: Vec2 = .{ .x = 0.0, .y = 0.0 },
    moving: bool = false,
    moveTarget: Vec2 = .{ .x = 0, .y = 0 },
    
    pub fn start(self: *Self) void {
        _ = self;
    }

    pub fn update(self: *Self, dt: f32) void {
        // _ = self;
        _ = dt;

        if (self.moving) {
            self.pos = self.pos.lerp(self.moveTarget, 0.8);

            if (self.pos.equals(self.moveTarget) == 1) {
                self.moving = false;
                self.pos = self.moveTarget;
            }

            // return;
        }

        var move: Vec2 = rl.Vector2.zero();

        if (rl.isKeyPressed(.key_l) or rl.isKeyPressed(.key_right)) {
            move = .{ .x = 1, .y = 0 };
        } else if (rl.isKeyPressed(.key_h) or rl.isKeyPressed(.key_left)) {
            move = .{ .x = -1, .y = 0 };
        } else if (rl.isKeyPressed(.key_j) or rl.isKeyPressed(.key_down)) {
            move = .{ .x = 0, .y = 1 };
        } else if (rl.isKeyPressed(.key_k) or rl.isKeyPressed(.key_up)) {
            move = .{ .x = 0, .y = -1 };
        }

        if (move.equals(Vec2.zero()) != 1) {
            move = move.scale(@floatFromInt(GridSize));
            
            self.moving = true;
            self.moveTarget = self.pos.add(move);
            // self.pos = self.pos.add(move);
        }
    }

    pub fn end(self: *Self) void {
        _ = self;
    }

    pub fn draw(self: *Self) void {
        var texture: rl.Texture2D = undefined;

        if (self.texture) |img| {
            texture = img;
        } else {
            const img = self.assetServer.loadTexture(self.textureTag);
            texture = img;
            self.texture = img;
        }

        texture.drawV(self.pos, rl.Color.white);
    }

    pub fn node(self: *Self) Node {
        return Node.init(self);
    }

    pub fn actor(self: *Self) Actor {
        return Actor.init(self);
    }

    pub fn init(tag: asset.ImageTag, assetServer: *asset.AssetServer) Self {
        return Self{
            .assetServer = assetServer,
            .textureTag = tag,
        };
    }
};
