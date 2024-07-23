const std = @import("std");
const rl = @import("raylib");
const AssetServer = @import("../asset/asset.zig").AssetServer;
const ECS = @import("../ecs/ECS.zig");

allocator: std.mem.Allocator = undefined,
dt: f32 = 0,
ecs: ECS = undefined,
asset_server: AssetServer = undefined,

agg_dt: [2048]f32 = undefined,
agg_i: usize = 0,

cam: rl.Camera2D = undefined,
camSpeed: f32 = 1,
// assets: AssetServer,
// tilemap: Tilemap(8),
// nodes: std.ArrayList(Node),
// player: Player,
