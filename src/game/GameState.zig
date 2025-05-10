const std = @import("std");
const rl = @import("raylib");
const AssetServer = @import("../asset/asset.zig").AssetServer;
const ECS = @import("../ecs/ECS.zig");
const Camera = @import("Camera.zig");

allocator: std.mem.Allocator = undefined,
ecs: ECS = undefined,
asset_server: AssetServer = undefined,
camera: Camera = undefined,

/// Delta time
dt: f32 = 0,
/// In-game time that the player's turn took
///
/// Time is relative, so here is reference values:
///     move 1 tile in 5 time  = average pace
///     move 1 tile in 2 time  = sprinting
///     move 1 tile in 10 time = sneaking
time_passed: u32 = 0,

turn_state: Turn = Turn.player,
actors_animating: u32 = 0,

const Turn = enum {
    player,
    other,
    animating,
};
