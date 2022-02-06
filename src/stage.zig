const std = @import("std");
const c = @import("./c.zig");
const Entity = @import("./entity.zig").Entity;
const App = @import("./app.zig").App;
const draw = @import("./draw.zig");
const config = @import("./consts.zig");
const utils = @import("./utils.zig");
const Allocator = std.mem.Allocator;

pub const Level = struct {
    stage: *anyopaque,

    logicFn: fn (*anyopaque) void,
    drawFn: fn (*anyopaque) void,

    pub fn logic(level: *const Level) void {
        level.logicFn(level.stage);
    }

    pub fn draw(level: *const Level) void {
        level.drawFn(level.stage);
    }
};

pub const Stage = struct {
    app: *App,
    arena: *std.heap.ArenaAllocator,
    rand: std.rand.Xoshiro256,
    player: Entity,

    bullets: std.ArrayList(Entity),
    bulletTexture: *c.SDL_Texture,

    enemies: std.ArrayList(Entity),
    enemyTexture: *c.SDL_Texture,
    enemy_spawn_timer: i32 = 0,

    pub fn init(app: *App) !Stage {
        var seed: u64 = undefined;
        try std.os.getrandom(std.mem.asBytes(&seed));

        var arena = try std.heap.page_allocator.create(std.heap.ArenaAllocator);
        arena.* = std.heap.ArenaAllocator.init(std.heap.page_allocator);

        return Stage{
            .app = app,
            .arena = arena,
            .rand = std.rand.DefaultPrng.init(seed),
            .player = try initPlayer(app),
            .bullets = std.ArrayList(Entity).init(arena.allocator()),
            .bulletTexture = try draw.loadTexture("gfx/playerBullet.png", app.renderer),
            .enemies = std.ArrayList(Entity).init(arena.allocator()),
            .enemyTexture = try draw.loadTexture("gfx/enemy.png", app.renderer),
        };
    }

    pub fn deinit(self: *@This()) void {
        self.bullets.deinit();
        self.enemies.deinit();
        self.arena.deinit();
        std.heap.page_allocator.destroy(self.arena);
    }

    pub fn level(self: *@This()) Level {
        return .{
            .stage = @ptrCast(*anyopaque, self),
            .logicFn = logic,
            .drawFn = drawEntities,
        };
    }

    fn initPlayer(app: *App) !Entity {
        var player = Entity{ .x = 100, .y = 100, .texture = try draw.loadTexture("gfx/player.png", app.renderer) };

        player.setWidthHeightFromTex();

        return player;
    }

    fn logic(self_ptr: *anyopaque) void {
        var self = utils.castTo(Stage, self_ptr);

        self.processPlayer();

        self.processEnemies();

        self.processBullets();

        self.spawnEnemies();
    }

    fn processPlayer(self: *@This()) void {
        self.player.dx = 0;
        self.player.dy = 0;

        if (self.player.reload > 0) {
            self.player.reload -= 1;
        }

        if (self.app.keyboard[c.SDL_SCANCODE_UP]) {
            self.player.dy = -config.PlayerSpeed;
        }
        if (self.app.keyboard[c.SDL_SCANCODE_DOWN]) {
            self.player.dy = config.PlayerSpeed;
        }
        if (self.app.keyboard[c.SDL_SCANCODE_LEFT]) {
            self.player.dx = -config.PlayerSpeed;
        }
        if (self.app.keyboard[c.SDL_SCANCODE_RIGHT]) {
            self.player.dx = config.PlayerSpeed;
        }
        if (self.app.keyboard[c.SDL_SCANCODE_LCTRL] and self.player.reload == 0) {
            self.fireBullet();
        }

        self.player.x += self.player.dx;
        self.player.y += self.player.dy;
    }

    fn fireBullet(self: *@This()) void {
        var bullet = Entity{
            .x = self.player.x + self.player.w,
            .y = self.player.y,
            .dx = config.PlayerBulletSpeed,
            .health = 1,
            .texture = self.bulletTexture,
        };

        bullet.setWidthHeightFromTex();
        bullet.y += @divFloor(self.player.h, 2) - @divFloor(bullet.h, 2);

        self.bullets.append(bullet) catch std.log.err("Could not append bullet", .{});

        self.player.reload = 8;
    }

    fn processBullets(self: *@This()) void {
        var i: usize = 0;
        while (i < self.bullets.items.len) : (i += 1) {
            var bullet = &self.bullets.items[i];
            bullet.x += bullet.dx;
            bullet.y += bullet.dy;

            if (bullet.x > config.ScreenWidth) {
                _ = self.bullets.swapRemove(i);
                i = if (i == 0) 0 else i - 1; // Reset the index to process the swapped bullet
            }
        }
    }

    fn spawnEnemies(self: *@This()) void {
        var random = self.rand.random();
        self.enemy_spawn_timer -= 1;

        if (self.enemy_spawn_timer <= 0) {
            var enemy = Entity{
                .x = config.ScreenWidth,
                .y = undefined,
                .dx = -random.intRangeAtMost(i32, 2, 6),
                .texture = self.enemyTexture,
            };

            enemy.setWidthHeightFromTex();
            enemy.y = random.intRangeAtMost(i32, 0, config.ScreenHeight - enemy.h);

            self.enemies.append(enemy) catch std.log.err("Could not append enemy", .{});

            self.enemy_spawn_timer = random.intRangeAtMost(i32, 30, 90);
        }
    }

    fn processEnemies(self: *@This()) void {
        var i: usize = 0;
        while (i < self.enemies.items.len) : (i += 1) {
            var enemy = &self.enemies.items[i];
            enemy.x += enemy.dx;
            enemy.y += enemy.dy;

            if (enemy.x < -enemy.w) {
                _ = self.enemies.swapRemove(i);
                i = if (i == 0) 0 else i - 1;
            }
        }
    }

    fn drawEntities(self_ptr: *anyopaque) void {
        var self = utils.castTo(Stage, self_ptr);

        self.drawPlayer();
        self.drawEnemies();
        self.drawBullets();
    }

    fn drawPlayer(self: *@This()) void {
        draw.blit(self.player, self.app.renderer);
    }

    fn drawBullets(self: *@This()) void {
        for (self.bullets.items) |bullet| {
            draw.blit(bullet, self.app.renderer);
        }
    }

    fn drawEnemies(self: *@This()) void {
        for (self.enemies.items) |enemy| {
            draw.blit(enemy, self.app.renderer);
        }
    }
};
