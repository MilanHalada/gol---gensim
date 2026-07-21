package main

import "core:fmt"
import rl "vendor:raylib"

main :: proc() {

	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, APP_NAME)

	defer rl.CloseWindow()

	rl.SetTargetFPS(60)

	init_simulation()
	defer free_simulation()

	tick: u128
	for !rl.WindowShouldClose() {
		tick += 1
		update_grid()


		rl.BeginDrawing()

		defer rl.EndDrawing()

		rl.ClearBackground(rl.BLACK)
		fmt.printfln("draw_grid[%d]", tick)
		draw_grid()
	}
}
