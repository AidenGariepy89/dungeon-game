const std = @import("std");
const rl = @import("raylib");
const t = std.testing;
const Vec2 = rl.Vector2;
const ImageTag = @import("../asset/asset.zig").ImageTag;

pub const Sprite = struct {
    texture: ?rl.Texture2D = null,
    position: Vec2,
    img: ImageTag,
};
