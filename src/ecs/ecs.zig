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

    pub fn deinit(self: Self) void {
        self.availableEntities.deinit();
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
const Component = u8;

const IComponentArray = struct {
    const Self = @This();
    const VTable = struct {
        entityDestroyed: *const fn (ptr: *anyopaque, entity: Entity) void,
    };

    ptr: *anyopaque,
    vtable: *const VTable,

    pub fn entityDestroyed(self: Self, entity: Entity) void {
        self.vtable.entityDestroyed(self.ptr, entity);
    }

    pub fn init(ptr: anytype) Self {
        const T = @TypeOf(ptr);
        const ptrInfo = @typeInfo(T);

        assert(ptrInfo == .Pointer);
        assert(@typeInfo(ptrInfo.Pointer.child) == .Struct);

        const vtable = struct {
            fn entityDestroyed(pointer: *anyopaque, entity: Entity) void {
                const self: T = @ptrCast(@alignCast(pointer));
                self.entityDestroyed(entity);
            }
        };

        return Self{
            .ptr = ptr,
            .vtable = &.{
                .entityDestroyed = vtable.entityDestroyed,
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
        // entityToIndex: std.ArrayList(usize),
        // indexToEntity: std.ArrayList(Entity),
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
