const std = @import("std");
const rl = @import("raylib");
const zigimg = @import("zigimg");

const t = std.testing;
const assert = std.debug.assert;

pub const Asset = usize;

pub const AssetServer = struct {
    const Self = @This();
    const MaxAssets = 128;

    alloc: std.mem.Allocator,
    assets: std.ArrayList([]u8),
    rawAssets: std.ArrayList([]const u8),
    assetHandles: [MaxAssets]i32,

    pub fn init(alloc: std.mem.Allocator) Self {
        return Self{
            .alloc = alloc,
            .assets = std.ArrayList([]u8).init(alloc),
            .rawAssets = std.ArrayList([]const u8).init(alloc),
            .assetHandles = [_]i32 {-1} ** MaxAssets,
        };
    }

    pub fn deinit(self: Self) void {
        for (self.assets.items) |asset| {
            self.alloc.free(asset);
        }

        self.assets.deinit();
        self.rawAssets.deinit();
    }

    pub fn registerAsset(self: *Self, comptime file: []const u8) !Asset {
        const contents = @embedFile(file);

        assert(self.assets.items.len == self.rawAssets.items.len);

        const contentsSlice: []const u8 = contents.*[0..contents.len];
        try self.rawAssets.append(contentsSlice);
        errdefer { _ = self.rawAssets.pop(); }

        const cpy = try self.alloc.alloc(u8, contents.len);
        std.mem.copyForwards(u8, cpy, contents);
        try self.assets.append(cpy);

        const idx = self.assets.items.len - 1;
        const handle = try self.newAssetHandle();
        self.assetHandles[handle] = @intCast(idx);
        return handle;
    }

    pub fn getAsset(self: Self, handle: Asset) []u8 {
        assert(handle < MaxAssets);
        assert(self.assetHandles[handle] >= 0);

        const idx: usize = @intCast(self.assetHandles[handle]);

        assert(idx < self.assets.items.len);

        return self.assets.items[idx];
    }

    fn newAssetHandle(self: *Self) !Asset {
        for (0..self.assetHandles.len) |i| {
            if (self.assetHandles[i] == -1) {
                const handle = i;
                self.assetHandles[handle] = -2; // reserved
                return handle;
            }
        }
        return error.OutOfAssets;
    }

    /// probably move this later
    pub fn openPng(self: Self, handle: Asset) !zigimg.Image {
        const rawData = self.getAsset(handle);
        return try zigimg.Image.fromMemory(self.alloc, rawData);
    }
};

pub fn assetToImage(rawAsset: []u8) rl.Image {
    return rl.Image{
        .width = 120,
        .height = 8,
        .mipmaps = 1,
        .format = .pixelformat_uncompressed_r8g8b8a8,
        .data = rawAsset.ptr,
    };
}

test "init and deinit" {
    const as = AssetServer.init(t.allocator);
    as.deinit();
}

test "register asset" {
    const path = "../resources/tilemaps/dungeon.png";
    const pathRelToRoot = "./src/resources/tilemaps/dungeon.png";

    var as = AssetServer.init(t.allocator);
    defer as.deinit();

    const handle = try as.registerAsset(path);
    const asset = as.getAsset(handle);

    // check if asset is the same as the file
    const file = try std.fs.cwd().openFile(pathRelToRoot, .{});
    var reader = file.reader();
    var i: usize = 0;
    while (true) {
        try t.expect(i < asset.len + 1);

        const c = reader.readByte() catch |err| switch (err) {
            error.EndOfStream => { break; },
            else => unreachable,
        };

        try t.expect(c == asset[i]);

        i += 1;
    }
    try t.expect(i == asset.len);
}

test "open png" {
    const Image = zigimg.Image;

    var as = AssetServer.init(t.allocator);
    defer as.deinit();
    const handle = try as.registerAsset("../resources/tilemaps/dungeon.png");
    const rawAsset = as.getAsset(handle);

    var img = try Image.fromMemory(t.allocator, rawAsset);
    defer img.deinit();

    const rlImage = rl.Image{
        .width = @intCast(img.width),
        .height = @intCast(img.height),
        .mipmaps = 1,
        .format = .pixelformat_uncompressed_r8g8b8a8,
        .data = @constCast(img.rawBytes().ptr),
    };
    _ = rlImage;
}
