const std = @import("std");
const utils = @import("./utils.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;
const test_alloc = std.testing.allocator;
const expect = std.testing.expect;

pub const ComponentManager = struct {
    const Self = @This();

    allocator: Allocator,
    comp_map: AutoHashMap(usize, Component),
    type_map: AutoHashMap(usize, ErasedWrapper),

    pub fn init(allocator: Allocator) Self {
        var comp_map = AutoHashMap(usize, Component).init(allocator);
        var type_map = AutoHashMap(usize, ErasedWrapper).init(allocator);

        return .{
            .allocator = allocator,
            .comp_map = comp_map,
            .type_map = type_map,
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.type_map.valueIterator();
        while (iter.next()) |wrapper| {
            wrapper.deinit(wrapper.ptr, self.allocator);
        }

        self.comp_map.deinit();
        self.type_map.deinit();
    }

    pub fn addComponent(self: *Self, parent: anytype) !void {
        const T = @TypeOf(parent);
        const id = utils.typeId(T);
        const gop = try self.type_map.getOrPut(id);

        if (gop.found_existing) return;

        var new_ptr = try self.allocator.create(T);
        errdefer self.allocator.destroy(new_ptr);

        new_ptr.* = parent;
        gop.value_ptr.* = ErasedWrapper{
            .ptr = new_ptr,
            .deinit = (struct {
                pub fn deinit(erased: *anyopaque, allocator: Allocator) void {
                    var ptr = ErasedWrapper.cast(erased, T);
                    allocator.destroy(ptr);
                }
            }).deinit,
        };

        try self.comp_map.put(id, new_ptr.component());
    }

    pub fn getComponent(self: *Self, comptime T: type) ?*T {
        const id = utils.typeId(T);
        var component: Component = self.comp_map.get(id) orelse return null;
        return component.get(T);
    }
};


pub const ErasedWrapper = struct {
    ptr: *anyopaque,
    deinit: fn (erased: *anyopaque, allocator: Allocator) void,

    pub fn cast(ptr: *anyopaque, comptime T: type) *T {
        return utils.castTo(T, ptr);
    }
};

pub const Component = struct {
    const Self = @This();

    parent: *anyopaque,

    pub fn init(parent: anytype) Component {
        return .{
            .parent = @ptrCast(*anyopaque, parent)
        };
    }

    pub fn get(self: *Self, comptime T: type) *T {
        return utils.castTo(T, self.parent);
    }
};

pub const HealthComponent = struct {
    const Self = @This();

    health: i32,

    pub fn component(self: *Self) Component {
        return Component.init(self);
    }
};

pub const PositionComponent = struct {
    const Self = @This();

    x: i32,
    y: i32,

    pub fn component(self: *Self) Component {
        return Component.init(self);
    }
};

test "Add a component" {
    var manager = ComponentManager.init(test_alloc);
    defer manager.deinit();

    const health: HealthComponent = .{ .health = 100 };

    try manager.addComponent(health);
    try expect(manager.comp_map.count() == 1);
}

test "Get a component" {
    var manager = ComponentManager.init(test_alloc);
    defer manager.deinit();

    const health: HealthComponent = .{ .health = 50 };

    try manager.addComponent(health);
    const comp = manager.getComponent(HealthComponent).?;

    try expect(comp.health == 50);
}

test "Modify a component" {
    var manager = ComponentManager.init(test_alloc);
    defer manager.deinit();

    try manager.addComponent(HealthComponent{ .health = 50 });
    const component = manager.getComponent(HealthComponent).?;

    component.health = 2000;

    try expect(component.health == 2000);
}

test "Add two components" {
    var manager = ComponentManager.init(test_alloc);
    defer manager.deinit();

    const health = HealthComponent{ .health = 50 };
    const position = PositionComponent{ .x = 100, .y = 100 };

    try manager.addComponent(health);
    try manager.addComponent(position);

    try expect(manager.comp_map.count() == 2);

    const managedPosition = manager.getComponent(PositionComponent).?;
    const managedHealth = manager.getComponent(HealthComponent).?;

    try expect(managedHealth.health == 50);
    try expect(managedPosition.x == 100 and managedPosition.y == 100);
}