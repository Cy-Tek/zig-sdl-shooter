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
const Position = component.Position;
const Velocity = component.Velocity;
const Texture = component.Texture;

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

        _ = try player.addComponent(Health, Health{});
        _ = try player.addComponent(Fighter, Fighter{});
        _ = try player.addComponent(Position, Position{ .x = 100, .y = 100 });
        _ = try player.addComponent(Velocity, Velocity{});

        const texture = try draw.loadTexture("gfx/player.png", app.renderer);
        _ = try player.addComponent(Texture, Texture.init(texture));

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
        const position = self.player.getComponent(Position).?;
        const fighter = self.player.getComponent(Fighter).?;

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

        position.x += velocity.dx;
        position.y += velocity.dy;
    }

    fn fireBullet(self: *@This()) !void {
        const p_texture = self.player.getComponent(Texture).?;
        const p_position = self.player.getComponent(Position).?;
        const p_fighter = self.player.getComponent(Fighter).?;

        var bullet = Entity.init(self.arena.allocator());

        const b_texture = try bullet.addComponent(Texture, Texture.init(self.bullet_texture));
        _ = try bullet.addComponent(Health, Health{ .health = 1 });
        _ = try bullet.addComponent(Velocity, Velocity{ .dx = config.PlayerBulletSpeed });
        _ = try bullet.addComponent(Position, Position{
            .x = p_position.x + p_texture.w,
            .y = p_position.y + @divFloor(p_texture.h, 2) - @divFloor(b_texture.h, 2),
        });


        self.bullets.append(bullet) catch std.log.err("Could not append bullet", .{});

        p_fighter.reload = 8;
    }

    fn processBullets(self: *@This()) void {
        var i: usize = 0;
        while (i < self.bullets.items.len) : (i += 1) {
            const bullet = &self.bullets.items[i];
            var position = bullet.getComponent(Position).?;
            var velocity = bullet.getComponent(Velocity).?;

            position.x += velocity.dx;
            position.y += velocity.dy;

            if (position.x > config.ScreenWidth) {
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

        var tex = try enemy.addComponent(Texture, Texture.init(self.enemy_texture));
        var pos = try enemy.addComponent(Position, .{ .x = config.ScreenWidth });
        _ = try enemy.addComponent(Velocity, .{ .dx = -random.intRangeAtMost(i32, 2, 6 )});

        pos.y = random.intRangeAtMost(i32, 0, config.ScreenHeight - tex.h);

        return enemy;
    }

    fn processEnemies(self: *@This()) void {
        var i: usize = 0;
        while (i < self.enemies.items.len) : (i += 1) {
            var enemy = &self.enemies.items[i];
            const pos = enemy.getComponent(Position).?;
            const vel = enemy.getComponent(Velocity).?;
            const tex = enemy.getComponent(Texture).?;

            pos.x += vel.dx;
            pos.y += vel.dy;

            if (pos.x < -tex.w) {
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
        const pos = self.player.getComponent(Position).?;
        const tex = self.player.getComponent(Texture).?;

        draw.blit(pos, tex, self.app.renderer);
    }

    fn drawBullets(self: *@This()) void {
        for (self.bullets.items) |*bullet| {
            const pos = bullet.getComponent(Position).?;
            const tex = bullet.getComponent(Texture).?;

            draw.blit(pos, tex, self.app.renderer);
        }
    }

    fn drawEnemies(self: *@This()) void {
        for (self.enemies.items) |*enemy| {
            const pos = enemy.getComponent(Position).?;
            const tex = enemy.getComponent(Texture).?;

            draw.blit(pos, tex, self.app.renderer);
        }
    }
};
