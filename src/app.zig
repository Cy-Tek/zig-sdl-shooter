const std = @import("std");
const c = @import("./c.zig");
const config = @import("./consts.zig");
const stage = @import("./stage.zig");

pub const App = struct {
    const Self = @This();

    renderer: *c.SDL_Renderer,
    window: *c.SDL_Window,
    keyboard: [config.MaxKeyboardKeys]bool,
    level: ?stage.Level,

    pub fn init() !Self {
        try initSDL();

        var self = Self{
            .renderer = undefined,
            .window = undefined,
            .keyboard = [_]bool{false} ** config.MaxKeyboardKeys,
            .level = null,
        };

        const window_flags = 0;
        const renderer_flags = c.SDL_RENDERER_ACCELERATED;

        self.window = c.SDL_CreateWindow("Shooter 01", c.SDL_WINDOWPOS_UNDEFINED, c.SDL_WINDOWPOS_UNDEFINED, config.ScreenWidth, config.ScreenHeight, window_flags) orelse {
            c.SDL_Log("Couldn't initialize SDL Window: %s\n", c.SDL_GetError);
            return error.SDLInitializationFailure;
        };
        errdefer c.SDL_DestroyWindow(self.window);

        self.renderer = c.SDL_CreateRenderer(self.window, -1, renderer_flags) orelse {
            c.SDL_Log("Couldn't initialize SDL Window: %s\n", c.SDL_GetError);
            return error.SDLInitializationFailure;
        };
        errdefer c.SDL_DestroyRenderer(self.renderer);

        // Initialize SDL Image
        if (c.IMG_Init(c.IMG_INIT_PNG | c.IMG_INIT_JPG) == 0) {
            c.SDL_Log("Couldn't initialize SDL Image: %s\n", c.SDL_GetError);
            return error.SDLInitializationFailure;
        }

        return self;
    }

    fn initSDL() !void {
        if (c.SDL_Init(c.SDL_INIT_VIDEO) < 0) {
            c.SDL_Log("Couldn't initialize SDL: %s\n", c.SDL_GetError);
            return error.SDLInitializationFailure;
        }
        errdefer c.SDL_Quit();

        if (c.SDL_SetHint(c.SDL_HINT_RENDER_SCALE_QUALITY, "linear") == c.SDL_FALSE) {
            c.SDL_Log("Couldn't set hint for render scale quality: %s\n", c.SDL_GetError());
            return error.SDLInitializationFailure;
        }
    }

    pub fn deinit(self: *Self) void {
        c.SDL_DestroyRenderer(self.renderer);
        c.SDL_DestroyWindow(self.window);
        c.SDL_Quit();
    }

    pub fn handle_input(self: *Self) bool {
        var event: c.SDL_Event = undefined;

        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.@"type") {
                c.SDL_QUIT => return true,
                c.SDL_KEYDOWN => self.handleKeyDown(event.key),
                c.SDL_KEYUP => self.handleKeyUp(event.key),
                else => {},
            }
        }

        return false;
    }

    fn handleKeyDown(self: *Self, event: c.SDL_KeyboardEvent) void {
        const code = @intCast(u64, event.keysym.scancode);
        if (event.repeat == 0 and code < config.MaxKeyboardKeys) {
            self.keyboard[code] = true;
        }
    }

    fn handleKeyUp(self: *Self, event: c.SDL_KeyboardEvent) void {
        const code = @intCast(u64, event.keysym.scancode);
        if (event.repeat == 0 and code < config.MaxKeyboardKeys) {
            self.keyboard[code] = false;
        }
    }
};
