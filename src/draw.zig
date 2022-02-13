const c = @import("./c.zig");
const App = @import("./app.zig").App;
const Entity = @import("./entity.zig").Entity;
const component = @import("./component.zig");
const Texture = component.Texture;
const Position = component.Position;

pub fn prepareScene(renderer: *c.SDL_Renderer) void {
    _ = c.SDL_SetRenderDrawColor(renderer, 32, 32, 32, 255);
    _ = c.SDL_RenderClear(renderer);
}

pub fn presentScene(renderer: *c.SDL_Renderer) void {
    _ = c.SDL_RenderPresent(renderer);
}

pub fn loadTexture(filename: []const u8, renderer: *c.SDL_Renderer) !*c.SDL_Texture {
    var texture: *c.SDL_Texture = undefined;

    c.SDL_LogMessage(c.SDL_LOG_CATEGORY_APPLICATION, c.SDL_LOG_PRIORITY_INFO, "Loading %s", @ptrCast([*]const u8, filename));
    texture = c.IMG_LoadTexture(renderer, @ptrCast([*]const u8, filename)) orelse return error.ImageLoadError;

    return texture;
}

pub fn blit(pos: *Position, tex: *Texture, renderer: *c.SDL_Renderer) void {
    var dest: c.SDL_Rect = c.SDL_Rect{
        .x = pos.x,
        .y = pos.y,
        .w = tex.w,
        .h = tex.h,
    };

    _ = c.SDL_RenderCopy(renderer, tex.texture, null, &dest);
}
