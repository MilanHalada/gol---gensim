package main

import fmt "core:fmt"
import rnd "core:math/rand"

Cell_type :: enum u8 {
	Empty,
	Resource,
	Grazer,
	Predator,
}

Genome :: struct {
	type:              Cell_type,
	reproduce_cost:    u16,
	reproduce_trigger: u16,
	energy_drain:      u8,
	ideal_neighbors:   u8,
	mutation_rate:     f32,
	strength:          u8,
	max_energy:        u16,
}

Cell :: struct {
	alive:      bool,
	genome:     Genome,
	energy:     u16,
	target_idx: Maybe(int),
}

NeighborStats :: struct {
	empty_cnt:    u8,
	resource_cnt: u8,
	grazer_cnt:   u8,
	predator_cnt: u8,
}

init_genome :: proc(type: Cell_type) -> (new_genome: Genome) {
	if type == .Empty {
		return
	}

	new_genome.type = type
	new_genome.reproduce_cost = u16(rnd.uint32_range(100, 200))
	new_genome.energy_drain = u8(rnd.uint32_range(20, 100))
	new_genome.ideal_neighbors = u8(rnd.int31_max(8))
	new_genome.mutation_rate = rnd.float32_range(0, 1)
	new_genome.strength = u8(rnd.int31_max(10))
	new_genome.max_energy = u16(rnd.uint32_range(100, 999))

	return new_genome
}

mutate_genome :: proc(genome: Genome, power: uint) -> (mutated_genome: Genome) {
	mutated_genome = genome

	rate := (f32(power) - MUTATION_TRIGGER) / MUTATION_TRIGGER

	mutated_genome.energy_drain += clamp(
		u8(f32(mutated_genome.energy_drain) * rnd.float32_range(-rate, rate)),
		0,
		max(u8),
	)
	mutated_genome.max_energy += clamp(
		u16(f32(mutated_genome.max_energy) * rnd.float32_range(-rate, rate)),
		0,
		max(u16),
	)
	mutated_genome.strength += clamp(
		u8(f32(mutated_genome.strength) * rnd.float32_range(-rate, rate)),
		0,
		max(u8),
	)

	return mutated_genome
}


init_cell :: proc(genome: Genome, reproduction: bool = false) -> (new_cell: Cell) {

	if genome.type == .Empty {
		return
	}

	mutation_power := uint(f32(rnd.int31_max(255)) * genome.mutation_rate)
	mutated_genome := genome

	if reproduction && mutation_power >= MUTATION_TRIGGER {
		mutated_genome = mutate_genome(genome, mutation_power)
	}

	new_cell.genome = mutated_genome
	new_cell.energy = mutated_genome.max_energy
	new_cell.alive = true

	return new_cell
}


get_cell_index :: proc(x, y: int) -> int {
	nx := (x + GRID_WIDTH) % GRID_WIDTH
	ny := (y + GRID_HEIGHT) % GRID_HEIGHT

	// fmt.printfln("[%d, %d] = [%d, %d] = %d", x, y, nx, ny, ny * GRID_WIDTH + nx)
	// fmt.printfln("%d * %d + %d = %d", ny, GRID_WIDTH, nx, ny * GRID_WIDTH + nx)

	return ny * GRID_WIDTH + nx
}

get_neighbor_stats :: proc(x, y: int) -> (stats: NeighborStats) {
	for dy in -1 ..= 1 {
		for dx in -1 ..= 1 {
			idx := get_cell_index(x + dx, y + dy)
			cell := grid_current[idx]

			switch cell.genome.type {
			case .Empty:
				stats.empty_cnt += 1
			case .Resource:
				stats.resource_cnt += 1
			case .Grazer:
				stats.grazer_cnt += 1
			case .Predator:
				stats.predator_cnt += 1
			}
		}
	}
	return stats
}
