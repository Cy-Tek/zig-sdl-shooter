const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
const assert = @import("std").debug.assert;

pub fn main() !void {
    var event: c.SDL_Event = undefined;

    if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    defer c.SDL_Quit();

    const screen = c.SDL_CreateWindow("My SDL Empty Window", c.SDL_WINDOWPOS_UNDEFINED, c.SDL_WINDOWPOS_UNDEFINED, 640, 480, 0) orelse {
        c.SDL_Log("Unable to create window: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyWindow(screen);

    var quit = false;
    while (!quit) {
        if (c.SDL_WaitEvent(&event) == 0) {
            c.SDL_Log("Failed to wait for event: %s", c.SDL_GetError());
            return error.SDLInitializationFailed;
        }

        switch (event.@"type") {
            c.SDL_QUIT => quit = true,
            else => continue,
        }
    }
}