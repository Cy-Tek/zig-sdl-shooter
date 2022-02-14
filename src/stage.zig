const std = @import("std");
const c = @import("./c.zig");
const Entity = @import("./entity.zig").Entity;
const App = @import("./app.zig").App;
const draw = @import("./draw.zig");
const config = @import("./consts.zig");
const utils = @import("./utils.zig");
const Allocator = std.mem.Allocator;

const component = @import("./component.zig");
const Fighter = component.Fighter;
const Health = component.Health;
const Velocity = component.Velocity;
const Texture = component.Texture;
const Bounds = component.Bounds;

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
    bullet_texture: *c.SDL_Texture,

    enemies: std.ArrayList(Entity),
    enemy_texture: *c.SDL_Texture,
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
            .player = try initPlayer(app, arena.allocator()),
            .bullets = std.ArrayList(Entity).init(arena.allocator()),
            .bullet_texture = try draw.loadTexture("gfx/playerBullet.png", app.renderer),
            .enemies = std.ArrayList(Entity).init(arena.allocator()),
            .enemy_texture = try draw.loadTexture("gfx/enemy.png", app.renderer),
        };
    }

    pub fn deinit(self: *@This()) void {
        for (self.bullets.items) |*bullet| {
            bullet.deinit();
        }
        self.bullets.deinit();

        for (self.enemies.items) |*enemy| {
            enemy.deinit();
        }
        self.enemies.deinit();

        self.player.deinit();

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

    fn initPlayer(app: *App, alloc: Allocator) !Entity {
        var player = Entity.init(alloc);

        _ = try player.addComponent(Health, .{});
        _ = try player.addComponent(Fighter, .{});
        _ = try player.addComponent(Velocity, .{});
        const bounds = try player.addComponent(Bounds, .{ .x = 100, .y = 100 });

        const texture = try draw.loadTexture("gfx/player.png", app.renderer);
        const tex = try player.addComponent(Texture, .{ .texture = texture });

        tex.getWidthHeight(&bounds.w, &bounds.h);

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
        const velocity = self.player.getComponent(Velocity).?;
        const fighter = self.player.getComponent(Fighter).?;
        const bounds = self.player.getComponent(Bounds).?;

        velocity.* = .{ .dx = 0, .dy = 0 };

        if (fighter.reload > 0) {
            fighter.reload -= 1;
        }

        if (self.app.keyboard[c.SDL_SCANCODE_UP]) {
            velocity.dy = -config.PlayerSpeed;
        }
        if (self.app.keyboard[c.SDL_SCANCODE_DOWN]) {
            velocity.dy = config.PlayerSpeed;
        }
        if (self.app.keyboard[c.SDL_SCANCODE_LEFT]) {
            velocity.dx = -config.PlayerSpeed;
        }
        if (self.app.keyboard[c.SDL_SCANCODE_RIGHT]) {
            velocity.dx = config.PlayerSpeed;
        }
        if (self.app.keyboard[c.SDL_SCANCODE_LCTRL] and fighter.reload == 0) {
            self.fireBullet() catch std.log.err("Could not fire bullet", .{});
        }

        bounds.x += velocity.dx;
        bounds.y += velocity.dy;
    }

    fn fireBullet(self: *@This()) !void {
        const p_bounds = self.player.getComponent(Bounds).?;
        const p_fighter = self.player.getComponent(Fighter).?;

        var bullet = Entity.init(self.arena.allocator());

        const b_texture = try bullet.addComponent(Texture, .{ .texture = self.bullet_texture });
        const b_bounds = try bullet.addComponent(Bounds, .{
            .x = p_bounds.x + p_bounds.w,
        });

        b_texture.getWidthHeight(&b_bounds.w, &b_bounds.h);
        b_bounds.y = p_bounds.y + @divFloor(p_bounds.h, 2) - @divFloor(b_bounds.h, 2);

        _ = try bullet.addComponent(Health, .{ .health = 1 });
        _ = try bullet.addComponent(Velocity, .{ .dx = config.PlayerBulletSpeed });

        self.bullets.append(bullet) catch std.log.err("Could not append bullet", .{});

        p_fighter.reload = 8;
    }

    fn processBullets(self: *@This()) void {
        var i: usize = 0;
        while (i < self.bullets.items.len) : (i += 1) {
            const bullet = &self.bullets.items[i];
            var bounds = bullet.getComponent(Bounds).?;
            var velocity = bullet.getComponent(Velocity).?;

            bounds.x += velocity.dx;
            bounds.y += velocity.dy;

            if (bounds.x > config.ScreenWidth or bounds.x < -bounds.w) {
                _ = self.bullets.swapRemove(i);
                i = if (i == 0) 0 else i - 1; // Reset the index to process the swapped bullet
            }
        }
    }

    fn spawnEnemies(self: *@This()) void {
        var random = self.rand.random();
        self.enemy_spawn_timer -= 1;

        if (self.enemy_spawn_timer <= 0) {
            const enemy = self.createEnemy() catch return std.log.err("Could not create enemy", .{});
            self.enemies.append(enemy) catch std.log.err("Could not append enemy", .{});

            self.enemy_spawn_timer = random.intRangeAtMost(i32, 30, 90);
        }
    }

    fn createEnemy(self: *@This()) !Entity {
        var random = self.rand.random();
        var enemy = Entity.init(self.arena.allocator());

        var tex = try enemy.addComponent(Texture, .{ .texture = self.enemy_texture });
        var bounds = try enemy.addComponent(Bounds, .{ .x = config.ScreenWidth });
        tex.getWidthHeight(&bounds.w, &bounds.h);
        bounds.y = random.intRangeAtMost(i32, 0, config.ScreenHeight - bounds.h);

        _ = try enemy.addComponent(Velocity, .{ .dx = -random.intRangeAtMost(i32, 2, 6) });

        return enemy;
    }

    fn processEnemies(self: *@This()) void {
        var i: usize = 0;
        while (i < self.enemies.items.len) : (i += 1) {
            var enemy = &self.enemies.items[i];
            const bounds = enemy.getComponent(Bounds).?;
            const vel = enemy.getComponent(Velocity).?;

            bounds.x += vel.dx;
            bounds.y += vel.dy;

            if (bounds.x < -bounds.w) {
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
        const bounds = self.player.getComponent(Bounds).?;
        const tex = self.player.getComponent(Texture).?;

        draw.blit(bounds.*, tex.texture, self.app.renderer);
    }

    fn drawBullets(self: *@This()) void {
        for (self.bullets.items) |*bullet| {
            const bounds = bullet.getComponent(Bounds).?;
            const tex = bullet.getComponent(Texture).?;

            draw.blit(bounds.*, tex.texture, self.app.renderer);
        }
    }

    fn drawEnemies(self: *@This()) void {
        for (self.enemies.items) |*enemy| {
            const bounds = enemy.getComponent(Bounds).?;
            const tex = enemy.getComponent(Texture).?;

            draw.blit(bounds.*, tex.texture, self.app.renderer);
        }
    }
};
