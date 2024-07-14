//! Important things about Tilemaps:
//! 1. all tilemap assets must be horizontal, aka the height = the tile size
//! 2. the first tile in the asset must be empty

const std = @import("std");
const rl = @import("raylib");
const asset = @import("../asset/asset.zig");

const assert = std.debug.assert;
const t = std.testing;
const print = std.debug.print;

pub const Tile = struct {
    pos: rl.Vector2,
    slice: rl.Rectangle,
};

fn assertPrint(ok: bool, comptime fmt: []const u8, args: anytype) void {
    if (!ok) {
        print(fmt, args);
        unreachable;
    }
}

pub fn Tilemap(comptime tileSize: usize) type {
    return struct {
        const Self = @This();
        const TileSize = tileSize;

        alloc: std.mem.Allocator,
        pos: rl.Vector2,
        imageTag: asset.ImageTag,
        texture: ?rl.Texture2D,
        assetServer: *asset.AssetServer,
        tiles: std.ArrayList(Tile),
        VARIANT_COUNT: usize,

        pub fn init(
            alloc: std.mem.Allocator,
            pos: rl.Vector2,
            variantCount: usize,
            textureTag: asset.ImageTag,
            assetServer: *asset.AssetServer,
        ) Self {
            return Self{
                .alloc = alloc,
                .pos = pos,
                .imageTag = textureTag,
                .texture = null,
                .assetServer = assetServer,
                .tiles = std.ArrayList(Tile).init(alloc),
                .VARIANT_COUNT = variantCount,
            };
        }

        pub fn deinit(self: Self) void {
            self.tiles.deinit();
        }

        pub fn setTile(self: *Self, x: usize, y: usize, variant: usize) void {
            assertPrint(variant < self.VARIANT_COUNT, "varient: {}\n", .{variant});

            self.tiles.append(Tile{
                .pos = rl.Vector2{
                    .x = @floatFromInt(x * TileSize),
                    .y = @floatFromInt(y * TileSize),
                },
                .slice = rl.Rectangle{
                    .x = @floatFromInt((variant + 1) * TileSize),
                    .y = 0,
                    .width = @floatFromInt(TileSize),
                    .height = @floatFromInt(TileSize),
                },
            }) catch unreachable;
        }

        pub fn draw(self: *Self) void {
            var texture: rl.Texture2D = undefined;

            if (self.texture) |img| {
                texture = img;
            } else {
                const img = self.assetServer.loadTexture(self.imageTag);
                self.texture = img;
                texture = img;
            }

            for (self.tiles.items) |tile| {
                texture.drawRec(tile.slice, self.pos.add(tile.pos), rl.Color.white);
            }
        }

        pub fn loadLevel(self: *Self, comptime path: []const u8) void {
            const file = @embedFile(path);

            var x: usize = 0;
            var y: usize = 0;
            var i: usize = 0;

            outer: while (i < file.len) {
                const c = file[i];
                switch (c) {
                    '/' => {
                        i += 1;
                        while (i < file.len) {
                            if (file[i] == '\n') {
                                i += 1;
                                continue :outer;
                            }
                            i += 1;
                        }
                        break;
                    },
                    '0'...'9' => {
                        self.setTile(x, y, @as(usize, @intCast(c - '0')));
                    },
                    'a'...'z' => {
                        self.setTile(x, y, @as(usize, @intCast(c - 'a' + 10)));
                    },
                    '\n' => {
                        y += 1;
                        x = 0;
                        i += 1;
                        continue;
                    },
                    else => {},
                }
                x += 1;
                i += 1;
            }
        }
    };
}

test "set tile" {
    const testTag: asset.ImageTag = 5; // not a real tag, don't do this
    var testServer = asset.AssetServer.init(t.allocator);
    defer testServer.deinit();

    var tilemap = Tilemap(8).init(t.allocator, rl.Vector2.zero(), 2, testTag, &testServer);
    defer tilemap.deinit();

    tilemap.setTile(1, 1, 1);

    try t.expect(tilemap.tiles.items.len == 1);
    try t.expect(tilemap.tiles.items[0].slice.x == 16.0);
    try t.expect(tilemap.tiles.items[0].pos.x == 8.0);
}
