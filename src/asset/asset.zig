const std = @import("std");
const rl = @import("raylib");
const zigimg = @import("zigimg");

const t = std.testing;
const assert = std.debug.assert;

pub const ImageTag = usize;

pub const AssetServer = struct {
    const Self = @This();
    const MaxImages = 128;

    alloc: std.mem.Allocator,
    images: [MaxImages]?zigimg.Image,
    textures: [MaxImages]?rl.Texture2D,

    pub fn init(alloc: std.mem.Allocator) Self {
        return Self{
            .alloc = alloc,
            .images = [_]?zigimg.Image {null} ** MaxImages,
            .textures = [_]?rl.Texture2D {null} ** MaxImages,
        };
    }

    pub fn deinit(self: *Self) void {
        for (0..self.textures.len) |i| {
            if (self.textures[i]) |*texture| {
                texture.unload();
            }
        }

        for (0..self.images.len) |i| {
            if (self.images[i]) |*img| {
                img.deinit();
            }
        }
    }

    pub fn registerImage(self: *Self, comptime path: []const u8) ImageTag {
        const file = @embedFile(path);
        const png: zigimg.Image = zigimg.Image.fromMemory(self.alloc, file.*[0..file.len]) catch unreachable;

        for (0..self.images.len) |i| {
            if (self.images[i] == null) {
                const tag = i;
                self.images[tag] = png;
                return tag;
            }
        }

        unreachable;
    }

    pub fn loadTexture(self: *Self, tag: ImageTag) rl.Texture2D {
        const png = self.getImage(tag);
        const image = rl.Image{
            .width = @intCast(png.width),
            .height = @intCast(png.height),
            .mipmaps = 1,
            .format = .pixelformat_uncompressed_r8g8b8a8,
            .data = @constCast(png.rawBytes().ptr),
        };
        const texture = rl.loadTextureFromImage(image);

        for (0..self.textures.len) |i| {
            if (self.textures[i] == null) {
                self.textures[i] = texture;
                return texture;
            }
        }

        unreachable;
    }

    fn getImage(self: *Self, tag: ImageTag) *zigimg.Image {
        const img: *zigimg.Image = &self.images[tag].?;
        return img;
    }
};

test "init and deinit" {
    var as = AssetServer.init(t.allocator);
    as.deinit();
}

test "register asset" {
    var as = AssetServer.init(t.allocator);
    defer as.deinit();

    const tag = as.registerImage("../resources/tilemaps/dungeon.png");
    _ = tag;
}
