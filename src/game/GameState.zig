const std = @import("std");
const rl = @import("raylib");
const AssetServer = @import("../asset/asset.zig").AssetServer;
const ECS = @import("../ecs/ECS.zig");
const Camera = @import("Camera.zig");

allocator: std.mem.Allocator = undefined,
dt: f32 = 0,
ecs: ECS = undefined,
asset_server: AssetServer = undefined,
camera: Camera = undefined,
