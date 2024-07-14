const std = @import("std");
const t = std.testing;

const assert = std.debug.assert;

pub const Node = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    const Self = @This();
    const VTable = struct {
        start: *const fn (ptr: *anyopaque) void,
        update: *const fn (ptr: *anyopaque, dt: f32) void,
        end: *const fn (ptr: *anyopaque) void,
        draw: *const fn (ptr: *anyopaque) void,
    };

    pub fn start(self: Self) void {
        self.vtable.start(self.ptr);
    }

    pub fn update(self: Self, dt: f32) void {
        self.vtable.update(self.ptr, dt);
    }

    pub fn end(self: Self) void {
        self.vtable.end(self.ptr);
    }

    pub fn draw(self: Self) void {
        self.vtable.draw(self.ptr);
    }

    pub fn init(ptr: anytype) Self {
        const T = @TypeOf(ptr);
        const ptrInfo = @typeInfo(T);

        assert(ptrInfo == .Pointer);
        assert(@typeInfo(ptrInfo.Pointer.child) == .Struct);

        const vtable = struct {
            fn start(pointer: *anyopaque) void {
                const self: T = @ptrCast(@alignCast(pointer));
                ptrInfo.Pointer.child.start(self);
            }

            fn update(pointer: *anyopaque, dt: f32) void {
                const self: T = @ptrCast(@alignCast(pointer));
                ptrInfo.Pointer.child.update(self, dt);
            }

            fn end(pointer: *anyopaque) void {
                const self: T = @ptrCast(@alignCast(pointer));
                ptrInfo.Pointer.child.end(self);
            }

            fn draw(pointer: *anyopaque) void {
                const self: T = @ptrCast(@alignCast(pointer));
                ptrInfo.Pointer.child.draw(self);
            }
        };

        return Self{
            .ptr = ptr,
            .vtable = &VTable{
                .start = vtable.start,
                .update = vtable.update,
                .end = vtable.end,
                .draw = vtable.draw,
            },
        };
    }
};

test "interface impl" {
    var impl = struct {
        const Self = @This();

        data: f32 = 0,

        fn start(self: *Self) void {
            self.data += 1;
        }

        fn update(self: *Self, dt: f32) void {
            self.data *= dt;
        }

        fn end(self: *Self) void {
            self.data = 0;
        }

        fn draw(self: *Self) void {
            self.data = 2;
        }

        fn node(self: *Self) Node {
            return Node.init(self);
        }
    }{};

    const node = impl.node();

    node.start();
    try t.expect(impl.data == 1.0);

    node.update(3);
    try t.expect(impl.data == 3.0);

    node.draw();
    try t.expect(impl.data == 2.0);

    node.end();
    try t.expect(impl.data == 0.0);
}
