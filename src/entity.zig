const c = @import("./c.zig");

pub const Entity = struct {
    x: i32,
    y: i32,
    texture: *c.SDL_Texture,
};