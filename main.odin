package main

import "core:fmt"
import "core:path/filepath"
import "core:strings"
import "core:math"
import "core:math/rand"
import "core:math/linalg"
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
    falling,
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
    maxFallSpeed: f32,
    jumpStartPosition: rl.Vector2,
    jumpLandPosition: rl.Vector2,
    walkAnimationTime: f32,
    walkAnimationDuration: f32,
    style: PlayerStyle,
    hasCollision: bool,
    lastCollision: rl.Rectangle,
    lastCollisionPlatform: Platform
}

Platform :: struct {
    position: rl.Vector2,
    size: rl.Vector2,
    hitbox: rl.Rectangle,
    textureRects: [4]rl.Rectangle,
}

Game :: struct {
    player: Player,
    camera: rl.Camera2D,
    platforms: [dynamic]Platform,
    platformAtlas: rl.Texture2D,
    playerAtlas: rl.Texture2D,
}

game: Game

PIXEL_PER_TILE :: 64
groundTextures: rl.Texture
playerTextures: rl.Texture
gravity:f32 = 30
showHelpers := false
isPaused := false
pauseOnCollision := false
keyToStyleMap := map[rl.KeyboardKey]PlayerStyle{
    rl.KeyboardKey.ONE=PlayerStyle.beige,
    rl.KeyboardKey.TWO=PlayerStyle.blue,
    rl.KeyboardKey.THREE=PlayerStyle.green,
    rl.KeyboardKey.FOUR=PlayerStyle.pink,
    rl.KeyboardKey.FIVE=PlayerStyle.yellow,
}

tileToScreenV :: proc(pos: rl.Vector2) -> rl.Vector2 {
    return pos * PIXEL_PER_TILE
}

tileToScreenRec :: proc(rec: rl.Rectangle) -> rl.Rectangle {
    return {rec.x * PIXEL_PER_TILE, rec.y * PIXEL_PER_TILE, rec.width * PIXEL_PER_TILE, rec.height * PIXEL_PER_TILE}
}

screenToTileV :: proc(pos: rl.Vector2) -> rl.Vector2 {
    return {pos.x / PIXEL_PER_TILE, pos.y / PIXEL_PER_TILE}
}

screenToTileRec :: proc(rec: rl.Rectangle) -> rl.Rectangle {
    return {rec.x / PIXEL_PER_TILE, rec.y / PIXEL_PER_TILE, rec.width / PIXEL_PER_TILE, rec.height / PIXEL_PER_TILE}
}

createPlatform :: proc(position: rl.Vector2, width: f32) -> Platform {
    size := rl.Vector2{width, 2}
    hitbox := rl.Rectangle{position.x, position.y, size.x, size.y}
    textureRects := [?]rl.Rectangle{
        rl.Rectangle{128, 128, 128, 128},
        rl.Rectangle{0, 256, 128, 128},
        rl.Rectangle{0, 128, 128, 128},
        rl.Rectangle{0, 0, 128, 128}
    }

    return { position, size, hitbox, textureRects }
}

drawPlatform :: proc(platform: Platform, atlas: rl.Texture2D) {
    size := tileToScreenV(platform.size)
    position := tileToScreenV(platform.position)
    hitbox := tileToScreenRec(platform.hitbox)
    source := rl.Rectangle{0, 0, size.x, size.y}
    origin := rl.Vector2{0, 0}
    rotation:f32 = 0
    tileWidth := f32(128)
    tileHeight := f32(128)

    if size.x == tileWidth {
        rl.DrawTexturePro(atlas, platform.textureRects[0], rl.Rectangle{position.x, position.y, size.x, size.y}, origin, rotation, rl.WHITE)
    } else {
        rl.DrawTexturePro(atlas, platform.textureRects[1], rl.Rectangle{position.x, position.y, tileWidth, tileHeight}, origin, rotation, rl.WHITE)

        dx := tileWidth
        tw := tileWidth
        for dx < size.x - tileWidth {
            dw := size.x - tileWidth - dx
            if dw < tw {
                tw = dw
            }

            rl.DrawTexturePro(
                atlas,
                platform.textureRects[2],
                rl.Rectangle{position.x + dx, position.y, tw, tileHeight},
                origin,
                rotation,
                rl.WHITE
            )
            dx += tw
        }

        rl.DrawTexturePro(
            atlas,
            platform.textureRects[3],
            rl.Rectangle{position.x + dx, position.y, tileWidth, tileHeight},
            origin,
            rotation,
            rl.WHITE
        )
    }
}

createPlayer :: proc(position: rl.Vector2, style: PlayerStyle) -> Player {
    player:Player
    player.position = position
    player.size = screenToTileV({128, 256})
    player.hitbox = rl.Rectangle{position.x, position.y, player.size.x - 0.5, player.size.y - 1.5}
    player.style = style
    player.jumpHeight = 6
    player.horizontalSpeed = 10
    player.maxFallSpeed = 10
    player.walkAnimationTime = 0
    player.walkAnimationDuration = 15

    return player
}

updateGame :: proc(game: ^Game, dt: f32) {
    player := &game.player
    movement := rl.Vector2{ 0, 0 }

    for key, style in keyToStyleMap {
        if rl.IsKeyPressed(key) {
            player.style = style
        }
    }

    if rl.IsKeyDown(rl.KeyboardKey.A) {
        movement.x -= 1
        player.faceDirection.x = -1
    }

    if rl.IsKeyDown(rl.KeyboardKey.D) {
        movement.x += 1
        player.faceDirection.x = 1
    }

    // if rl.IsKeyDown(rl.KeyboardKey.S) {
    //     if player.state == PlayerState.idle || player.state == PlayerState.walking {
    //         player.state = PlayerState.ducking
    //     }
    // }

    // if rl.IsKeyReleased(rl.KeyboardKey.S) {
    //     if player.state == PlayerState.ducking {
    //         player.state = PlayerState.idle
    //     }
    // }

    if rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
        if player.isGrounded {
            initialVelocity := -math.sqrt_f32(2 * gravity * player.jumpHeight)
            player.velocity.y = initialVelocity
            player.jumpStartPosition = player.position
        }
    }

    player.velocity.x = movement.x * player.horizontalSpeed
    player.velocity.y += gravity * dt
    player.isGrounded = false
    player.hasCollision = false

    // Apply y velocity and check collision
    {
        player.position.y += player.velocity.y * dt
        player.hitbox.x = player.position.x - player.size.x * 0.5 - (player.hitbox.width - player.size.x) * 0.5
        player.hitbox.y = player.position.y - player.hitbox.height

        for platform in game.platforms {
            collision := screenToTileRec(rl.GetCollisionRec(tileToScreenRec(player.hitbox), tileToScreenRec(platform.hitbox)))
            if collision.height != 0 {
                sign := f32((player.hitbox.y + player.hitbox.height / 2) > (platform.hitbox.y + platform.hitbox.height / 2) ? 1 : -1)
                player.position.y += collision.height * sign
                player.velocity.y = 0
                player.isGrounded = true
                player.hasCollision = true
                player.lastCollision = collision
                break
            }
        }
    }

    // Apply x velocity and check collision
    {
        player.position.x += player.velocity.x * dt
        player.hitbox.x = player.position.x - player.size.x * 0.5 - (player.hitbox.width - player.size.x) * 0.5
        player.hitbox.y = player.position.y - player.hitbox.height

        for platform in game.platforms {
            collision := screenToTileRec(rl.GetCollisionRec(tileToScreenRec(player.hitbox), tileToScreenRec(platform.hitbox)))
            if collision.width != 0 {
                sign := f32((player.hitbox.x + player.hitbox.width / 2) > (platform.hitbox.x + platform.hitbox.width / 2) ? 1 : -1)
                player.position.x += collision.width * sign
                player.velocity.x = 0
                break
            }
        }
    }

    {
        camera := &game.camera
        position := tileToScreenV(player.position)
        minScreenTargetY := f32(rl.GetScreenHeight()) - 256
        maxDistanceY:f32 = 512
        target:rl.Vector2
        target.x = position.x
        target.y = minScreenTargetY
        playerOffsetY := minScreenTargetY - position.y
        if playerOffsetY > maxDistanceY {
            target.y = minScreenTargetY - (playerOffsetY - maxDistanceY) * dt
        }
        camera.target = target
        horizontalOffset := f32(0)
        cameraOffset := rl.Vector2{f32(rl.GetScreenWidth()) * 0.5 - player.faceDirection.x * horizontalOffset, f32(rl.GetScreenHeight() - 128)}
        camera.offset = linalg.lerp(camera.offset, cameraOffset, dt * 1.2)
        camera.zoom = 1
        camera.rotation = 0
    }

    if player.isGrounded {
        if player.velocity.x != 0 {
            player.state = .walking
            player.walkAnimationTime += dt
        } else {
            player.state = .idle
        }
    } else {
        if player.velocity.y > 0 {
            player.state = .falling
        } else {
            player.state = .jumping
        }
    }
}

drawPlayer :: proc(player: Player, atlas: rl.Texture2D) {
    position := tileToScreenV(player.position)
    size := tileToScreenV(player.size)
    hitbox := tileToScreenRec(player.hitbox)
    dest := rl.Rectangle{
        position.x - size.x * 0.5,
        position.y - size.y,
        size.x,
        size.y
    }
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
            textureRects[0] = rl.Rectangle{384, 512, 128, 256} // stand
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
            textureIndex = 1 + int(math.mod(player.walkAnimationTime*player.walkAnimationDuration, 2))
        case PlayerState.jumping:
            textureIndex = 3
        case PlayerState.falling:
            textureIndex = 3
        case PlayerState.ducking:
            textureIndex = 4
    }

    textureSource := textureRects[textureIndex]

    if player.faceDirection.x < 0 {
        textureSource.width = -textureSource.width
    }

    rl.DrawTexturePro(atlas, textureSource, dest, origin, rotation, rl.WHITE)
}

// updateCamera :: proc(camera: ^Game, dt: f32) {
//     camera := &game.camera
//     player := &game.player

//     position := tileToScreenV(player.position)
//     minScreenTargetY := f32(rl.GetScreenHeight()) - 256
//     maxDistanceY:f32 = 512
//     target:rl.Vector2
//     target.x = position.x
//     target.y = minScreenTargetY
//     playerOffsetY := minScreenTargetY - position.y
//     if playerOffsetY > maxDistanceY {
//         target.y = minScreenTargetY - (playerOffsetY - maxDistanceY) * dt
//     }
//     camera.target = target
//     horizontalOffset := f32(0)
//     cameraOffset := rl.Vector2{f32(rl.GetScreenWidth()) * 0.5 - player.faceDirection.x * horizontalOffset, f32(rl.GetScreenHeight() - 128)}
//     if false {
//         camera.offset = linalg.lerp(camera.offset, cameraOffset, dt * 1.2)
//     } else  {
//         camera.offset = cameraOffset
//     }
//     camera.zoom = 1
//     camera.rotation = 0
// }

restartGame :: proc(game: ^Game) {
    player := &game.player
    player.position.x = 1
    player.position.y = 5
    player.velocity.x = 0
    player.velocity.y = 0
    player.hitbox.x = player.position.x - player.size.x * 0.5 - (player.hitbox.width - player.size.x) * 0.5
    player.hitbox.y = player.position.y - player.hitbox.height
}

initGame :: proc(game: ^Game) {
    game.platforms = make([dynamic]Platform)
    game.platformAtlas = rl.LoadTexture(cstring("assets/Spritesheets/spritesheet_ground.png"))
    game.playerAtlas = rl.LoadTexture(cstring("assets/Spritesheets/spritesheet_players.png"))

    append(&game.platforms, createPlatform({0, 12}, 4))
    append(&game.platforms, createPlatform({4, 14}, 10))
    append(&game.platforms, createPlatform({8, 9}, 4))
    append(&game.platforms, createPlatform({14, 12}, 4))

    game.player = createPlayer({1, 5}, .beige)

    // x:f32 = 0
    // for _ in 0..<50 {
    //     y := f32(14 - rand.int_max(6))
    //     w := 4 + f32(rand.int_max(12))

    //     append(&platforms, createPlatform({x, y}, w))

    //     x += w + f32(2 + rand.int_max(4))
    // }
}

freeGame :: proc(game: ^Game) {
    delete(game.platforms)
    rl.UnloadTexture(game.platformAtlas)
    rl.UnloadTexture(game.playerAtlas)
}

drawGame :: proc(game: Game) {
    rl.BeginDrawing()
    rl.BeginMode2D(game.camera)
    rl.ClearBackground(rl.SKYBLUE)

    for platform in game.platforms {
        drawPlatform(platform, game.platformAtlas)
    }

    drawPlayer(game.player, game.playerAtlas)

    if showHelpers {
        for platform in game.platforms {
            position := tileToScreenV(platform.position)
            hitbox := tileToScreenRec(platform.hitbox)
            rl.DrawRectangleLinesEx(hitbox, 1, rl.RED)
            rl.DrawCircleV(position, 5, rl.RED)
        }

        hitbox := tileToScreenRec(game.player.hitbox)
        rl.DrawRectangleLinesEx(hitbox, 1, rl.RED)
        rl.DrawText(fmt.ctprint(hitbox), i32(hitbox.x), i32(hitbox.y - 22), 20, rl.RED)

        if game.player.hasCollision {
            rec := tileToScreenRec(game.player.lastCollision)
            rl.DrawRectangleRec(rec, rl.MAGENTA)
            rl.DrawText(fmt.ctprint(rec), i32(hitbox.x), i32(hitbox.y - 44), 20, rl.MAGENTA)
            rl.DrawText(fmt.ctprint(tileToScreenRec(game.player.lastCollisionPlatform.hitbox)), i32(hitbox.x), i32(hitbox.y - 64), 20, rl.BLUE)
        }

        rl.DrawCircleV(game.camera.target, 2, rl.YELLOW)
    }

    rl.EndMode2D()

    if showHelpers {
        rl.DrawCircleV(tileToScreenV(game.player.position), 5, rl.RED)

        rl.DrawText(fmt.ctprintf("FPS %d", rl.GetFPS()), 10, 10, 20, rl.YELLOW)
        rl.DrawText(fmt.ctprintf("Position %f:%f", game.player.position.x, game.player.position.y), 10, 30, 20, rl.YELLOW)
        rl.DrawText(fmt.ctprintf("Position %f:%f", game.player.position.x, game.player.position.y), 10, 50, 20, rl.YELLOW)
        rl.DrawText(fmt.ctprintf("Velocity %f:%f", game.player.velocity.x, game.player.velocity.y), 10, 70, 20, rl.YELLOW)
        rl.DrawText(fmt.ctprintf("State %s", game.player.state), 10, 90, 20, rl.YELLOW)
        rl.DrawText(fmt.ctprintf("Is Grounded %s", game.player.isGrounded), 10, 110, 20, rl.YELLOW)

        if game.player.hasCollision {
            rl.DrawText(fmt.ctprintf("Collision"), 10, 130, 20, rl.MAGENTA)
        }
    }

    rl.EndDrawing()
}
main :: proc() {
    rl.InitWindow(1920, 1080, "Platformer with Raylib")
    defer rl.CloseWindow()
    rl.SetTargetFPS(144)

    game: Game
    initGame(&game)
    restartGame(&game)
    defer freeGame(&game)

    for !rl.WindowShouldClose() {
        dt := rl.GetFrameTime()

        if rl.IsKeyPressed(rl.KeyboardKey.F) {
            rl.TakeScreenshot(cstring("screenshot.png"))
        }

        if rl.IsKeyPressed(.R) {
            restartGame(&game)
        }

        if rl.IsKeyPressed(rl.KeyboardKey.H) {
            showHelpers = !showHelpers
        }

        if rl.IsKeyPressed(.ENTER) {
            isPaused = !isPaused
        }

        if rl.IsKeyPressed(.BACKSPACE) {
            pauseOnCollision = !pauseOnCollision
        }

        if !isPaused {
            updateGame(&game, dt)
        }

        drawGame(game)
    }
}