const std = @import("std");
const rl = @import("raylib");
const t = std.testing;
const asset = @import("../asset/asset.zig");

const Node = @import("../2D/node.zig").Node;
const Actor = @import("../2D/actor.zig").Actor;
const Vec2 = rl.Vector2;

const Cam = struct {
    const Self = @This();

    camera: rl.Camera2D,
    target: ?Actor,
};
