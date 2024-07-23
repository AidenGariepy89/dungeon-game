const std = @import("std");
const rl = @import("raylib");
const t = std.testing;

const assert = std.debug.assert;
const Vec2 = rl.Vector2;

pub const Actor = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    const Self = @This();
    const VTable = struct {
        pos: *const fn(ptr: *anyopaque) Vec2,
    };

    pub fn pos(self: Self) Vec2 {
        return self.vtable.pos(self.ptr);
    }

    pub fn init(ptr: anytype) Self {
        const T = @TypeOf(ptr);
        const ptrInfo = @typeInfo(T);

        assert(ptrInfo == .Pointer);
        assert(@typeInfo(ptrInfo.Pointer.child) == .Struct);

        const vtable = struct {
            fn pos(pointer: *anyopaque) Vec2 {
                const self: T = @ptrCast(@alignCast(pointer));
                return self.pos();
            }
        };

        return .{
            .ptr = ptr,
            .vtable = &.{
                .pos = vtable.pos,
            },
        };
    }
};
