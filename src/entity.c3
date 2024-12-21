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

import monster;
import thinkers;

const usz NUM_COLLISION_NEIGHBOURS = 9;
const usz NUM_ADDITIONAL_COLLISION_RECT = 10; // how many more things we can collide with outside of 9 neighbours
const usz FRICTIONLESS = 0b1;


fault EntityError {
	INVALID_STATE,
}

struct Body {
	bool simulated;
	bool collides;
	bool moving;
	// in radians
	double dir;
	double dir_vel;
	Vec2 camera_plane;

	Vec2 vel;
	Vec2 acc;
	Vec2 scale; // every hitbox is a rectangle or a box, so we just need width and height
				// to create a hitbox centred on Entity.pos

	usz flags; 
	usz collision_layer; // TODO!
}

fn void Body.update(&self, float dt) {
	self.dir -= self.dir_vel * dt;
	self.dir = self.dir.rem(2.0*math::PI);
	self.camera_plane = self.camera_plane.rotate(-(double)(self.dir_vel * dt));
	
	if (self.flags & entity::FRICTIONLESS == 0) {
		self.vel *= player::PLAYER_VEL_DAMPING;
	}

	if (self.vel.length_sq() < player::MINIMUM_MOVEMENT_THRESHOLD) {
		self.vel = {0,0};
		self.moving = false;
	}
	else {
		self.moving = true;
	}

	self.dir_vel *= player::PLAYER_TURN_DAMPING;
}

fn Body new_body(double w, double h, bool collides = true, bool simulated = true, float dir = math::PI, float dir_vel = 0.0) {
	Body body = Body {
		.simulated = true,
		.collides = true,
		.vel = {0.0, 0.0},
		.acc = {0.0, 0.0},
		.dir = dir,
		.dir_vel = dir_vel,
		.camera_plane = {0, 0.45}, // default small FOV
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
	inline Body body;
	EntityModel model;

	Vec2 pos;
	
	bool dead;
	
	ThinkFunction think;
	Timer timer;

	EntityType type;
	any state;
}

enum EntityType {
	INDESTRUCTIBLE_DECORATION,
	PICKUP,
	FOLLOWER,
	DECAL,
	PROJECTILE,
	SMART_FELLA,
}

struct ProjectileState {
	float dmg;
}

fn any! Entity.get_state(&self, EntityType type) {
	if (self.type != type) {
		return EntityError.INVALID_STATE?;
	}

	return self.state;
}

fn Entity new_monster(
	Vec2 pos,
	EntityModel model,
	any state,
	ThinkFunction think_fn = &thinkers::default_monster,
	Timer timer = timer::new_secs(1.0),
	Body body = new_body(1,1),
) {
	return Entity {
		.type = EntityType.SMART_FELLA,
		.pos = pos,
		.model = model,
		.body = body,
		.timer = timer,
		.think = think_fn,
		.state = state,
		.dead = false,
	};
}

fn Entity new_thinker(
	EntityType 		type, 
	Vec2 			pos, 
	EntityModel 			model, 
	ThinkFunction 	think_fn = &thinkers::default_think, 
	Body 			body 	 = new_body(1,1), 
	Timer 			timer 	 = timer::new_secs(1.0),
	bool 			dead	 = false
) {
	return Entity {
		.type = type,
		.pos = pos,
		.model = model,
		.body = body,
		.timer = timer,
		.think = think_fn,
		.dead = dead,
	};
}

fn Entity new_projectile(Vec2 pos, Vec2 vel, EntityModel model, Body body, ProjectileState* state, Timer duration = timer::new_secs(5.0), ThinkFunction think_fn = &thinkers::default_projectile) {
	body.flags |= FRICTIONLESS;
	body.vel = vel;
	return Entity {
		.type = EntityType.PROJECTILE,
		.pos = pos,
		.model = model,
		.body = body,
		.think = think_fn,
		.state = any_make(state, ProjectileState.typeid),
		.timer = duration,
		.dead = false,
	};
}

fn Entity new_dummy(
	EntityType 		type, 
	Vec2 			pos, 
	EntityModel 			model, 
	Body 			body 	 = new_body(1,1), 
	Timer 			timer 	 = timer::new_secs(1.0),
	bool 			dead	 = false
) {
	return Entity {
		.type = type,
		.pos = pos,
		.model = model,
		.body = body,
		.timer = timer,
		.think = &thinkers::default_think,
		.dead = dead,
	};
}

fn Entity new_decal(Vec2 pos, double z, int texture_index, float duration_secs) {
	return Entity {
		.type = EntityType.DECAL,
		.pos = pos,
		.model = sprite::new_sprite(texture_index, z, {1.0, 1.0}),
		.think = &thinkers::slowly_die,
		.timer = timer::new_secs(duration_secs),
		.dead = false,
	};
}

fn EntityModel* Entity.get_model(Entity* this) {
	this.model.pos = this.pos;
	this.model.dir = this.body.dir;
	return &this.model;
}



fn bool Entity.is_type(Entity* this, EntityType t) {
	return t == this.type;
}

fn bool Entity.can_collide(Entity* this) {
	switch (this.type) {
		case EntityType.DECAL:
		case EntityType.PICKUP:
			return false;
		default:
			return true;
	}
}

// TODO: replace this with the 'think' function for entities which have it
fn void update_entities(World* w, EntityList* entities) {
	bool should_remove_dead_ents = false;
	foreach (i, &ent : *entities) {
		if (ent.dead) continue;

		ThinkResult res = ent.think(ent, w);
		switch (res) {
			case ThinkResult.KILLME:
				should_remove_dead_ents = true;
			break;
			case ThinkResult.NOT_ME_ERROR:
				io::printfn("ERROR: Thinker has incorrect think function for its entity type, got %s", EntityType.names[ent.type]);
			break;
			case ThinkResult.OK:
			case ThinkResult.FINISHED:
			break;
			default:
				io::printfn("ERROR: Unhandled ThinkResult %s", ThinkResult.names[res]);
			break;
		}
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
	
	if (should_remove_dead_ents) {
		io::printn("INFO: removing dead guys");
		entities.retain_using_test(fn bool(Entity* ent, any _ctx) => !ent.dead, null);
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
			
			if (entities.len() <= i - NUM_COLLISION_NEIGHBOURS) {
				continue;
			}
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

// here bc it screws with sublime text :,)
def EntityList = List(<Entity>);
def ThinkFunction = fn ThinkResult(Entity*, World*);