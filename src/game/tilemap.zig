const std = @import("std");
const rl = @import("raylib");

const t = std.testing;

pub fn openTexture(path: [*:0]const u8) !rl.Texture2D {
    if (!rl.fileExists(path)) {
        return error.FileDoesNotExist;
    }

    return rl.loadTexture(path);
}

pub const Tile = struct {
    pos: rl.Vector2,
    tile: usize,

    const TileSize = 8;

    pub fn worldPos(self: Tile) rl.Vector2 {
        return self.pos.scale(TileSize);
    }

    pub fn draw(self: Tile, tilemap: rl.Texture2D) void {
        const slice = rl.Rectangle{
            .x = @floatFromInt(self.tile * TileSize),
            .y = 0,
            .width = @floatFromInt(TileSize),
            .height = @floatFromInt(TileSize),
        };

        tilemap.drawRec(slice, self.worldPos(), rl.Color.white);
    }
};

const Level1 = @embedFile("../levels/1.level");
/// Load tiles from Level1 during comptime
pub inline fn loadTilemap() *const [numTiles(Level1.len, Level1)]Tile {
    comptime {
        const num = numTiles(Level1.len, Level1);
        const array = parseToTiles(Level1.len, Level1, num);
        return &array;
    }
}

const ParseInstruction = union(enum) {
    tile: usize,
    newline: void,
};

/// Determines instructions for parsing tilesets
fn interpretTile(c: u8) ?ParseInstruction {
    return switch (c) {
        '0'...'9' => {
            return ParseInstruction{ .tile = c - '0' };
        },
        'a'...'z' => {
            return ParseInstruction{ .tile = c - 'a' + 10 };
        },
        '\n' => {
            return ParseInstruction{ .newline = {} };
        },
        else => null,
    };
}

/// Counts the number of tiles in a tileset text blob at comptime.
fn numTiles(comptime len: usize, blob: *const [len:0]u8) comptime_int {
    comptime {
        var num = 0;

        for (blob) |c| {
            if (interpretTile(c)) |instruction| {
                if (instruction == .tile) {
                    num += 1;
                }
            }
        }

        return num;
    }
}

/// Parses a text blob known at compile time to an array of Tiles
///
/// Undefined behavior if `num` is not equal to the number of tiles in blob
///
/// len - length of blob
/// blob - tileset string blob
/// num - number of tiles found in blob
///
/// Only run function in a comptime context
inline fn parseToTiles(comptime len: usize, comptime blob: *const [len:0]u8, comptime num: usize) [num]Tile {
    comptime {
        @setEvalBranchQuota(2000);
        var array: [num]Tile = undefined;

        var pos = rl.Vector2{ .x = 0, .y = 0 };
        var i = 0;
        var loopCount = 0;
        for (blob) |c| {
            loopCount += 1;
            if (interpretTile(c)) |instruction| {
                switch (instruction) {
                    .tile => |tile| {
                        std.debug.assert(i < num);
                        array[i] = Tile{
                            .pos = pos,
                            .tile = tile,
                        };
                        i += 1;
                    },
                    .newline => {
                        pos.y += 1;
                        pos.x = 0;
                        continue;
                    },

                }
            }
            pos.x += 1;
        }

        return array;
    }
}

test "parse blob to tiles comptime" {
    const blob = "111  1\n1 11";
    const tileCount = numTiles(blob.len, blob);

    const array = parseToTiles(blob.len, blob, tileCount);

    try t.expect(array.len == tileCount);

    const expectedPositions = [_]rl.Vector2 {
        rl.Vector2{ .x = 0, .y = 0 },
        rl.Vector2{ .x = 1, .y = 0 },
        rl.Vector2{ .x = 2, .y = 0 },
        rl.Vector2{ .x = 5, .y = 0 },
        rl.Vector2{ .x = 0, .y = 1 },
        rl.Vector2{ .x = 2, .y = 1 },
        rl.Vector2{ .x = 3, .y = 1 },
    };

    for (array, expectedPositions) |tile, expectedPos| {
        try t.expect(tile.tile == 1);
        try t.expect(tile.pos.equals(expectedPos) == 1);
    }
}
