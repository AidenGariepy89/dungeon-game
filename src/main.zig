const std = @import("std");
const rl = @import("raylib");

const w = @import("window/window.zig");
const game = @import("game/game.zig");

const print = std.debug.print;

pub fn main() !void {
    w.init(800, 450);
    defer w.deinit();

    var gameState = game.setup();

    while (!w.shouldClose()) {
        if (try game.run(&gameState)) {
            break;
        }
    }
}
