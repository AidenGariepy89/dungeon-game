const std = @import("std");
const rl = @import("raylib");

const w = @import("window/window.zig");
const game = @import("game/game.zig");

const print = std.debug.print;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer { _ = gpa.deinit(); }

    w.init(800, 450);
    defer w.deinit();

    var gameState = try game.setup(gpa.allocator());

    while (!w.shouldClose()) {
        if (try game.run(&gameState)) {
            break;
        }
    }

    game.deinit(&gameState);
}

const tm = @import("game/tilemap.zig");
const as = @import("asset/asset.zig");

test { _ = tm; }
test { _ = as; }
