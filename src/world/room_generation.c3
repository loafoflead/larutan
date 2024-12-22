module world::room_gen;

import std::io;
import std::core::mem;
import std::math;
import libc;

const int GRID_WIDTH = 4;
const int GRID_HEIGHT = 4;

const int DISPLAY_WIDTH = 50;
const int DISPLAY_HEIGHT = 50;

const short LEFT = 0b0001;
const short RIGHT = 0b0010;
const short UP = 0b0100;
const short DOWN = 0b1000;

def IVec = int[<2>];

def GridCell = short;

fn IVec[4] GridCell.get_doors(GridCell this) {
	IVec[4] doors;
	if (this & LEFT != 0) { // LEFT
		doors[0] = {-1, 0};
	} 
	if (this & RIGHT != 0) { // RIGHT
		doors[1]  = {1, 0};
	}
	if (this & UP != 0) { // UP
		doors[2] = {0, -1};
	}
	if (this & DOWN != 0) { // DOWN
		doors[3] = {0, 1};
	}
	return doors;
}

fn void print_grid(GridCell* grid) {
	for (int i = 0; i < GRID_HEIGHT; i++) {
		for (int j = 0; j < GRID_WIDTH; j++) {
			char ch = 48; // ascii index of '0'
			ch += (char)count_bits(grid[i * GRID_WIDTH + j]); // display the number of doors this cell has
			io::printf("%c", ch);
		}
		io::printn("");
	}
}

fn int count_bits(int x){
	int y = 0;
	while(x){   
		y += x &  1 ;
		x  = x >> 1 ;
	}
	return y;
}

fn usz idx(int x, int y) {
	return((usz)y * (usz)GRID_WIDTH + (usz)x);
}

fn bool in_bounds(int x, int y) {
	return( x >= 0 && x < GRID_WIDTH && y >= 0 && y < GRID_HEIGHT );
}

fn void randomise_grid_pos(GridCell* grid, int x, int y) {
	grid[idx(x, y)] = (short)(libc::rand() % (usz)math::pow(2, 4));
}

fn void collapse_dem_waves(GridCell* grid, int x, int y, short from) {
	randomise_grid_pos(grid, x, y);
	grid[idx(x, y)] |= from;

	IVec[4] doors = grid[idx(x, y)].get_doors();

	foreach(i, door: doors) {
		if (door == {0, 0}) continue;

		IVec next = {x, y} + door;

		if (in_bounds(next.x, next.y) && grid[idx(next.x, next.y)] == 0) {
			from = 0;
			switch(i) {
				case 0: from = RIGHT; // from the LEFT
				case 1: from = LEFT;  // from the RIGHT
				case 2: from = DOWN;  // from UP
				case 3: from = UP;	  // from DOWN
			}
			collapse_dem_waves(grid, next.x, next.y, from);
		}
		else {
			short rm;
			switch(i) {
				case 0: rm = LEFT; // from the LEFT
				case 1: rm = RIGHT;  // from the RIGHT
				case 2: rm = UP;  // from UP
				case 3: rm = DOWN;	  // from DOWN
			}
			grid[idx(x, y)] ^= rm;
		}
	}
}

fn void draw_rect(char* display, char fill, int ox, int oy, int w, int h) {
	// i don't like this, ugly and hard to read, but im lazy so
	for (int y = oy; y < oy + h; y++) {
		for (int x = ox; x < ox + w; x++) {
			if (x * y >= DISPLAY_HEIGHT * DISPLAY_WIDTH) continue;
			display[y * DISPLAY_WIDTH + x] = fill;
		}
	}
}

fn void draw_rect_outline(char* display, char border, int ox, int oy, int w, int h) {
	for (int y = oy; y < oy + h; y++) {
		for (int x = ox; x < ox + w; x++) {
			if (x * y >= DISPLAY_HEIGHT * DISPLAY_WIDTH) continue;
			if (y == oy || x == ox || y == oy + h - 1 || x == ox + w - 1) display[y * DISPLAY_WIDTH + x] = border;
		}
	}
}

fn void draw_grid(GridCell* grid) {
	char* display = mem::new_array(char, DISPLAY_WIDTH * DISPLAY_HEIGHT);
	for (int i = 0; i < DISPLAY_WIDTH*DISPLAY_HEIGHT; i++) display[i] = ' ';

	int width_factor = DISPLAY_WIDTH / GRID_WIDTH;
	int height_factor = DISPLAY_HEIGHT / GRID_HEIGHT;

	for (int y = 0; y < GRID_HEIGHT; y++) {
		for (int x = 0; x < GRID_WIDTH; x ++) {
			if (grid[idx(x, y)] != 0) {
				draw_rect_outline(display, '~', x * width_factor, y * height_factor, width_factor, height_factor);
			}
		}
	}

	for (int y = 0; y < GRID_HEIGHT; y++) {
		for (int x = 0; x < GRID_WIDTH; x ++) {
			if (grid[idx(x, y)] != 0) {
				IVec[4] doors = grid[idx(x, y)].get_doors();

				foreach(door: doors) {
					if (door == {0, 0}) continue;

					IVec doorpos = {x, y} * IVec { width_factor, height_factor };
					IVec realdoorpos;

					// FIXME: this is ass im too tired to think of better pls dont hate
					switch (door) {
						case {-1, 0}:
							realdoorpos = doorpos + {0, height_factor / 2-1};
						break;
						case {1, 0}:
							realdoorpos = doorpos + {width_factor, height_factor / 2-1};
						break;
						case {0, 1}:
							realdoorpos = doorpos + {width_factor/2-1, height_factor};
						break;
						case {0, -1}:
							realdoorpos = doorpos + {width_factor/2-1, 0 };
						break;
					}
					
					if (realdoorpos.x * realdoorpos.y >= DISPLAY_HEIGHT * DISPLAY_WIDTH || realdoorpos.x * realdoorpos.y < 0) continue;

					display[realdoorpos.y * DISPLAY_WIDTH + realdoorpos.x] = ' ';
				}
			}
		}
	}

	for (int y = 0; y < DISPLAY_HEIGHT; y++) {
		for (int x = 0; x < DISPLAY_WIDTH; x ++) {
			io::printf("%c", display[y * DISPLAY_WIDTH + x]);
		}
		io::print("\n");
	}
}

fn void generate_rooms() {
	libc::srand((uint)libc::time((Time_t*)0));
	GridCell* grid = mem::new_array(GridCell, GRID_WIDTH * GRID_HEIGHT);

	for (int i = 0; i < GRID_HEIGHT*GRID_WIDTH; i++) grid[i] = '\0';

	randomise_grid_pos(grid, GRID_WIDTH/2, GRID_HEIGHT/2);
	if (grid[idx(GRID_WIDTH/2, GRID_HEIGHT/2)] == 0) grid[idx(GRID_WIDTH/2, GRID_HEIGHT/2)] = 1;

	IVec[4] doors = grid[idx(GRID_WIDTH/2, GRID_HEIGHT/2)].get_doors();

	foreach(i, door: doors) {
		if (door == {0, 0}) continue;

		IVec next = {GRID_WIDTH/2, GRID_HEIGHT/2} + door;

		short from = 0;
		switch(i) {
			case 0: from = RIGHT; // from the LEFT
			case 1: from = LEFT;  // from the RIGHT
			case 2: from = DOWN;  // from UP
			case 3: from = UP;	  // from DOWN
		}

		if (in_bounds(next.x, next.y)) {
			collapse_dem_waves(grid, next.x, next.y, from);
		}
	}

	draw_grid(grid);
	print_grid(grid);

	return;
}
