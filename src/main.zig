const c = @import("./c.zig");
const App = @import("./app.zig").App;
const draw = @import("./draw.zig");
const Entity = @import("./entity.zig").Entity;

pub fn main() !void {
    var app = try App.init();
    defer app.deinit();

    var player = Entity{
        .x = 100,
        .y = 100,
        .texture = try draw.loadTexture("gfx/player.png", &app),
    };

    var quit: bool = false;
    while (!quit) {
        draw.prepareScene(&app);

        quit = app.handle_input();

        movePlayer(&player, app);

        draw.blit(player.texture, player.x, player.y, &app);

        draw.presentScene(&app);

        c.SDL_Delay(16);
    }
}

fn movePlayer(player: *Entity, app: App) void {
    if (app.up != 0) {
        player.y -= 4;
    }

    if (app.down != 0) {
        player.y += 4;
    }

    if (app.left != 0) {
        player.x -= 4;
    }

    if (app.right != 0) {
        player.x += 4;
    }
}
