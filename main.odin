package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

PlayerState :: enum {
    idle,
    walking,
    jumping,
}

Player :: struct {
    position: rl.Vector2,
    size: rl.Vector2,
    hitbox: rl.Rectangle,
    faceDirection: rl.Vector2,
    velocity: rl.Vector2,
    state: PlayerState,
    isGrounded: bool,
    jumpHeight: f32,
    horizontalSpeed: f32,
    jumpStartPosition: rl.Vector2,
    jumpLandPosition: rl.Vector2,
    textures: [4]rl.Texture,
    walkStepStartTime: f64,
    walkStepTime: f64,
    walkStepDuration: f64,
    walkStepOdd: bool
}

Platform :: struct {
    position: rl.Vector2,
    size: rl.Vector2,
    hitbox: rl.Rectangle,
    texture: rl.Texture
}

groundTexture: rl.Texture
playerTexture: rl.Texture
gravity:f32 = 9.8 * 64
showHelpers := false

createPlatform :: proc(position: rl.Vector2, width: f32) -> Platform {
    size := rl.Vector2{width, 128}
    hitbox := rl.Rectangle{position.x - size.x * 0.5, position.y - size.y, size.x, size.y}
    texture := groundTexture

    return { position, size, hitbox, texture }
}

drawPlatform :: proc(platform: Platform) {
    source := rl.Rectangle{0, 0, platform.size.x, platform.size.y}
    dest := rl.Rectangle{platform.position.x - platform.size.x * 0.5, platform.position.y - platform.size.y, platform.size.x, platform.size.y}
    origin := rl.Vector2{0, 0}
    rotation:f32 = 0

    rl.DrawTexturePro(platform.texture, source, dest, origin, rotation, rl.WHITE)

    if showHelpers {
        rl.DrawRectangleLinesEx(platform.hitbox, 1, rl.RED)
        rl.DrawCircle(i32(platform.position.x), i32(platform.position.y), 5, rl.RED)
    }
}

createPlayer :: proc(position: rl.Vector2) -> Player {
    player:Player

    player.position = position
    player.size = rl.Vector2{128, 256}
    player.hitbox = rl.Rectangle{position.x - player.size.x * 0.5, position.y - player.size.y, player.size.x, player.size.y}
    player.textures[0] = rl.LoadTexture("assets/PNG/Players/128x256/Beige/alienBeige_front.png")
    player.textures[1] = rl.LoadTexture("assets/PNG/Players/128x256/Beige/alienBeige_walk1.png")
    player.textures[2] = rl.LoadTexture("assets/PNG/Players/128x256/Beige/alienBeige_walk2.png")
    player.textures[3] = rl.LoadTexture("assets/PNG/Players/128x256/Beige/alienBeige_jump.png")
    player.jumpHeight = 256
    player.horizontalSpeed = 128
    player.walkStepDuration = 0.2

    return player
}

destroyPlayer :: proc(player: Player) {
    for texture in player.textures {
        rl.UnloadTexture(texture)
    }
}

drawPlayer :: proc(player: Player) {
    texture: rl.Texture = player.textures[0]
    dest := rl.Rectangle{player.position.x - player.size.x * 0.5, player.position.y - player.size.y, player.size.x, player.size.y}
    source := rl.Rectangle{0, 0, player.size.x, player.size.y}
    origin := rl.Vector2{0, 0}
    rotation: f32 = 0

    if player.isGrounded {
        if player.faceDirection.x != 0 {
            if player.walkStepOdd {
                texture = player.textures[2]
            } else {
                texture = player.textures[1]
            }
        }
    } else {
        texture = player.textures[3]
    }

    if player.faceDirection.x < 0 {
        source.x = source.width
        source.width = -source.width
    }

    rl.DrawTexturePro(texture, source, dest, origin, rotation, rl.WHITE)

    if showHelpers {
        rl.DrawRectangleLinesEx(player.hitbox, 1, rl.RED)
        rl.DrawCircle(i32(player.position.x), i32(player.position.y), 5, rl.RED)
    }
}

main :: proc() {
    rl.InitWindow(1920, 1080, "Platformer with Raylib")
    defer rl.CloseWindow()
    rl.SetTargetFPS(144)

    groundTexture = rl.LoadTexture("assets/PNG/Ground/Grass/grassMid.png")
    defer rl.UnloadTexture(groundTexture)

    // playerTexture = rl.LoadTexture("assets/PNG/Players/128x256/Beige/alienBeige_stand.png")
    // defer rl.UnloadTexture(playerTexture)

    ground := createPlatform({f32(rl.GetScreenWidth()) * 0.5, f32(rl.GetScreenHeight())}, f32(rl.GetScreenWidth()))
    player := createPlayer({f32(rl.GetScreenWidth()) * 0.5, ground.hitbox.y})
    defer destroyPlayer(player)

    for !rl.WindowShouldClose() {
        dt := rl.GetFrameTime()
        playerVelocityX:f32 = 0

        if rl.IsKeyPressed(rl.KeyboardKey.F) {
            rl.TakeScreenshot(cstring("screenshot.png"))
        }

        if rl.IsKeyDown(rl.KeyboardKey.LEFT) {
            player.faceDirection.x = -1
            playerVelocityX = player.faceDirection.x * player.horizontalSpeed
        }

        if rl.IsKeyDown(rl.KeyboardKey.RIGHT) {
            player.faceDirection.x = 1
            playerVelocityX = player.faceDirection.x * player.horizontalSpeed
        }

        if player.velocity.x == 0 && playerVelocityX != 0 {
            player.walkStepStartTime = rl.GetTime()
        }

        player.velocity.x = playerVelocityX

        if rl.CheckCollisionRecs(player.hitbox, ground.hitbox) {
            player.velocity.y = 0
            player.position.y = ground.hitbox.y
            player.isGrounded = true

            if rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
                initialVelocity := -math.sqrt_f32(2 * gravity * player.jumpHeight)
                player.velocity.y = initialVelocity
                player.jumpStartPosition = player.position
            }
        } else {
            player.isGrounded = false
            player.velocity.y += gravity * dt
            player.jumpLandPosition.x = player.position.x + player.velocity.x * dt
            player.jumpLandPosition.y = 0
        }

        player.position += player.velocity * dt
        player.hitbox.x = player.position.x - player.size.x * 0.5
        player.hitbox.y = player.position.y - player.size.y + 1

        if player.velocity.x != 0 {
            player.walkStepTime = rl.GetTime() - player.walkStepStartTime
        }

        if player.walkStepTime >= player.walkStepDuration {
            player.walkStepOdd = !player.walkStepOdd
            player.walkStepStartTime = rl.GetTime()
        }

        rl.BeginDrawing()
        rl.ClearBackground(rl.SKYBLUE)

        drawPlatform(ground)

        drawPlayer(player)

        if showHelpers {
            gridY := f32(rl.GetScreenHeight())
            screenCenterX := f32(rl.GetScreenWidth()) * 0.5
            for gridY > 0 {
                gridY -= 32
                // relativeY := (f32(rl.GetScreenHeight()) - gridY)

                lineWidth := 10
                start := rl.Vector2{screenCenterX, gridY}
                end := rl.Vector2{screenCenterX + f32(lineWidth), gridY}
                relativeY := ground.hitbox.y - gridY

                rl.DrawLineEx(start, end, 2, rl.WHITE)
                rl.DrawText(fmt.ctprintf("%0.1fpx", relativeY), i32(end.x + 10), i32(end.y - 16), 20, rl.WHITE)
            }

            rl.DrawText(fmt.ctprintf("Vertical Velocity %f", player.velocity.y), 10, 10, 20, rl.YELLOW)
            rl.DrawText(fmt.ctprintf("Is Grounded %s", player.isGrounded), 10, 30, 20, rl.YELLOW)
            rl.DrawText(fmt.ctprintf("Walk step time %f", player.walkStepTime), 10, 50, 20, rl.YELLOW)
        }

        rl.EndDrawing()
    }
}