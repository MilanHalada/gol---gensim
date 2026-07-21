package main

import fmt "core:fmt"
import rnd "core:math/rand"
import slice "core:slice"

grid_current: []Cell
grid_next: []Cell

genomes: []Genome

init_grid :: proc() {
	fmt.printfln("init_grid: %v, %v", GRID_WIDTH, GRID_HEIGHT)
	for y in 0 ..< GRID_HEIGHT {
		for x in 0 ..< GRID_WIDTH {
			idx := get_cell_index(x, y)

			roll := rnd.float32()

			if roll >= (1.0 - INITIAL_COVERAGE) {
				ginx := (idx + INITIAL_GENOME_COUNT) % INITIAL_GENOME_COUNT

				genome := genomes[ginx]
				grid_current[idx] = init_cell(genome)
			} else {
				grid_current[idx] = init_cell(Genome{type = .Empty})
			}
		}
	}
}

update_grid :: proc() {
	collect_data()
	resolve_interactions()
	swap()
}

init_simulation :: proc() {

	total_cells := GRID_WIDTH * GRID_HEIGHT

	grid_current = make([]Cell, total_cells)
	grid_next = make([]Cell, total_cells)

	genomes = make([]Genome, max(u16))
	food_map = make([]FoodMapItem, total_cells)

	fmt.printfln("total_cells: %v", total_cells)
	init_genomes()
	init_grid()
}

free_simulation :: proc() {

	delete(grid_current)
	delete(grid_next)

	delete(genomes)

}

init_genomes :: proc() {
	for i in 0 ..< INITIAL_GENOME_COUNT {
		// 60 - 30 - 10 initial ratio for resource/grazer/predator

		ratio := f32(i) / f32(INITIAL_GENOME_COUNT)

		if ratio <= 0.6 {
			genomes[i] = init_genome(Cell_type.Resource)
		} else if ratio <= 0.9 {
			genomes[i] = init_genome(Cell_type.Grazer)
		} else {
			genomes[i] = init_genome(Cell_type.Predator)
		}
	}
}


FoodMapItem :: struct {
	total_strength:   u16,
	competitor_count: u8,
}

food_map: []FoodMapItem

collect_data :: proc() {
	slice.zero(food_map)
	for y in 0 ..< GRID_HEIGHT {
		for x in 0 ..< GRID_WIDTH {

			idx := get_cell_index(x, y)
			current_cell := grid_current[idx]

			if !current_cell.alive do continue

			if current_cell.genome.type == .Grazer || current_cell.genome.type == .Predator {

				max_energy := u16(0)
				max_energy_idx: Maybe(int)

				for dy in -1 ..= 1 {
					for dx in -1 ..= 1 {
						if dx == 0 && dy == 0 do continue

						n_idx := get_cell_index(x + dx, y + dy)
						n_cell := grid_current[n_idx]
						if (current_cell.genome.type == .Grazer &&
							   n_cell.genome.type == .Resource) ||
						   (current_cell.genome.type == .Predator &&
								   n_cell.genome.type == .Grazer) {
							if n_cell.energy > max_energy {
								max_energy = n_cell.energy
								max_energy_idx = n_idx
							}
						}
					}
				}

				current_cell.target_idx = max_energy_idx

				val, ok := max_energy_idx.?
				if (ok) {
					item := food_map[val]
					item.total_strength += u16(current_cell.genome.strength)
					item.competitor_count += 1
					food_map[val] = item
					// fmt.printfln("%d targeting %v", idx, current_cell.target_idx)
				}
			}

			grid_current[idx] = current_cell
		}
	}
}

resolve_interactions :: proc() {
	for y in 0 ..< GRID_HEIGHT {
		for x in 0 ..< GRID_WIDTH {

			idx := get_cell_index(x, y)
			current_cell := grid_current[idx]
			stats := get_neighbor_stats(x, y)

			next_cell := current_cell

			switch current_cell.genome.type {
			case .Empty:
				if stats.empty_cnt >= EMPTY_TO_RESOURCE_NEIGHBOR_TRIGGER {
					next_cell = init_cell(init_genome(.Resource))
				}
			case .Resource:
				if !current_cell.alive {
					next_cell = init_cell(init_genome(.Empty))
				} else if stats.resource_cnt >= RESOURCE_TO_GRAZER_NEIGHBOR_TRIGGER {
					next_cell = init_cell(init_genome(.Grazer))
				}
			case .Grazer:
				if !current_cell.alive {
					next_cell = init_cell(init_genome(.Empty))
				} else if stats.grazer_cnt >= GRAZER_TO_PREDATOR_NEIGHBOR_TRIGGER {
					next_cell = init_cell(init_genome(.Predator))
				}
			case .Predator:
				if !current_cell.alive {
					next_cell = init_cell(init_genome(.Resource))
					next_cell.genome.max_energy = current_cell.genome.max_energy
				}
			}

			switch current_cell.genome.type {
			case .Empty:
			// nothing
			case .Resource:
				if (food_map[idx].competitor_count > 0) {
					next_cell.alive = false
				} else {
					multiplier :=
						f32(stats.resource_cnt) / f32(current_cell.genome.ideal_neighbors)
					gain := u16(f32(current_cell.genome.energy_drain) * multiplier)

					next_cell.energy = clamp(
						current_cell.energy + gain,
						0,
						current_cell.genome.max_energy,
					)
				}

			case .Grazer, .Predator:
				if current_cell.energy <= u16(current_cell.genome.energy_drain) {
					next_cell.alive = false
				} else {
					next_cell.energy -= u16(current_cell.genome.energy_drain)

					//feeding

					target_idx, ok := current_cell.target_idx.?
					if ok {
						food := food_map[target_idx]
						ratio := f32(current_cell.genome.strength) / f32(food.total_strength)
						target := grid_current[target_idx]

						next_cell.energy += u16(f32(target.energy) * ratio)
					}

					//reproduction

					if current_cell.energy > current_cell.genome.reproduce_cost &&
					   stats.empty_cnt > 0 {
						next_cell.energy -= current_cell.genome.reproduce_cost

						repro_loop: for dy in -1 ..= 1 {
							for dx in -1 ..= 1 {
								n_idx := get_cell_index(x + dx, y + dy)
								n_cell := grid_current[n_idx]
								if (n_cell.genome.type == .Empty ||
									   n_cell.genome.type == .Resource) {
									grid_next[n_idx] = init_cell(current_cell.genome, true)
									break repro_loop
								}
							}
						}
					}

					if current_cell.genome.type == .Predator && stats.predator_cnt == 8 {
						next_cell.alive = false
					}
				}
			}
			grid_next[idx] = next_cell
		}
	}
}


swap :: proc() {
	temp := grid_current
	grid_current = grid_next
	grid_next = temp
}
