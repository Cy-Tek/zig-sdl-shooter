const std = @import("std");
const Allocator = std.mem.Allocator;
const Side = @import("./consts.zig").Side;

const comp = @import("./component.zig");
const Position = comp.Position;
const Texture = comp.Texture;

pub const Entity = struct {
    components: comp.Manager,
    side: Side,

    pub fn init(side: Side, alloc: Allocator) Entity {
        return .{
            .side = side,
            .components = comp.Manager.init(alloc),
        };
    }

    pub fn deinit(self: *@This()) void {
        self.components.deinit();
    }

    pub fn addComponent(self: *@This(), comptime T: type, component: T) !*T {
        return try self.components.addComponent(T, component);
    }

    pub fn getComponent(self: *@This(), comptime ComponentType: type) ?*ComponentType {
        return self.components.getComponent(ComponentType);
    }
};
