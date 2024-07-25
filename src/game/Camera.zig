const std = @import("std");
const rl = @import("raylib");
const w = @import("../window/window.zig");

const Self = @This();
const CAM_SPEED: f32 = 200;

cam: rl.Camera2D,

pub fn init(x: f32, y: f32) Self {
    return Self{
        .cam = rl.Camera2D{
            .rotation = 0,
            .zoom = 12,
            .offset = .{ .x = @floatFromInt(w.wh()), .y = @floatFromInt(w.hh()) },
            .target = .{ .x = x, .y = y },
        },
    };
}

pub fn update(self: *Self, dt: f32) void {
    self.cam.offset.x = @floatFromInt(w.wh());
    self.cam.offset.y = @floatFromInt(w.hh());

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
        vel = dir.normalize().scale(CAM_SPEED);
    }

    self.cam.target = self.cam.target.add(vel.scale(dt));
}
