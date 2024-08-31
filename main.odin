package main

import "core:fmt"
import "core:path/filepath"
import "core:strings"
import "core:math"
import rl "vendor:raylib"

PlayerStyle :: enum {
    beige,
    blue,
    green,
    pink,
    yellow
}

PlayerState :: enum {
    idle,
    walking,
    jumping,
    ducking,
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
    texture: rl.Texture,
    walkAnimationTime: f32,
    style: PlayerStyle
}

Platform :: struct {
    position: rl.Vector2,
    size: rl.Vector2,
    hitbox: rl.Rectangle,
    texture: rl.Texture,
    textureRect: rl.Rectangle,
}

groundTextures: rl.Texture
playerTextures: rl.Texture
gravity:f32 = 9.8 * 64
showHelpers := true

createPlatform :: proc(position: rl.Vector2, width: f32) -> Platform {
    size := rl.Vector2{width, 128}
    hitbox := rl.Rectangle{position.x - size.x * 0.5, position.y - size.y, size.x, size.y}
    texture := groundTextures
    textureRect := rl.Rectangle{128, 384, 128, 128}

    return { position, size, hitbox, texture, textureRect }
}

drawPlatform :: proc(platform: Platform) {
    source := rl.Rectangle{0, 0, platform.size.x, platform.size.y}
    dest := rl.Rectangle{platform.position.x - platform.size.x * 0.5, platform.position.y - platform.size.y, platform.size.x, platform.size.y}
    origin := rl.Vector2{0, 0}
    rotation:f32 = 0

    rl.DrawTexturePro(platform.texture, platform.textureRect, dest, origin, rotation, rl.WHITE)

    if showHelpers {
        rl.DrawRectangleLinesEx(platform.hitbox, 1, rl.RED)
        rl.DrawCircle(i32(platform.position.x), i32(platform.position.y), 5, rl.RED)
    }
}

createPlayer :: proc(position: rl.Vector2, style: PlayerStyle) -> Player {
    player:Player

    player.position = position
    player.size = rl.Vector2{128, 256}
    player.hitbox = rl.Rectangle{position.x - player.size.x * 0.5, position.y - player.size.y, player.size.x, player.size.y}
    player.texture = playerTextures
    player.style = style
    player.jumpHeight = 256
    player.horizontalSpeed = 128
    player.walkAnimationTime = 0

    return player
}

drawPlayer :: proc(player: Player) {
    texture := player.texture
    dest := rl.Rectangle{player.position.x - player.size.x * 0.5, player.position.y - player.size.y, player.size.x, player.size.y}
    origin := rl.Vector2{0, 0}
    rotation: f32 = 0
    textureIndex := 0
    textureRects: [5]rl.Rectangle

    switch player.style {
        case .beige:
            textureRects[0] = rl.Rectangle{0, 1024, 128, 256} // stand
            textureRects[1] = rl.Rectangle{0, 256, 128, 256}  // walk1
            textureRects[2] = rl.Rectangle{0, 0, 128, 256}    // walk2
            textureRects[3] = rl.Rectangle{0, 1280, 128, 256} // jump
            textureRects[4] = rl.Rectangle{128, 0, 128, 256} // duck
        case .blue:
            textureRects[0] = rl.Rectangle{768, 0, 128, 256} // stand
            textureRects[1] = rl.Rectangle{640, 1280, 128, 256}  // walk1
            textureRects[2] = rl.Rectangle{640, 1024, 128, 256}    // walk2
            textureRects[3] = rl.Rectangle{768, 256, 128, 256} // jump
            textureRects[4] = rl.Rectangle{768, 1024, 128, 256} // duck
        case .green:
            textureRects[0] = rl.Rectangle{512, 1280, 128, 256} // stand
            textureRects[1] = rl.Rectangle{512, 512, 128, 256}  // walk1
            textureRects[2] = rl.Rectangle{512, 256, 128, 256}    // walk2
            textureRects[3] = rl.Rectangle{512, 1536, 128, 256} // jump
            textureRects[4] = rl.Rectangle{640, 256, 128, 256} // duck
        case .pink:
            textureRects[0] = rl.Rectangle{384, 1280, 128, 256} // stand
            textureRects[1] = rl.Rectangle{256, 1792, 128, 256}  // walk1
            textureRects[2] = rl.Rectangle{256, 1536, 128, 256}    // walk2
            textureRects[3] = rl.Rectangle{768, 1536, 128, 256} // jump
            textureRects[4] = rl.Rectangle{384, 1536, 128, 256} // duck
        case .yellow:
            textureRects[0] = rl.Rectangle{128, 1792, 128, 256} // stand
            textureRects[1] = rl.Rectangle{128, 1024, 128, 256}  // walk1
            textureRects[2] = rl.Rectangle{128, 768, 128, 256}    // walk2
            textureRects[3] = rl.Rectangle{256, 0, 128, 256} // jump
            textureRects[4] = rl.Rectangle{256, 768, 128, 256} // duck
    }

    switch player.state {
        case PlayerState.idle:
            textureIndex = 0
        case PlayerState.walking:
            textureIndex = 1 + int(math.mod(player.walkAnimationTime*2, 2))
        case PlayerState.jumping:
            textureIndex = 3
        case PlayerState.ducking:
            textureIndex = 4
    }

    source := textureRects[textureIndex]

    if player.faceDirection.x < 0 {
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

    groundTextures = rl.LoadTexture(cstring("assets/Spritesheets/spritesheet_ground.png"))
    defer rl.UnloadTexture(groundTextures)

    playerTextures = rl.LoadTexture(cstring("assets/Spritesheets/spritesheet_players.png"))
    defer rl.UnloadTexture(playerTextures)

    ground := createPlatform({f32(rl.GetScreenWidth()) * 0.5, f32(rl.GetScreenHeight())}, f32(rl.GetScreenWidth()))
    player := createPlayer({f32(rl.GetScreenWidth()) * 0.5, ground.hitbox.y}, .blue)

    keyToStyleMap := map[rl.KeyboardKey]PlayerStyle{
        rl.KeyboardKey.ONE=PlayerStyle.beige,
        rl.KeyboardKey.TWO=PlayerStyle.blue,
        rl.KeyboardKey.THREE=PlayerStyle.green,
        rl.KeyboardKey.FOUR=PlayerStyle.pink,
        rl.KeyboardKey.FIVE=PlayerStyle.yellow,
    }

    for !rl.WindowShouldClose() {
        dt := rl.GetFrameTime()
        playerVelocityX:f32 = 0

        if rl.IsKeyPressed(rl.KeyboardKey.F) {
            rl.TakeScreenshot(cstring("screenshot.png"))
        }

        for key, style in keyToStyleMap {
            if rl.IsKeyPressed(key) {
                player.style = style
            }
        }

        if rl.IsKeyPressed(rl.KeyboardKey.H) {
            showHelpers = !showHelpers
        }

        if rl.IsKeyDown(rl.KeyboardKey.A) {
            player.faceDirection.x = -1
            playerVelocityX = player.faceDirection.x * player.horizontalSpeed
        }

        if rl.IsKeyDown(rl.KeyboardKey.D) {
            player.faceDirection.x = 1
            playerVelocityX = player.faceDirection.x * player.horizontalSpeed
        }

        if playerVelocityX == 0 {
            if player.state != .jumping {
                player.state = .idle
            }
        } else {
            if player.state != .jumping {
                player.state = .walking
            }
        }

        if rl.IsKeyDown(rl.KeyboardKey.S) {
            if player.state == PlayerState.idle || player.state == PlayerState.walking {
                player.state = PlayerState.ducking
                playerVelocityX = 0
            }
        }

        if rl.IsKeyReleased(rl.KeyboardKey.S) {
            if player.state == PlayerState.ducking {
                player.state = PlayerState.idle
            }
        }

        if rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
            if player.state == PlayerState.idle || player.state == PlayerState.walking {
                initialVelocity := -math.sqrt_f32(2 * gravity * player.jumpHeight)
                player.velocity.y = initialVelocity
                player.jumpStartPosition = player.position
                player.state = PlayerState.jumping
            }
        }

        if player.state == PlayerState.walking  {
            player.walkAnimationTime += dt
        } else {
            player.walkAnimationTime = 0
        }

        player.velocity.x = playerVelocityX
        player.position += player.velocity * dt
        player.hitbox.x = player.position.x - player.size.x * 0.5
        player.hitbox.y = player.position.y - player.size.y + 1

        if player.state == PlayerState.jumping {
            if rl.CheckCollisionRecs(player.hitbox, ground.hitbox) {
                player.velocity.y = 0
                player.position.y = ground.hitbox.y
                player.state = PlayerState.idle
            } else {
                player.velocity.y += gravity * dt
                player.jumpLandPosition.x = player.position.x + player.velocity.x * dt
                player.jumpLandPosition.y = 0
            }
        }

        rl.BeginDrawing()
        rl.ClearBackground(rl.SKYBLUE)

        drawPlatform(ground)

        drawPlayer(player)

        if showHelpers {
            rl.DrawText(fmt.ctprintf("Vertical Velocity %f", player.velocity.y), 10, 10, 20, rl.YELLOW)
            rl.DrawText(fmt.ctprintf("Is Grounded %s", player.isGrounded), 10, 30, 20, rl.YELLOW)
            rl.DrawText(fmt.ctprintf("Player state %s", player.state), 10, 50, 20, rl.YELLOW)
        }

        rl.EndDrawing()
    }
}