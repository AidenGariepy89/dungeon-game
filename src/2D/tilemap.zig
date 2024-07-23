//! Important things about Tilemaps:
//! 1. all tilemap assets must be horizontal, aka the height = the tile size
//! 2. the first tile in the asset must be empty

const std = @import("std");
const rl = @import("raylib");
const t = std.testing;
const asset = @import("../asset/asset.zig");
const assert = std.debug.assert;
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const AssetServer = asset.AssetServer;
const GameState = @import("../game/GameState.zig");

pub const Tile = struct {
    pos: rl.Vector2,
    slice: rl.Rectangle,
};
const TileList = std.ArrayList(Tile);

pub const Tilemap = struct {
    const Self = @This();
    const TILE_SIZE = 8;

    world_pos: rl.Vector2,
    img: asset.ImageTag,
    texture: ?rl.Texture2D,
    tiles: TileList,

    pub fn init(allocator: Allocator, img_tag: asset.ImageTag, pos: ?rl.Vector2) Self {
        const p = pos orelse rl.Vector2.zero();

        return Self{
            .world_pos = p,
            .img = img_tag,
            .texture = null,
            .tiles = TileList.init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        // self.texture.?.unload();
        self.tiles.deinit();
        self.* = undefined;
    }

    pub fn setTile(self: *Self, x: u32, y: u32, variant: u32) !void {
        try self.tiles.append(Tile{
            .pos = rl.Vector2{
                .x = @floatFromInt(x * TILE_SIZE),
                .y = @floatFromInt(y * TILE_SIZE),
            },
            .slice = rl.Rectangle{
                .x = @floatFromInt((variant + 1) * TILE_SIZE),
                .y = 0.0,
                .width = @floatFromInt(TILE_SIZE),
                .height = @floatFromInt(TILE_SIZE),
            },
        });
    }

    pub fn loadLevel(self: *Self, comptime path: []const u8) !void {
        const file = @embedFile(path);

        var x: u32 = 0;
        var y: u32 = 0;
        var i: u32 = 0;

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
                    try self.setTile(x, y, @as(u32, @intCast(c - '0')));
                },
                'a'...'z' => {
                    try self.setTile(x, y, @as(u32, @intCast(c - 'a' + 10)));
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

pub fn renderTilemaps(gs: *GameState) !void {
    var ecs = gs.ecs;
    var buf: [1]u32 = undefined;
    const res = try ecs.query(Tilemap, &buf);

    for (res) |entity| {
        const tilemap = ecs.getComponent(Tilemap, entity).?;
        var texture: rl.Texture2D = undefined;
        if (tilemap.texture) |txtr| {
            texture = txtr;
        } else {
            const txtr = gs.asset_server.loadTexture(tilemap.img);
            tilemap.texture = txtr;
            texture = txtr;
        }

        for (tilemap.tiles.items) |tile| {
            texture.drawRec(tile.slice, tile.pos, rl.Color.white);
        }
    }
}
