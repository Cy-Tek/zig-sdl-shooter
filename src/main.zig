const c = @import("./c.zig");
const application = @import("./app.zig");
const App = application.App;
const draw = @import("./draw.zig");
const Entity = @import("./entity.zig").Entity;
const std = @import("std");
const stage = @import("./stage.zig");

pub fn main() !void {
    var app = try App.init();
    defer app.deinit();

    var new_stage = try stage.Stage.init(&app);
    defer new_stage.deinit();

    app.level = new_stage.level();

    var quit: bool = false;
    while (!quit) {
        draw.prepareScene(app.renderer);

        quit = app.handle_input();

        if (app.level) |level| {
            level.logic();
            level.draw();
        }

        draw.presentScene(app.renderer);
        c.SDL_Delay(16);
    }
}
