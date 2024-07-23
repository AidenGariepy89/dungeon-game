const std = @import("std");
const builtin = std.builtin;
const t = std.testing;
const mem = std.mem;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const GameState = @import("../game/GameState.zig");

const Self = @This();

const MAX_ENTITIES = 200;
const MAX_COMPONENTS = 32;
pub const Entity = u32;
pub const Component = u8;
pub const Signature = std.bit_set.IntegerBitSet(MAX_COMPONENTS);
pub const System = struct {
    tag: u32,
    func: *const fn (gs: *GameState) anyerror!void,
};

const ComponentMap = std.StringArrayHashMap(Component);
const CompArrMap = std.StringArrayHashMap(ComponentArrayGeneric);
const SystemList = std.ArrayList(System);

allocator: Allocator,
entity_signatures: [MAX_ENTITIES]Signature,
entity_count: u32 = 0,
comp_arr_map: CompArrMap,
component_map: ComponentMap,
component_count: u32 = 0,
systems: SystemList,

pub fn newEntityEmpty(self: *Self) Entity {
    assert(self.entity_count < MAX_ENTITIES);

    const entity = self.entity_count;
    self.entity_count += 1;
    return entity;
}

pub fn newEntity(self: *Self, components: anytype) !Entity {
    const entity = self.newEntityEmpty();

    const tuple_info = @typeInfo(@TypeOf(components));
    if (tuple_info != .Struct) {
        @compileError("param must be a tuple!");
    }
    if (!tuple_info.Struct.is_tuple) {
        @compileError("param must be a tuple!");
    }

    inline for (tuple_info.Struct.fields) |field| {
        var generic = self.getComponentArr(field.type) orelse try self.registerComponent(field.type);
        var comp_arr = generic.toComponentArray(field.type);

        const comp_item: field.type = @field(components, field.name);
        try comp_arr.add(comp_item, entity);

        const comp = self.getComponentType(field.type).?;
        self.entity_signatures[entity].set(comp);
    }

    return entity;
}

pub fn addComponent(self: *Self, T: type, component: T, entity: Entity) !*T {
    assert(entity < self.entity_count);

    var generic = self.getComponentArr(T) orelse try self.registerComponent(T);
    var comp_arr = generic.toComponentArray(T);

    try comp_arr.add(component, entity);

    const comp = self.getComponentType(T).?;
    self.entity_signatures[entity].set(comp);

    return comp_arr.get(entity).?;
}

pub fn removeComponent(self: *Self, T: type, entity: Entity) !T {
    assert(entity < self.entity_count);

    var generic = self.getComponentArr(T).?;
    var comp_arr = generic.toComponentArray(T);

    const comp = self.getComponentType(T).?;
    self.entity_signatures[entity].unset(comp);

    return comp_arr.remove(entity);
}

pub fn getComponent(self: *Self, T: type, entity: Entity) ?*T {
    var generic = self.getComponentArr(T).?;
    var comp_arr = generic.toComponentArray(T);

    return comp_arr.get(entity);
}

pub fn getComponentType(self: *Self, T: type) ?Component {
    const comp_name = @typeName(T);
    return self.component_map.get(comp_name).?;
}

fn getComponentArr(self: *Self, T: type) ?ComponentArrayGeneric {
    const comp_name = @typeName(T);
    return self.comp_arr_map.get(comp_name);
}

fn registerComponent(self: *Self, T: type) !ComponentArrayGeneric {
    assert(self.component_count < MAX_COMPONENTS);

    var comp_arr = try self.allocator.create(ComponentArray(T));
    comp_arr.* = ComponentArray(T).init(self.allocator);

    const type_name = @typeName(T);
    const generic = comp_arr.generic();

    try self.comp_arr_map.put(type_name, generic);
    try self.component_map.put(type_name, @intCast(self.component_count));
    self.component_count += 1;
    return generic;
}

fn componentCount(self: *Self, T: type) usize {
    var generic = self.getComponentArr(T).?;
    const comp_arr = generic.toComponentArray(T);
    return comp_arr.components.items.len;
}

/// Add a system to the ECS. Specify a tag to update systems of that tag later.
/// Tags default to 0.
pub fn addSystem(self: *Self, comptime func_ptr: anytype, tag: ?u32) void {
    const ptr_info = @typeInfo(@TypeOf(func_ptr));
    if (ptr_info != .Pointer) {
        @compileError("Systems must be function pointers");
    }
    if (ptr_info.Pointer.size != .One) {
        @compileError("Systems must be function pointers");
    }

    const func_info = @typeInfo(ptr_info.Pointer.child);
    if (func_info != .Fn) {
        @compileError("Systems must be function pointers");
    }
    if (func_info.Fn.params.len != 1) {
        @compileError("Systems must have one param");
    }
    if (func_info.Fn.params[0].type != *GameState) {
        @compileError("The system param must be *GameState");
    }

    const runner = struct {
        fn run(gs: *GameState) !void {
            return @call(builtin.CallModifier.always_inline, func_ptr, .{gs});
        }
    };

    const system = System{
        .tag = tag orelse 0,
        .func = &runner.run,
    };

    self.systems.append(system) catch unreachable;
}

pub fn update(self: *Self, gs: *GameState, tag: ?u32) !void {
    const system_tag = tag orelse 0;
    for (self.systems.items) |*system| {
        if (system.tag != system_tag) {
            continue;
        }
        try system.func(gs);
    }
}

pub const QueryError = error{NoSpaceLeft};

pub fn query(self: *Self, T: type, buf: []Entity) QueryError![]Entity {
    const comp = self.getComponentType(T).?;
    var sig = Signature.initEmpty();
    sig.set(comp);
    return self.getSigMatches(sig, buf);
}

pub fn query2(self: *Self, T: type, U: type, buf: []Entity) QueryError![]Entity {
    const comp = self.getComponentType(T).?;
    const comp2 = self.getComponentType(U).?;
    var sig = Signature.initEmpty();
    sig.set(comp);
    sig.set(comp2);
    return self.getSigMatches(sig, buf);
}

pub fn query3(self: *Self, T: type, U: type, V: type, buf: []Entity) QueryError![]Entity {
    const comp = self.getComponentType(T).?;
    const comp2 = self.getComponentType(U).?;
    const comp3 = self.getComponentType(V).?;
    var sig = Signature.initEmpty();
    sig.set(comp);
    sig.set(comp2);
    sig.set(comp3);
    return self.getSigMatches(sig, buf);
}

fn getSigMatches(self: *Self, needle: Signature, buf: []Entity) QueryError![]Entity {
    var buf_idx: usize = 0;
    for (0..self.entity_count) |i| {
        const sig = self.entity_signatures[i];
        const entity: Entity = @intCast(i);
        if (needle.subsetOf(sig)) {
            if (buf_idx >= buf.len) {
                return QueryError.NoSpaceLeft;
            }
            buf[buf_idx] = entity;
            buf_idx += 1;
        }
    }
    return buf[0..buf_idx];
}

pub fn init(allocator: Allocator) Self {
    return Self{
        .allocator = allocator,
        .entity_signatures = [_]Signature{Signature.initEmpty()} ** MAX_ENTITIES,
        .comp_arr_map = CompArrMap.init(allocator),
        .component_map = ComponentMap.init(allocator),
        .systems = SystemList.init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    for (self.comp_arr_map.values()) |*generic| {
        generic.deinit();
        generic.free(self.allocator);
    }
    self.comp_arr_map.deinit();
    self.component_map.deinit();
    self.systems.deinit();
}

fn ComponentArray(T: type) type {
    return struct {
        const CompList = std.ArrayList(T);
        const Map = std.AutoArrayHashMap(u32, u32);
        const This = @This();

        components: CompList,
        entity_to_idx: Map,
        idx_to_entity: Map,

        fn add(self: *This, component: T, entity: Entity) !void {
            assert(self.entity_to_idx.get(entity) == null);

            const idx: u32 = @intCast(self.components.items.len);
            try self.components.append(component);

            try self.entity_to_idx.put(entity, idx);
            try self.idx_to_entity.put(idx, entity);
        }

        fn remove(self: *This, entity: Entity) !T {
            const idx_remove = self.entity_to_idx.get(entity).?;
            const idx_last: u32 = @intCast(self.components.items.len - 1);
            const entity_last = self.idx_to_entity.get(idx_last).?;

            try self.entity_to_idx.put(entity_last, idx_remove);
            try self.idx_to_entity.put(idx_remove, entity_last);
            _ = self.entity_to_idx.swapRemove(entity);
            _ = self.idx_to_entity.swapRemove(idx_last);

            return self.components.swapRemove(idx_remove);
        }

        fn get(self: *This, entity: Entity) ?*T {
            const idx = self.entity_to_idx.get(entity) orelse return null;
            return &self.components.items[idx];
        }

        fn generic(self: *This) ComponentArrayGeneric {
            return ComponentArrayGeneric{
                .ptr = self,
                .vtable = .{
                    .deinit = This.deinit,
                    .free = This.free,
                },
            };
        }

        fn init(allocator: Allocator) This {
            return This{
                .components = CompList.init(allocator),
                .entity_to_idx = Map.init(allocator),
                .idx_to_entity = Map.init(allocator),
            };
        }

        fn deinit(ptr: *anyopaque) void {
            const self: *This = @ptrCast(@alignCast(ptr));

            self.components.deinit();
            self.entity_to_idx.deinit();
            self.idx_to_entity.deinit();

            self.* = undefined;
        }

        fn free(ptr: *anyopaque, allocator: Allocator) void {
            const self: *This = @ptrCast(@alignCast(ptr));
            allocator.destroy(self);
        }
    };
}

const ComponentArrayGeneric = struct {
    const This = @This();

    ptr: *anyopaque,
    vtable: VTable,

    const VTable = struct {
        deinit: *const fn (ptr: *anyopaque) void,
        free: *const fn (ptr: *anyopaque, allocator: Allocator) void,
    };

    fn deinit(self: *This) void {
        self.vtable.deinit(self.ptr);
    }

    fn free(self: *This, allocator: Allocator) void {
        self.vtable.free(self.ptr, allocator);
    }

    fn toComponentArray(self: *This, T: type) *ComponentArray(T) {
        return @ptrCast(@alignCast(self.ptr));
    }
};

// Testing

test "Entity init with components" {
    const Player = struct {
        xp: u32,
        health: u32,
    };
    const Pos = struct {
        x: f32,
        y: f32,
    };

    var ecs = Self.init(t.allocator);
    defer ecs.deinit();

    const entity = try ecs.newEntity(.{
        Player{ .xp = 0, .health = 100 },
        Pos{ .x = 0, .y = 0 },
    });

    const player = ecs.getComponent(Player, entity);
    try t.expect(player != null);
    try t.expect(player.?.xp == 0);
    try t.expect(player.?.health == 100);

    const pos = ecs.getComponent(Pos, entity);
    try t.expect(pos != null);
    try t.expect(pos.?.x == @as(f32, 0));
    try t.expect(pos.?.y == @as(f32, 0));
}

test "Add, remove, and get components" {
    const Player = struct {
        xp: u32,
        health: u32,
    };

    var ecs = Self.init(t.allocator);
    defer ecs.deinit();

    const e1 = ecs.newEntityEmpty();
    const e2 = ecs.newEntityEmpty();
    const e3 = ecs.newEntityEmpty();

    const player1 = Player{ .xp = 0, .health = 100 };
    const player2 = Player{ .xp = 254, .health = 87 };
    const player3 = Player{ .xp = 75, .health = 200 };
    _ = try ecs.addComponent(Player, player1, e1);
    _ = try ecs.addComponent(Player, player2, e2);
    _ = try ecs.addComponent(Player, player3, e3);

    try t.expect(ecs.comp_arr_map.count() == 1);
    try t.expect(ecs.componentCount(Player) == 3);

    const get_player1 = ecs.getComponent(Player, e1).?;
    const get_player2 = ecs.getComponent(Player, e2).?;
    const get_player3 = ecs.getComponent(Player, e3).?;
    try t.expect(get_player1.xp == player1.xp);
    try t.expect(get_player1.health == player1.health);
    try t.expect(get_player2.xp == player2.xp);
    try t.expect(get_player2.health == player2.health);
    try t.expect(get_player3.xp == player3.xp);
    try t.expect(get_player3.health == player3.health);

    const removed_player = try ecs.removeComponent(Player, e2);
    const get_after_removed_player1 = ecs.getComponent(Player, e1);
    const get_after_removed_player2 = ecs.getComponent(Player, e2);
    const get_after_removed_player3 = ecs.getComponent(Player, e3);

    try t.expect(get_after_removed_player1 != null);
    try t.expect(get_after_removed_player1.?.xp == player1.xp);
    try t.expect(get_after_removed_player1.?.health == player1.health);

    try t.expect(get_after_removed_player2 == null);
    try t.expect(removed_player.xp == player2.xp);
    try t.expect(removed_player.health == player2.health);

    try t.expect(get_after_removed_player3 != null);
    try t.expect(get_after_removed_player3.?.xp == player3.xp);
    try t.expect(get_after_removed_player3.?.health == player3.health);
}

test "entity component signatures" {
    const Pos = struct {
        x: f32,
        y: f32,
    };
    const Physics = struct {
        dx: f32,
        dy: f32,
        ddx: f32,
        ddy: f32,
    };

    var ecs = Self.init(t.allocator);
    defer ecs.deinit();

    const entity = try ecs.newEntity(.{
        Pos{ .x = 100, .y = 20 },
        Physics{ .dx = 0, .dy = 0, .ddx = 10, .ddy = 0 },
    });

    const posIdx = 0;
    const physicsIdx = 1;
    var expected = Signature.initEmpty();
    expected.set(posIdx);
    expected.set(physicsIdx);

    const actual = ecs.entity_signatures[entity];

    try t.expectEqual(expected, actual);
}

test "entity init with zero components" {
    var ecs = Self.init(t.allocator);
    defer ecs.deinit();

    _ = try ecs.newEntity(.{});
}

test "query test" {
    var ecs = Self.init(t.allocator);
    defer ecs.deinit();

    const Pos = struct {
        x: f32,
        y: f32,
    };
    const Player = struct {
        xp: u32,
        health: u32,
    };
    const Color = struct {
        color: ColorType,
        const ColorType = enum {
            red,
            green,
            blue,
        };
    };
    const Weapon = struct {
        weapon_type: WeaponType,
        const WeaponType = enum {
            sword,
            bow,
        };
    };

    const e1 = try ecs.newEntity(.{
        Color{ .color = .red },
        Player{ .xp = 10, .health = 100 },
        Pos{ .x = 50, .y = 100 },
    });
    const e2 = try ecs.newEntity(.{
        Color{ .color = .green },
        Pos{ .x = -7, .y = 23 },
    });
    const e3 = try ecs.newEntity(.{
        Color{ .color = .blue },
        Player{ .xp = 50, .health = 800 },
        Weapon{ .weapon_type = .bow },
    });

    var buf: [3]Entity = undefined;
    var res = try ecs.query(Color, &buf);
    try t.expect(res.len == 3);
    try t.expectEqual(e1, res[0]);
    try t.expectEqual(e2, res[1]);
    try t.expectEqual(e3, res[2]);

    const color1 = ecs.getComponent(Color, res[0]).?;
    const color2 = ecs.getComponent(Color, res[1]).?;
    const color3 = ecs.getComponent(Color, res[2]).?;
    try t.expectEqual(Color{ .color = .red }, color1.*);
    try t.expectEqual(Color{ .color = .green }, color2.*);
    try t.expectEqual(Color{ .color = .blue }, color3.*);

    res = try ecs.query2(Color, Player, &buf);
    try t.expect(res.len == 2);
    try t.expectEqual(e1, res[0]);
    try t.expectEqual(e3, res[1]);

    const q2_color1 = ecs.getComponent(Color, res[0]).?;
    const q2_color2 = ecs.getComponent(Color, res[1]).?;
    const q2_player1 = ecs.getComponent(Player, res[0]).?;
    const q2_player2 = ecs.getComponent(Player, res[1]).?;
    try t.expectEqual(Color{ .color = .red }, q2_color1.*);
    try t.expectEqual(Color{ .color = .blue }, q2_color2.*);
    try t.expectEqual(Player{ .xp = 10, .health = 100 }, q2_player1.*);
    try t.expectEqual(Player{ .xp = 50, .health = 800 }, q2_player2.*);

    res = try ecs.query3(Weapon, Player, Color, &buf);
    try t.expect(res.len == 1);
    try t.expectEqual(e3, res[0]);

    const q3_weapon = ecs.getComponent(Weapon, res[0]).?;
    const q3_player = ecs.getComponent(Player, res[0]).?;
    const q3_color = ecs.getComponent(Color, res[0]).?;
    try t.expectEqual(Weapon{ .weapon_type = .bow }, q3_weapon.*);
    try t.expectEqual(Player{ .xp = 50, .health = 800 }, q3_player.*);
    try t.expectEqual(Color{ .color = .blue }, q3_color.*);
}

test "query out of space" {
    var ecs = Self.init(t.allocator);
    defer ecs.deinit();

    const Pos = struct {
        x: f32 = 0,
        y: f32 = 0,
    };

    _ = try ecs.newEntity(.{Pos{}});
    _ = try ecs.newEntity(.{Pos{}});
    _ = try ecs.newEntity(.{Pos{}});

    var buf: [2]Entity = undefined;
    const res = ecs.query(Pos, &buf);
    try t.expectError(QueryError.NoSpaceLeft, res);
}

test "system test" {
    const Pos = struct {
        x: f32 = 0,
        y: f32 = 0,
    };

    const system = struct {
        fn moveRight(gs: *GameState) !void {
            var buf: [3]Entity = undefined;
            const q = try gs.ecs.query(Pos, &buf);

            for (q) |entity| {
                var pos = gs.ecs.getComponent(Pos, entity).?;
                pos.x += 1;
            }
        }
    };

    var ecs = Self.init(t.allocator);
    defer ecs.deinit();

    ecs.addSystem(&system.moveRight, null);

    const e1 = try ecs.newEntity(.{Pos{}});
    const e2 = try ecs.newEntity(.{Pos{ .x = 10 }});
    const e3 = try ecs.newEntity(.{Pos{ .x = -1 }});

    var gs = GameState{ .ecs = ecs };
    try gs.ecs.update(&gs, null);

    const pos1 = ecs.getComponent(Pos, e1).?;
    const pos2 = ecs.getComponent(Pos, e2).?;
    const pos3 = ecs.getComponent(Pos, e3).?;
    try t.expectEqual(Pos{ .x = 1 }, pos1.*);
    try t.expectEqual(Pos{ .x = 11 }, pos2.*);
    try t.expectEqual(Pos{}, pos3.*);
}
