package main

import fmt "core:fmt"
import rl "vendor:raylib"

draw_grid :: proc() {
	for y in 0 ..< GRID_HEIGHT {
		for x in 0 ..< GRID_WIDTH {
			// fmt.printfln("coord: %d, %d", x, y)

			idx := get_cell_index(x, y)

			// fmt.printfln("rendering index: %d", idx)

			cell := grid_current[idx]

			if !cell.alive do continue

			color := rl.BLACK

			switch cell.genome.type {
			case .Empty:
				color = rl.BLACK
			case .Resource:
				color = rl.GREEN
			case .Grazer:
				color = rl.YELLOW
			case .Predator:
				color = rl.RED
			}

			rl.DrawRectangle(
				i32(x * CELL_SIZE),
				i32(y * CELL_SIZE),
				i32(CELL_SIZE - 1),
				i32(CELL_SIZE - 1),
				color,
			)
		}
	}
}
