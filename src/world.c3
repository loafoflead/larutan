import std::collections::list;
import math;
import std::math::vector;
import entity;
import player;
import rendering;
import raylib;

import std::io;

const double MAP_AABB_RAYCAST_CHECK_RAY_STEP = 0.1;
const double MAX_NEARBY_DIST = 1.0;
const float RAYCAST_DIST = 256f;

def MapCell = short;
def IndexList = List(<usz>);

const uint MAP_WIDTH = 30;
const uint MAP_HEIGHT = MAP_WIDTH;
const Rect MAP_RECT = Rect { 0, 0, MAP_WIDTH, MAP_HEIGHT };

struct World {
	MapCell* map;
	EntityList entities;
	// list of cells that have a sprite in them, so that when raycasting into 
	// the world we can check if we hit a sprite when entering 
	// a cell. (presumably (haven't implemented yet) this is gonna have 
	// similar bug as in doom where you won't raycast hit a bit sprite bc it overlaps
	// collision 'sectors')
	IndexList occupied_cells;
}

fn bool World.ray_hits(World* this, Vec2 og, Vec2 dir, EntityList* ents) {
	RaycastHit hit = this.cast_ray(og, dir, ents);
	if (hit.hit) return true;
	return false;
}

// TODO: when hitting an entity, the ray will sometimes be right up in a cell 
// and therefore inside an entity on the border between two or more cells
// when hit, so the hit is registered way far off from where it actually 
// hits the entity's hitbox
// TODO; small hitboxes seem to never or possibly only extremely rarely
// be detected by raycasts. VALVE PLS FIX!
fn RaycastHit World.cast_ray(World* this, Vec2 og, Vec2 dir, EntityList* ents) {
	// check for entities and stuff now
	MapCell* temp_map = mem::new_array(MapCell, MAP_WIDTH*MAP_HEIGHT);
	defer free(temp_map);

	foreach(cell: this.occupied_cells) {
		temp_map[cell] = 1;
	}

	// check if a cell that contains an entity is hit with a raycast
	RaycastHit hit = rendering::cast_ray(temp_map, og, dir);

	Vec2 hit_pt = og + dir * hit.dist;
	double added_dist = 0;
	if (hit.hit) {
		io::printfn("NEAR A GUY");
		// FIXME: extremely naive and frankly shit implementation
		foreach(ent:ents) {
			if (ent.dead) continue;
			if (!ent.can_collide()) continue;
			//if ((ent.pos - hit_pt).length_sq() > MAX_NEARBY_DIST) continue;

			Vec2f begin = Vec2f {(float)og.x, (float)og.y};
			Vec2f end = Vec2f {(float)og.x + (float)dir.x * RAYCAST_DIST, (float)og.y + (float)dir.y * RAYCAST_DIST};


			if (try hit_pos = raylib::line_collides_rect(ent.body.centred_box(ent.pos), begin, end)) {
				hit.dist = (begin - hit_pos).length();
				return hit;
			}
		}
	}

	hit = rendering::cast_ray(this.map, og, dir);

	// just checking if it hit or not...
	if (hit.hit) return hit;

	hit.hit = false;
	return hit;
}

fn void update_world_occupied_cells(World* world, EntityList entities, Player* player) {
	world.occupied_cells.clear();
	// TODO: shit
	// FIXME: i unironically have no fucking idea what this routine does, 
	// but hopefully its now more efficient (i.e. doesn't bring the whole
	// game to its knees for some reason (possibly the (before the fix) triply
	// nested for loops run every frame))
	foreach(&ent: entities) {
		if (ent.dead) continue;

		if (!MAP_RECT.contains(ent.pos.round())) continue;

		Rect[4] rects = {
			{(float)ent.pos.x.floor(), (float)ent.pos.y.floor(), 1, 1},
			{(float)ent.pos.x.ceil(), (float)ent.pos.y.ceil(), 1, 1},
			{(float)ent.pos.x.ceil(), (float)ent.pos.y.floor(), 1, 1},
			{(float)ent.pos.x.floor(), (float)ent.pos.y.ceil(), 1, 1},
		};
		
		foreach(rect:rects) {
			if (!rect.intersection(ent.body.centred_box(ent.pos)).equals(math::ZERO)) {
				if (!world.occupied_cells.contains((ulong)(rect.y * MAP_WIDTH + rect.x))) {
					world.occupied_cells.push((ulong)(rect.y * MAP_WIDTH + rect.x));
				}
			}
		}
	}

	usz[<2>] player_map_pos = (usz[<2>])player.pos.round();
	world.occupied_cells.push(player_map_pos.y * MAP_WIDTH + player_map_pos.x);
}
