module world;

import std::collections::list;
import utils::math;
import std::math::vector;
import entity;
import player;
import rendering;
import bindings::raylib;
import astar;

import std::io;

const double MAP_AABB_RAYCAST_CHECK_RAY_STEP = 0.1;
const double MAX_NEARBY_DIST = 1.0;
const float RAYCAST_DIST = 256f;

def MapCell = GridCell;
def IndexList = List(<usz>);

const uint MAP_WIDTH = 30;
const uint MAP_HEIGHT = MAP_WIDTH;
const Rect MAP_RECT = Rect { 0, 0, MAP_WIDTH, MAP_HEIGHT };

fault RaycastError {
	NOT_HIT,
}

struct World {
	Grid map;
	Player* player;
	EntityList entities;
	// list of cells that have a sprite in them, so that when raycasting into 
	// the world we can check if we hit a sprite when entering 
	// a cell. (presumably (haven't implemented yet) this is gonna have 
	// similar bug as in doom where you won't raycast hit a bit sprite bc it overlaps
	// collision 'sectors')
	IndexList occupied_cells;
}

fn bool World.ray_hits(World* this, Vec2 og, Vec2 dir, EntityList* ents) {
	RaycastHit hit = this.cast_ray(og, dir);
	if (hit.hit) return true;
	return false;
}

fn RaycastHit! World.hits_player(&self, Vec2 og, Vec2 dir, float range = RAYCAST_DIST) {
	Vec2f begin = Vec2f {(float)og.x, (float)og.y};
	Vec2f end = Vec2f {(float)og.x + (float)dir.x * range, (float)og.y + (float)dir.y * range};

	if (try hit_pos = raylib::line_collides_rect(self.player.centred_hitbox(), begin, end)) {
		RaycastHit hit = {
			.dist = (begin - hit_pos).length(),
			.hit = true,
			.hit_player = true,
			.player = self.player,
		};
		return hit;
	}
	return RaycastError.NOT_HIT?;
}

// TODO: when hitting an entity, the ray will sometimes be right up in a cell 
// and therefore inside an entity on the border between two or more cells
// when hit, so the hit is registered way far off from where it actually 
// hits the entity's hitbox
// TODO: make this return an optional for snazzy syntax & hit detection
// TODO: make exclude better lmao hacky fix
// TODO: make range a parameter
fn RaycastHit World.cast_ray(World* this, Vec2 og, Vec2 dir, Entity* exclude = null, bool exclude_player = false) {
	RaycastHit hit = {};
/*	MapCell* temp_map = mem::new_array(MapCell, MAP_WIDTH*MAP_HEIGHT);
	defer free(temp_map);

	foreach(cell: this.occupied_cells) {
		temp_map[cell] = 1;
	}

	// check if a cell that contains an entity is hit with a raycast
	RaycastHit hit = rendering::cast_ray(temp_map, og, dir);

	Vec2 hit_pt = og + dir * hit.dist;
*/	double added_dist = 0;
	Vec2f begin = Vec2f {(float)og.x, (float)og.y};
	Vec2f end = Vec2f {(float)og.x + (float)dir.x * RAYCAST_DIST, (float)og.y + (float)dir.y * RAYCAST_DIST};

//	if (hit.hit) {
	foreach(ent:this.entities) {
		if (&ent == exclude) continue;
		if (ent.dead) continue;
		if (!ent.can_collide()) continue;
		//if ((ent.pos - hit_pt).length_sq() > MAX_NEARBY_DIST) continue;

		if (try hit_pos = raylib::line_collides_rect(ent.body.centred_box(ent.pos), begin, end)) {
			hit.dist = (begin - hit_pos).length();
			hit.entity = &ent;
			hit.hit = true;
			return hit;
		}
	}
//	}

	if (!exclude_player) {
		if (try hit_pos = raylib::line_collides_rect(this.player.centred_hitbox(), begin, end)) {
			hit.dist = (begin - hit_pos).length();
			hit.hit = true;
			hit.hit_player = true;
			hit.player = this.player;
			return hit;
		}
	}

	hit = rendering::cast_ray(this.map.grid, og, dir);

	// just checking if it hit or not...
	if (hit.hit) return hit;

	return hit;
}

// TODO: make this actually work por favor
fn void update_world_occupied_cells(World* world, EntityList entities, Player* player) {
	world.occupied_cells.clear();
	// NOTE: i unironically have no fucking idea what this routine does, 
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
