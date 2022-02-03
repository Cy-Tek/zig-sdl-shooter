const c = @import("./c.zig");
const App = @import("./app.zig").App;

pub fn prepareScene(app: *App) void {
    _ = c.SDL_SetRenderDrawColor(app.renderer, 96, 128, 255, 255);
    _ = c.SDL_RenderClear(app.renderer);
}

pub fn presentScene(app: *App) void {
    _ = c.SDL_RenderPresent(app.renderer);
}

pub fn loadTexture(filename: []const u8, app: *App) !*c.SDL_Texture {
    var texture: *c.SDL_Texture = undefined;

    c.SDL_LogMessage(c.SDL_LOG_CATEGORY_APPLICATION, c.SDL_LOG_PRIORITY_INFO, "Loading %s", @ptrCast([*]const u8, filename));
    texture = c.IMG_LoadTexture(app.renderer, @ptrCast([*]const u8, filename)) orelse return error.ImageLoadError;

    return texture;
}

pub fn blit(texture: *c.SDL_Texture, x: i32, y: i32, app: *App) void {
    var dest: c.SDL_Rect = c.SDL_Rect{
        .x = x,
        .y = y,
        .w = undefined,
        .h = undefined,
    };

    _ = c.SDL_QueryTexture(texture, null, null, &dest.w, &dest.h);
    _ = c.SDL_RenderCopy(app.renderer, texture, null, &dest);
}
