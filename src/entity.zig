const c = @import("./c.zig");

pub const Entity = struct {
    x: i32 = 0,
    y: i32 = 0,
    w: i32 = 0,
    h: i32 = 0,
    dx: i32 = 0,
    dy: i32 = 0,
    health: i32 = 0,
    reload: i32 = 0,
    texture: *c.SDL_Texture,

    pub fn setWidthHeightFromTex(self: *@This()) void {
        _ = c.SDL_QueryTexture(self.texture, null, null, &self.w, &self.h);
    }
};