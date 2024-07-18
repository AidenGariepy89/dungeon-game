const std = @import("std");
const t = std.testing;

const assert = std.debug.assert;

const MAX_ENTITIES = 5000;
const Entity = usize;
const Signature = std.bit_set.ArrayBitSet(usize, MAX_COMPONENTS);

const EntityManager = struct {
    const Self = @This();

    availableEntities: std.ArrayList(Entity),
    signatures: [MAX_ENTITIES]Signature,
    livingEntityCount: usize,

    pub fn init(alloc: std.mem.Allocator) Self {
        var availableEntities = std.ArrayList(Entity).init(alloc);
        for (0..MAX_ENTITIES) |i| {
            availableEntities.append(i) catch unreachable;
        }
        return Self{
            .availableEntities = availableEntities,
            .livingEntityCount = 0,
            .signatures = [_]Signature {Signature.initEmpty()} ** MAX_ENTITIES,
        };
    }

    pub fn deinit(self: *Self) void {
        self.availableEntities.deinit();
        self.* = undefined;
    }

    pub fn createEntity(self: *Self) Entity {
        assert(self.livingEntityCount < MAX_ENTITIES);

        const id = self.availableEntities.orderedRemove(0);
        self.livingEntityCount += 1;

        return id;
    }

    pub fn deleteEntity(self: *Self, entity: Entity) void {
        assert(entity < MAX_ENTITIES);

        self.signatures[entity].setRangeValue(.{ .start = 0, .end = MAX_COMPONENTS }, false);
        self.availableEntities.append(entity) catch unreachable;
        self.livingEntityCount -= 1;
    }

    pub fn setSignature(self: *Self, entity: Entity, sig: Signature) void {
        assert(entity < MAX_ENTITIES);

        self.signatures[entity] = sig;
    }

    pub fn getSignature(self: Self, entity: Entity) Signature {
        assert(entity < MAX_ENTITIES);

        return self.signatures[entity];
    }
};

test "entity manager" {
    var em = EntityManager.init(t.allocator);
    defer em.deinit();

    const entity = em.createEntity();
    em.deleteEntity(entity);
}

test "signatures" {
    var em = EntityManager.init(t.allocator);
    defer em.deinit();

    const sig = Signature.initFull();
    const entity = em.createEntity();
    em.setSignature(entity, sig);

    const get = em.getSignature(entity);
    try t.expect(get.eql(sig));
}

const MAX_COMPONENTS = 32;
const ComponentType = u8;

const IComponentArray = struct {
    const Self = @This();
    const VTable = struct {
        entityDestroyed: *const fn (ptr: *anyopaque, entity: Entity) void,
        deinit: *const fn (ptr: *anyopaque, alloc: ?std.mem.Allocator) void,
    };

    ptr: *anyopaque,
    vtable: *const VTable,

    pub fn entityDestroyed(self: Self, entity: Entity) void {
        self.vtable.entityDestroyed(self.ptr, entity);
    }

    pub fn deinit(self: Self, alloc: ?std.mem.Allocator) void {
        self.vtable.deinit(self.ptr, alloc);
    }

    pub fn init(ptr: anytype) Self {
        const T = @TypeOf(ptr);
        const ptrInfo = @typeInfo(T);

        assert(ptrInfo == .Pointer);
        assert(ptrInfo.Pointer.size == .One);
        assert(@typeInfo(ptrInfo.Pointer.child) == .Struct);

        const vtable = struct {
            fn entityDestroyed(pointer: *anyopaque, entity: Entity) void {
                const self: T = @ptrCast(@alignCast(pointer));
                self.entityDestroyed(entity);
            }
            fn deinit(pointer: *anyopaque, alloc: ?std.mem.Allocator) void {
                const self: T = @ptrCast(@alignCast(pointer));
                self.deinit();

                // feels terrible
                if (alloc) |a| {
                    a.destroy(self);
                }
            }
        };

        return Self{
            .ptr = ptr,
            .vtable = &.{
                .entityDestroyed = vtable.entityDestroyed,
                .deinit = vtable.deinit,
            },
        };
    }
};

fn ComponentArray(T: type) type {
    return struct {
        const Self = @This();
        const EntityToIndexHashMap = std.ArrayHashMap(Entity, usize, std.array_hash_map.AutoContext(Entity), false);
        const IndexToEntityHashMap = std.ArrayHashMap(usize, Entity, std.array_hash_map.AutoContext(usize), false);

        componentList: [MAX_ENTITIES]T,
        entityToIndex: EntityToIndexHashMap,
        indexToEntity: IndexToEntityHashMap,
        size: usize,

        pub fn init(alloc: std.mem.Allocator) Self {
            return Self{
                .componentList = undefined,
                .entityToIndex = EntityToIndexHashMap.init(alloc),
                .indexToEntity = IndexToEntityHashMap.init(alloc),
                .size = 0,
            };
        }

        pub fn deinit(self: *Self) void {
            self.entityToIndex.deinit();
            self.indexToEntity.deinit();
            self.* = undefined;
        }

        pub fn insertData(self: *Self, entity: Entity, component: T) !void {
            assert(self.entityToIndex.get(entity) == null);

            const idx = self.size;
            try self.entityToIndex.put(entity, idx);
            try self.indexToEntity.put(idx, entity);
            self.componentList[idx] = component;
            self.size += 1;
        }

        pub fn removeData(self: *Self, entity: Entity) void {
            const idxOfRemoved = self.entityToIndex.get(entity).?;
            const idxOfLast = self.size - 1;
            self.componentList[idxOfRemoved] = self.componentList[idxOfLast];

            const entityOfLast = self.indexToEntity.get(idxOfLast).?;
            self.entityToIndex.put(entityOfLast, idxOfRemoved) catch unreachable;
            self.indexToEntity.put(idxOfRemoved, entityOfLast) catch unreachable;

            _ = self.entityToIndex.swapRemove(entity);
            _ = self.indexToEntity.swapRemove(idxOfLast);

            self.size -= 1;
        }

        pub fn getData(self: *Self, entity: Entity) ?*T {
            const idx = self.entityToIndex.get(entity) orelse return null;
            return &self.componentList[idx];
        }

        pub fn entityDestroyed(self: *Self, entity: Entity) void {
            if (self.entityToIndex.get(entity) != null) {
                self.removeData(entity);
            }
        }

        pub fn getIComponentArray(self: *Self) IComponentArray {
            return IComponentArray.init(self);
        }
    };
}

test "component array dummy data" {
    var compArr = ComponentArray(i32).init(t.allocator);
    defer compArr.deinit();

    const fakeEntity = 5;
    const fakeComponent = 10;
    try compArr.insertData(fakeEntity, fakeComponent);
    const data = compArr.getData(fakeEntity).?;

    try t.expect(data.* == fakeComponent);

    compArr.removeData(fakeEntity);
    try t.expect(compArr.getData(fakeEntity) == null);
}

test "component array interface" {
    var compArr = ComponentArray(i32).init(t.allocator);

    const fakeEntity = 5;
    const fakeComponent = 10;
    try compArr.insertData(fakeEntity, fakeComponent);

    const interface = compArr.getIComponentArray();
    interface.entityDestroyed(fakeEntity);

    try t.expect(compArr.getData(fakeEntity) == null);

    interface.deinit(null);
}

const ComponentManager = struct {
    const Self = @This();
    const ComponentMap = std.StringArrayHashMap(ComponentType);
    const ComponentArrayMap = std.StringArrayHashMap(IComponentArray);

    alloc: std.mem.Allocator,
    componentTypes: ComponentMap,
    componentArrays: ComponentArrayMap,
    nextComponent: ComponentType = 0,

    pub fn init(alloc: std.mem.Allocator) Self {
        return Self{
            .alloc = alloc,
            .componentTypes = ComponentMap.init(alloc),
            .componentArrays = ComponentArrayMap.init(alloc),
        };
    }

    pub fn deinit(self: *Self) void {
        // dont need to free keys in self.componentTypes because it would be a double free
        var arraysIter = self.componentArrays.iterator();
        while (true) {
            const entry = arraysIter.next() orelse break;
            self.alloc.free(entry.key_ptr.*);
            entry.value_ptr.deinit(self.alloc);
        }

        self.componentTypes.deinit();
        self.componentArrays.deinit();

        self.* = undefined;
    }

    pub fn registerComponent(self: *Self, T: type) void {
        const rawStr = @typeName(T);
        const newStr: []u8 = self.alloc.alloc(u8, rawStr.len) catch unreachable;
        std.mem.copyForwards(u8, newStr, rawStr);

        assert(self.componentTypes.get(newStr) == null);

        self.componentTypes.put(newStr, self.nextComponent) catch unreachable;

        const compArr = self.alloc.create(ComponentArray(T)) catch unreachable;
        compArr.* = ComponentArray(T).init(self.alloc);
        self.componentArrays.put(newStr, compArr.getIComponentArray()) catch unreachable;

        self.nextComponent += 1;
    }

    pub fn getComponentType(self: Self, T: type) ?ComponentType {
        const rawStr = @typeName(T);
        const typeName: []const u8 = rawStr.*[0..rawStr.len];

        return self.componentTypes.get(typeName);
    }

    pub fn addComponent(self: *Self, entity: Entity, T: type, component: T) !void {
        try self.getComponentArray(T).?.insertData(entity, component);
    }

    pub fn removeComponent(self: *Self, entity: Entity, T: type) void {
        self.getComponentArray(T).?.removeData(entity);
    }

    pub fn getComponent(self: *Self, entity: Entity, T: type) ?*T {
        return self.getComponentArray(T).?.getData(entity);
    }

    pub fn entityDestroyed(self: *Self, entity: Entity) void {
        var iter = self.componentArrays.iterator();
        var entry = iter.next();
        while (entry != null) : (entry = iter.next()) {
            entry.?.value_ptr.entityDestroyed(entity);
        }
    }

    fn getComponentArray(self: Self, T: type) ?*ComponentArray(T) {
        const rawStr = @typeName(T);
        const typeName: []const u8 = rawStr.*[0..rawStr.len];

        const result = self.componentArrays.get(typeName) orelse return null;

        const ptr: *ComponentArray(T) = @ptrCast(@alignCast(result.ptr));
        return ptr;
    }
};

test "component manager" {
    var cm = ComponentManager.init(t.allocator);
    defer cm.deinit();

    const Pos = struct {
        x: f32,
        y: f32,
    };
    const Sprite = struct {
        idx: u32,
    };

    cm.registerComponent(Pos);
    cm.registerComponent(Sprite);

    const fakeEntity: Entity = 5;
    const data = Pos{ .x = 5, .y = 10 };

    try cm.addComponent(fakeEntity, Pos, data);

    var posRes = cm.getComponent(fakeEntity, Pos);
    try t.expect(posRes != null);
    const entityPosition = posRes.?;
    try t.expect(entityPosition.x == data.x);
    try t.expect(entityPosition.y == data.y);

    const spriteRes = cm.getComponent(fakeEntity, Sprite);
    try t.expect(spriteRes == null);

    cm.removeComponent(fakeEntity, Pos);
    posRes = cm.getComponent(fakeEntity, Pos);
    try t.expect(posRes == null);
}
