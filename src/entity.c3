import std::math::vector;
import std::collections::list;
import std::io;
import math;
import sprite;
import player;
import world;
import raylib;
import libc;
import timer;

import thinkers;

const usz NUM_COLLISION_NEIGHBOURS = 9;
const usz NUM_ADDITIONAL_COLLISION_RECT = 10; // how many more things we can collide with outside of 9 neighbours

def EntityList = List(<Entity>);
def ThinkFunction = fn int(Entity*, Player*);

struct Body {
	bool simulated;
	bool collides;
	Vec2 vel;
	Vec2 acc;
	Vec2 scale; // every hitbox is a rectangle or a box, so we just need width and height
				// to create a hitbox centred on Entity.pos
}

fn Body new_body(double w, double h, bool collides = true, bool simulated = true) {
	Body body = Body {
		.simulated = true,
		.collides = true,
		.vel = {0.0, 0.0},
		.acc = {0.0, 0.0},
		.scale = {w, h},
	};
	return body;
}

fn Rect Body.centred_box(Body* this, Vec2 pos) {
	Rect rect = {
		(float)pos.x - (float)this.scale.x / 2.0,
		(float)pos.y - (float)this.scale.y / 2.0,
		(float)this.scale.x,
		(float)this.scale.y,
	};
	return rect;
}

struct Entity {
	Sprite sprite;
	Vec2 pos;
	bool dead;
	ThinkFunction think;

	EntityType type;
	union {
		// Enemy, Creature, Shop(?)
		struct {
			Body body;
		}
		// Decal/Decoration
		struct {
			Timer timer;
		}
	}
}

fn Entity new_thinker(
	EntityType 		type, 
	Vec2 			pos, 
	Sprite 			sprite, 
	Body 			body 	 = new_body(1,1), 
	ThinkFunction 	think_fn = &thinkers::default_think, 
	bool 			dead	 = false
) {
	return Entity {
		.type = type,
		.pos = pos,
		.sprite = sprite,
		.body = body,
		.think = think_fn,
		.dead = dead,
	};
}

fn Entity new_dummy(
	EntityType 		type, 
	Vec2 			pos, 
	Sprite 			sprite, 
	Body 			body 	 = new_body(1,1), 
	bool 			dead	 = false
) {
	return Entity {
		.type = type,
		.pos = pos,
		.sprite = sprite,
		.body = body,
		.think = &thinkers::default_think,
		.dead = dead,
	};
}

fn Entity new_decal(Vec2 pos, double z, int sprite_index, float duration_secs) {
	return Entity {
		.type = EntityType.DECAL,
		.pos = pos,
		.sprite = sprite::new_sprite(sprite_index, z, {1.0, 1.0}),
		.think = &thinkers::slowly_die,
		.timer = timer::new_secs(duration_secs),
		.dead = false,
	};
}

fn Sprite* Entity.get_sprite(Entity* this) {
	this.sprite.pos = this.pos;
	return &this.sprite;
}

enum EntityType {
	INDESTRUCTIBLE_DECORATION,
	PICKUP,
	FOLLOWER,
	DECAL,
}

fn bool Entity.is_type(Entity* this, EntityType t) {
	return t == this.type;
}

fn bool Entity.can_collide(Entity* this) {
	if (this.type == EntityType.DECAL) {
		return false;
	}
	else {
		return true;
	}
}

// TODO: replace this with the 'think' function for entities which have it
fn void update_entities(EntityList* entities, Player* player) {
	foreach (&ent : *entities) {
		if (ent.dead) continue;

		ent.think(ent, player);
		/* switch (ent.type) {
			case EntityType.INDESTRUCTIBLE_DECORATION: break;
			case EntityType.PICKUP:
				
			break;
			case EntityType.FOLLOWER:
				
			break;
			case EntityType.DECAL:
				ent.timer.tick_secs(raylib::get_frame_time());
				if (ent.timer.finished()) {
					ent.dead = true; // TODO: possibly put decals in a seperate list
									 // so they get actually removed
					ent.timer.reset();
				}
			break;
			default:
				io::printfn("WARNING: ENTITY TYPE NOT IMPLEMENTED: %d", ent.type);
				break;
		}*/
	}
}

fn Vec2 process_body_collisions(MapCell* map, EntityList entities, Vec2 pos, Body body, Entity* this) {
	if (this != null && this.dead) return pos;

	Vec2 final_pos = pos;
	Vec2 vel = body.vel;

	int[<2>] map_pos = (int[<2>])(pos);

	Vec2 next_pos = pos + body.vel * raylib::get_frame_time();
	// don't check for map collisions outside of the map 
	// TODO: (add one to avoid clipping into stuff from outside)
	if (next_pos.x <= world::MAP_WIDTH && next_pos.x >= 0 && next_pos.y <= world::MAP_HEIGHT && next_pos.y >= 0) {
		Rect[NUM_COLLISION_NEIGHBOURS + NUM_ADDITIONAL_COLLISION_RECT] rects;

		// loop in the 9 neighbouring squares and check which aren't empty 
		// to fill in rects array.
		for (int y = -1; y <= 1; y ++) {
			if (y + map_pos.y < 0 || y + map_pos.y >= world::MAP_HEIGHT) continue;

			for (int x = -1; x <= 1; x ++) {
				if (x + map_pos.x < 0 || x + map_pos.x >= world::MAP_WIDTH) continue;

				if (map[(map_pos.y + y) * world::MAP_WIDTH + (map_pos.x + x)] > 0) {
					rects[(y + 1) * 3 + (x + 1)] = {(float)((map_pos.x + x)), (float)((map_pos.y + y)), 1, 1};
				}
				else {
					rects[(y + 1) * 3 + (x + 1)] = {(float)((map_pos.x + x)), (float)((map_pos.y + y)), 0, 0};
				}
			}
		}

		for (int i = NUM_COLLISION_NEIGHBOURS; i < NUM_COLLISION_NEIGHBOURS + NUM_ADDITIONAL_COLLISION_RECT; i ++) {
			//foreach (&ent : entities) ent.sprite.player_dist = ent.pos.distance(pos);
			// TODO: maybe rename player_dist? it doesn't make a lot of sense in this situation
			//sort::quicksort(entities, fn int(Entity* a, Entity* b) => (int)((b.sprite.player_dist - a.sprite.player_dist) * 1000.0));
			
			Entity* ent = entities.get_ref(i - NUM_COLLISION_NEIGHBOURS);
			if (ent != null && ent.can_collide() && ent.body.collides == true && !ent.dead && ent != this) {
				rects[i] = ent.body.centred_box(ent.pos);
			}
		}

		bool[<2>] can_advance = {true, true};

		for (int i = 0; i < NUM_COLLISION_NEIGHBOURS + NUM_ADDITIONAL_COLLISION_RECT; i ++) {
			if (rects[i].w == 0) continue; // BTEC Rust options :P

			Rect next_hitbox = {(float)(next_pos.x - player::PLAYER_SIDE_LENGTH / 2.0), (float)(next_pos.y - player::PLAYER_SIDE_LENGTH / 2.0), (float)player::PLAYER_SIDE_LENGTH, (float)player::PLAYER_SIDE_LENGTH};

			if (rects[i].contains_rect(next_hitbox)) {
				Rect intersection = rects[i].intersection(next_hitbox);

				vel.x = (double)(intersection.w);
				vel.y = (double)(intersection.h);
			}

			double next_x = pos.x + body.vel.x * raylib::get_frame_time();
			Rect x_hitbox = {(float)(next_x - player::PLAYER_SIDE_LENGTH / 2.0), (float)(pos.y - player::PLAYER_SIDE_LENGTH / 2.0), (float)player::PLAYER_SIDE_LENGTH, (float)player::PLAYER_SIDE_LENGTH};
			if (rects[i].contains_rect(x_hitbox)) {
				can_advance.x = false;
			}

			double next_y = pos.y + body.vel.y * raylib::get_frame_time();
			Rect y_hitbox = {(float)(pos.x - player::PLAYER_SIDE_LENGTH / 2.0), (float)(next_y - player::PLAYER_SIDE_LENGTH / 2.0), (float)player::PLAYER_SIDE_LENGTH, (float)player::PLAYER_SIDE_LENGTH};
			if (rects[i].contains_rect(y_hitbox)) {
				can_advance.y = false;
			}
		}

		//can_advance = {true, true};
		double next_x = pos.x + body.vel.x * raylib::get_frame_time();
		double next_y = pos.y + body.vel.y * raylib::get_frame_time();

		if (can_advance.x) final_pos.x = next_x;
		if (can_advance.y) final_pos.y = next_y;
	}
	else {
		final_pos = next_pos;
	}

	// TODO: return vel
	return final_pos;
}
