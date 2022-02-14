const std = @import("std");
const utils = @import("./utils.zig");
const c = @import("./c.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;
const test_alloc = std.testing.allocator;
const expectEqual = std.testing.expectEqual;

pub const Manager = struct {
    const Self = @This();

    allocator: Allocator,
    comp_map: AutoHashMap(usize, ErasedComponent),

    pub fn init(allocator: Allocator) Self {
        var comp_map = AutoHashMap(usize, ErasedComponent).init(allocator);

        return .{
            .allocator = allocator,
            .comp_map = comp_map,
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.comp_map.valueIterator();
        while (iter.next()) |wrapper| {
            wrapper.deinit(wrapper.ptr, self.allocator);
        }

        self.comp_map.deinit();
    }

    pub fn addComponent(self: *Self, comptime T: type, parent: T) !*T {
        const id = utils.typeId(T);
        const gop = try self.comp_map.getOrPut(id);

        if (gop.found_existing) {
            _ = self.removeComponent(T);
        }

        var new_ptr = try self.allocator.create(T);
        errdefer self.allocator.destroy(new_ptr);

        new_ptr.* = parent;
        gop.value_ptr.* = ErasedComponent{
            .ptr = new_ptr,
            .deinit = (struct {
                pub fn deinit(erased: *anyopaque, allocator: Allocator) void {
                    var ptr = ErasedComponent.cast(erased, T);
                    allocator.destroy(ptr);
                }
            }).deinit,
        };

        return new_ptr;
    }

    pub fn removeComponent(self: *Self, comptime T: type) ?T {
        const id = utils.typeId(T);
        const kv = self.comp_map.fetchRemove(id) orelse return null;
        const wrapper = kv.value;
        const component = ErasedComponent.cast(wrapper.ptr, T).*;

        wrapper.deinit(wrapper.ptr, self.allocator);

        return component;
    }

    pub fn getComponent(self: *Self, comptime T: type) ?*T {
        const id = utils.typeId(T);
        var wrapper: ErasedComponent = self.comp_map.get(id) orelse return null;
        return ErasedComponent.cast(wrapper.ptr, T);
    }
};

const ErasedComponent = struct {
    ptr: *anyopaque,
    deinit: fn (erased: *anyopaque, allocator: Allocator) void,

    pub fn cast(ptr: *anyopaque, comptime T: type) *T {
        return utils.castTo(T, ptr);
    }
};

pub const Health = struct {
    health: i32 = 0,
};

pub const Fighter = struct {
    reload: i32 = 0,
};

pub const Velocity = struct {
    dx: i32 = 0,
    dy: i32 = 0,
};

pub const Bounds = struct {
    x: i32 = 0,
    y: i32 = 0,
    w: i32 = 0,
    h: i32 = 0,

    pub fn isColliding(self: @This(), other: Bounds) bool {
        const x_check = @maximum(self.x, other.x) < @minimum(self.x + self.w, other.x + other.w);
        const y_check = @maximum(self.y, other.y) < @minimum(self.y + self.h, other.y + other.h);

        return x_check and y_check;
    }
};

pub const Texture = struct {
    texture: *c.SDL_Texture,

    pub fn getWidthHeight(self: @This(), w: *i32, h: *i32) void {
        _ = c.SDL_QueryTexture(self.texture, null, null, w, h);
    }
};

test "Add a component" {
    var manager = Manager.init(test_alloc);
    defer manager.deinit();

    const health: Health = .{ .health = 100 };

    _ = try manager.addComponent(Health, health);
    try expectEqual(manager.comp_map.count(), 1);
}

test "Get a component" {
    var manager = Manager.init(test_alloc);
    defer manager.deinit();

    const health: Health = .{ .health = 50 };

    _ = try manager.addComponent(Health, health);
    const comp = manager.getComponent(Health).?;

    try expectEqual(comp.health, 50);
}

test "Modify a component" {
    var manager = Manager.init(test_alloc);
    defer manager.deinit();

    _ = try manager.addComponent(Health, .{ .health = 50 });
    const component = manager.getComponent(Health).?;

    component.health = 2000;

    try expectEqual(component.health, 2000);
}

test "Add two components" {
    var manager = Manager.init(test_alloc);
    defer manager.deinit();

    _ = try manager.addComponent(Health, .{ .health = 50 });
    _ = try manager.addComponent(Bounds, .{ .x = 100, .y = 100 });

    try expectEqual(manager.comp_map.count(), 2);

    const managedBounds = manager.getComponent(Bounds).?;
    const managedHealth = manager.getComponent(Health).?;

    try expectEqual(managedHealth.health, 50);
    try expectEqual(managedBounds.x, 100);
}

test "Remove component" {
    var manager = Manager.init(test_alloc);
    defer manager.deinit();

    _ = try manager.addComponent(Health, .{ .health = 50 });
    _ = try manager.addComponent(Bounds, .{});

    const c_health = manager.removeComponent(Health).?;

    try expectEqual(manager.comp_map.count(), 1);
    try expectEqual(c_health.health, 50);
}
