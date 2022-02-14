const c = @import("./c.zig");
const App = @import("./app.zig").App;
const Entity = @import("./entity.zig").Entity;
const component = @import("./component.zig");
const Texture = component.Texture;
const Bounds = component.Bounds;

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

pub fn blit(bounds: Bounds, tex: *c.SDL_Texture, renderer: *c.SDL_Renderer) void {
    var dest: c.SDL_Rect = c.SDL_Rect{
        .x = bounds.x,
        .y = bounds.y,
        .w = bounds.w,
        .h = bounds.h,
    };

    _ = c.SDL_RenderCopy(renderer, tex, null, &dest);
}
