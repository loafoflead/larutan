// https://www.kodeco.com/3016-introduction-to-a-pathfinding/page/3
// this is the one!!!!!

module astar;

import std::io;
import std::collections::list;
import std::collections;
import std::math;
import std::math::vector;

def PositionList = List(<GridPos>);
def NodeList = List(<GridNode>);
def GridPos = usz[<2>];
def GridCell = short;
def IVec2 = isz[<2>];
def CostMap = HashMap(<GridCell, float>);

const int DEFAULT_ASTAR_ITERS = 256;

fault PathfindError {
	NO_VALID_PATH,
	EXCEEDS_MAX_ITERATIONS,
}

struct GridNode {
	GridPos pos;
	float score;
	GridNode* prev;
	bool dead_end;
	bool path;
}
struct Grid {
	usz w, h;
	GridCell* grid;
	GridCell[] empties;
	CostMap costs;
}

fn Grid new_grid(usz w, usz h) {
	return Grid {
		.w = w,
		.h = h,
		.grid = mem::new_array(GridCell, w*h),
		.empties = {' '},
		.costs = {},
	};
}

fn bool Grid.in_bounds(&self, GridPos pos) {
	return pos.x < self.w && pos.y < self.h;
}

macro Grid.at(&self, pos) => pos.y * self.w + pos.x;

fn bool Grid.is_empty(&self, GridPos pos) {
	foreach(emp: self.empties) {
		if (self.grid[self.at(pos)] == emp) return true;	
	}
	return false;
}

fn float Grid.cost_at(&self, GridPos pos) {
	if (!self.in_bounds(pos)) return 0.0;

	return self.costs[self.grid[self.at(pos)]] ?? 0.0;
}

fn PositionList Grid.neighbours(&self, GridPos pos) {
	PositionList idxs; idxs.new_init();
	//	  x
	//   xox
	//	  x
	GridPos[] nbors = {
		pos + {1, 0},
		pos - {1, 0},
		pos + {0, 1},
		pos - {0, 1},
	};
	foreach (n: nbors) {
		if (self.in_bounds(n) && self.is_empty(n)) idxs.push(n);
	}
	return idxs;
}

fn void Grid.fill(&self, char c) {
	for (int i = 0; i < self.w*self.h; i++) self.grid[i] = c;
}

fn void Grid.print(&self) {
	for (int i = 0; i < self.h; i ++) {
		for (int j = 0; j < self.w; j++) {
			io::printf("%c", self.grid[i * self.w + j]);
		}	
		io::printn("");
	}
}


fn usz! GridNode.to_format(&self, Formatter* formatter) @dynamic
{
	return formatter.printf(
		"GridNode { pos: %s, score: %f, prev: %d%d, dead end: %s, path: %s }", 
		self.pos,
		self.score,
		self.prev != null ? self.prev.pos.x : 0, 
		self.prev != null ? self.prev.pos.y : 0, 
		self.dead_end,
		self.path,
	);
}

fn String GridNode.to_new_string(&self, Allocator allocator = allocator::heap()) @dynamic
{
	return string::format("%s", *self, allocator: allocator);
}

fn usz manhattan_dist(GridPos a, GridPos b) {
	return math::abs(a.x - b.x) + math::abs(a.y - b.y);
}


macro bool GridNode.equals(&self, GridNode other) => self.pos == other.pos;

struct Path {
	PositionList points;
	usz target;
}
//	temp_grid[THING_ONE_OG.pos.y * WIDTH + THING_ONE_OG.pos.x] = THING_ONE_OG;

fn Path! Grid.compute_path(&grid, GridPos a, GridPos b, usz max_iters = DEFAULT_ASTAR_ITERS) {
	NodeList open_list; open_list.new_init();
	NodeList closed_list; closed_list.new_init();

	open_list.push(GridNode { .pos=a, .score = ((Vec2f)b).distance((Vec2f)a), .prev = null });

	GridNode* end = null;
	usz iters = 0;

	while (open_list.len() != 0 && iters < max_iters) {
		// 'extend' our search tree from the closest point
		// in the open list
		GridNode* best = &open_list[0]; 
		usz best_idx = 0;

		foreach(i, &node: open_list) {
			if (node.score <= best.score) {
				best = node;
				best_idx = i;
			}
		}

		closed_list.push(*best);
		best = &closed_list[closed_list.len()-1]; // meory... sadge
		
		// this has to be here bc im dumb and thought that 
		// a variable inside of open_list would exist after getting freed
		PositionList autour = grid.neighbours(best.pos);

		open_list.remove_at(best_idx);

		if (closed_list.contains(GridNode { .pos = b })) {
			end = &closed_list[closed_list.index_of(GridNode { .pos = b })!!];
			break;
		}


		// add surroundings to list of grid spaces to check and 'extend' search from
		foreach HI: (neighbour: autour) {
			GridNode node = {
				.pos = neighbour,
				.score = ((Vec2f)b).distance((Vec2f)neighbour) + grid.cost_at(neighbour),
				.prev = best,
			};
			if (closed_list.contains(node)) {
				continue HI;
			}

			if (!open_list.contains(node)) {
				open_list.push(node);
			}
			// TODO: figure out if this needs to rebind the prev
		}

		iters += 1;
	}

	if (end == null && iters == max_iters) {
		return PathfindError.EXCEEDS_MAX_ITERATIONS?;
	}

	if (end == null) {
		return PathfindError.NO_VALID_PATH?;
	}

	Path p; p.points.new_init();

	while(end.prev != null) {
		p.points.push(end.pos);
		end = end.prev;
	}

	p.points.push(a);
	p.points.reverse();
	
	return p;
}

