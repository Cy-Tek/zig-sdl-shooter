const std = @import("std");
const Allocator = std.mem.Allocator;

const comp = @import("./component.zig");

pub const Entity = struct {
    components: comp.Manager,

    pub fn init(alloc: Allocator) Entity {
        return .{
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