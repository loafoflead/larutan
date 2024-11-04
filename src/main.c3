import std::sort;
import std::io;
import std::math;
import std::core::mem;
import libc;
import std::thread;
import std::collections::list;

import raylib;
import rendering;
import math;

def SpriteList = List(<Sprite*>);
def EntityList = List(<Entity>);
def IndexList = List(<usz>);

const Colour RED = {255, 0, 0, 255};
const Colour WHITE = {255, 255, 255, 255};
const Colour BACKGROUND_COL = {0x18, 0x18, 0x18, 0xFF};

const float PLAYER_SIDE_LENGTH = 0.2f;
const usz NUM_COLLISION_NEIGHBOURS = 9;
const usz NUM_ADDITIONAL_COLLISION_RECT = 10; // how many more things we can collide with outside of 9 neighbours

const float PLAYER_ACCELERATION = 50.0; // Grid squares per second
const float PLAYER_VEL_DAMPING = 0.9;

const float PLAYER_TURN_ACCELERATION = math::PI_2; // RADIANS per second per second
const float PLAYER_TURN_DAMPING = 0.7; // RADIANS per second

const double FOV_ANGLE = 30 * (math::PI/180);//math::PI/2.0;
const double PITCH_ANGLE = 0.66;

enum Weapon : int (String sprite_path)
{
	NONE = "assets/missing.png",
	PISTOL = "assets/weapons/pistol.png",
}

fn bool Weapon.has_altfire(Weapon weapon) {
	switch(weapon) {
		case PISTOL:
			return false;
		default:
			return false;
	}
}

const int WIDTH_FACTOR = 16;
const int HEIGHT_FACTOR = 9;
const int WINDOW_SCALING_FACTOR = 100;
const float RENDER_SCREEN_PERCENT = 0.5;

const uint RENDER_WINDOW_WIDTH = (uint)((float)(WIDTH_FACTOR * WINDOW_SCALING_FACTOR) * RENDER_SCREEN_PERCENT);
const uint RENDER_WINDOW_HEIGHT = (uint)((float)(HEIGHT_FACTOR * WINDOW_SCALING_FACTOR) * RENDER_SCREEN_PERCENT);

const uint WINDOW_WIDTH = WIDTH_FACTOR * WINDOW_SCALING_FACTOR;
const uint WINDOW_HEIGHT = HEIGHT_FACTOR * WINDOW_SCALING_FACTOR;


def MapCell = short;
const uint MAP_WIDTH = 30;
const uint MAP_HEIGHT = MAP_WIDTH;
const Rect MAP_RECT = Rect { 0, 0, MAP_WIDTH, MAP_HEIGHT };

const uint MAP_GRID_SIZE = 1;
const float MINIMAP_SCALE_FACTOR = 50.0;
const double MAP_AABB_RAYCAST_CHECK_RAY_STEP = 0.05;

const uint COLUMN_PIXEL_WIDTH = 1;
const uint PIXEL_HEIGHT = 1;

const uint TEXTURE_COUNT = 1;

// DEBUG

bool draw_minimap = false;
bool draw_floor_and_ceiling = true;

//------

const usz WORLD_TEXTURES_COUNT = 1;
const usz SPRITE_TEXTURES_COUNT = 1;
const usz WEAPON_TEXTURES_COUNT = 1;

struct Assets {
	Image* world_textures;
	Image* sprite_textures;
	Image* weapon_textures;
	Image missing;
}

macro Assets.@get(&self, category, idx) {
	switch (category) {
		case "ws":
		case "weapons":
			if (idx < 0 || idx >= WEAPON_TEXTURES_COUNT) return &self.missing;

			return &self.weapon_textures[idx];
		break;
		case "w":
		case "wrld":
		case "world":
			if (idx < 0 || idx >= WORLD_TEXTURES_COUNT) return &self.missing;

			return &self.world_textures[idx];
		break;
		case "s":
		case "sprite":
			if (idx < 0 || idx >= SPRITE_TEXTURES_COUNT) return &self.missing;

			return &self.sprite_textures[idx];
		break;
		default:
			return &self.missing;
	}
	return &self.missing;
}

fn Image* Assets.load_images(Assets this, String[] paths) {

	io::printn("TODO: don't do this, make it similar to the '@get' interface, and make the sizes not be constants because that's a bit schewpid in the year of our lord twenty twenty four");

	foreach (path: paths) {
		// TODO: don't do this, make it similar to the '@get'
		// interface, and make the sizes not be constants because that's a 
		// bit schewpid in the year of our lord twenty twenty four
	}
	return null;
}

fn void Assets.free(Assets this) {
	io::printfn("TODO: IMPLEMENT FREEING ASSETS");

	//for (int i = 0; i < TEXTURE_COUNT; i ++) raylib::unload_image(textures[i]);

}

fn bool Assets.assert_loaded(Assets this) {
	io::printfn("TODO: IMPLEMENT CHECKING ASSETS LOADED CORRECTLY");

	return true;
	//for (int i = 0; i < TEXTURE_COUNT; i ++) {
	//	if (textures[i].data == null) {
	//		io::printfn("Failed to load '%s', file not found or corrupt.", image_paths[i ]);
	//		return -1;
	//	}
	//	else if (textures[i].format != 7) {
	//		io::printfn("Failed to load '%s', file is in the wrong pixel format (need R8G8B8A8, soit 32bpp)\n", image_paths[i]);
	//		return -1;
	//	}
	//}
}

struct World {
	MapCell* map;
	// list of cells that have a sprite in them, so that when raycasting into 
	// the world we can check if we hit a sprite when entering 
	// a cell. (presumably (haven't implemented yet) this is gonna have 
	// similar bug as in doom where you won't raycast hit a bit sprite bc it overlaps
	// collision 'sectors')
	IndexList occupied_cells;
}

fn bool World.ray_hits(World* this, Vec2 og, Vec2 dir, EntityList* ents) {
	RaycastHit hit = rendering::cast_ray(this.map, og, dir);

	// just checking if it hit or not...
	if (hit.hit) return true;

	// check for entities and stuff now
	MapCell* temp_map = mem::new_array(MapCell, MAP_WIDTH*MAP_HEIGHT);
	defer free(temp_map);

	foreach(cell: this.occupied_cells) {
		temp_map[cell] = 1;
	}

	// check if a cell that contains an entity is hit with a raycast
	hit = rendering::cast_ray(temp_map, og, dir);

	if (hit.hit) {
		// FIXME: extremely naive and frankly shit implementation
		Vec2 hit_pt = og + dir * hit.dist;

		foreach(ent:ents) {
			for (int i = 0; i < (int)(1.0 / MAP_AABB_RAYCAST_CHECK_RAY_STEP); i ++) {
				if (ent.body.centred_box(ent.pos).contains(hit_pt)) {
					return true;
				}
				hit_pt += MAP_AABB_RAYCAST_CHECK_RAY_STEP * dir;
			}
		}
	}

	return false;
}

struct Sprite {
	usz texture_index;
	Vec2 uv_scale_division;
	double z;
	// effectively private variables
	Vec2 pos;
	double player_dist;
}

fn Sprite new_sprite(usz texture_index, double z, Vec2 uv_scale_division) {
	Sprite new = Sprite {
		.texture_index = texture_index,
		.z = z,
		.uv_scale_division = uv_scale_division,
		.pos = {0, 0},
		.player_dist = 0.0,
	};
	return new;
}

struct Body {
	bool simulated;
	bool collides;
	Vec2 vel;
	Vec2 acc;
	Vec2 scale; // every hitbox is a rectangle or a box, so we just need width and height
				// to create a hitbox centred on Entity.pos
}

fn Body new_body(double w, double h) {
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
	EntityType type;
	Body body;
	bool dead;
}

fn Sprite* Entity.get_sprite(Entity* this) {
	this.sprite.pos = this.pos;
	return &this.sprite;
}

enum EntityType {
	INDESTRUCTIBLE_DECORATION,
	PICKUP,
	FOLLOWER,
}

struct Player {
	Vec2 pos;
	Body body;
	Vec2 camera_plane;
	// in radians
	float dir;
	float dir_vel;
	// inv
	Weapon gun;
}

fn Rect Player.centred_hitbox(Player* this) {
	Rect rect = {
		(float)this.pos.x - PLAYER_SIDE_LENGTH / 2.0f,
		(float)this.pos.y - PLAYER_SIDE_LENGTH / 2.0f,
		PLAYER_SIDE_LENGTH,
		PLAYER_SIDE_LENGTH,
	};
	return rect;
}

fn Vec2 float.angle_to_cart(float this) {
	return {math::cos(this), math::sin(this)};
}

fn Vec2 double.angle_to_cart(double this) {
	return {math::cos(this), math::sin(this)};
}

usz time = 0;

fn void update_entities(EntityList* entities, Player* player) {
	foreach (&ent : *entities) {
		if (ent.dead) continue;
		switch (ent.type) {
			case EntityType.INDESTRUCTIBLE_DECORATION: break;
			case EntityType.PICKUP:
				if (ent.body.collides == true || ent.body.simulated) {
					ent.body.collides = false;
					ent.body.simulated = false;
				}
				ent.sprite.z = math::sin(time / 20.0) * 100;
				if (ent.body.centred_box(ent.pos).contains_rect(player.centred_hitbox())) {
					ent.dead = true;
					player.gun = PISTOL;
					io::printfn("TODO: implement picking up items.");
				}
			break;
			case EntityType.FOLLOWER:
				Vec2 to_player = player.pos - ent.pos;
				ent.body.vel += to_player * raylib::get_frame_time() * 10;
			break;
			default:
				io::printfn("WARNING: ENTITY TYPE NOT IMPLEMENTED: %d", ent.type);
				break;
		}
	}
}

fn Vec2 process_body_collisions(MapCell* map, EntityList entities, Vec2 pos, Body body, Entity* this) {
	Vec2 final_pos = pos;
	Vec2 vel = body.vel;

	int[<2>] map_pos = (int[<2>])(pos / MAP_GRID_SIZE);

	Vec2 next_pos = pos + body.vel * raylib::get_frame_time();
	// don't check for map collisions outside of the map 
	// TODO: (add one to avoid clipping into stuff from outside)
	if (next_pos.x / MAP_GRID_SIZE <= MAP_WIDTH && next_pos.x >= 0 && next_pos.y / MAP_GRID_SIZE <= MAP_HEIGHT && next_pos.y >= 0) {
		Rect[NUM_COLLISION_NEIGHBOURS + NUM_ADDITIONAL_COLLISION_RECT] rects;

		// loop in the 9 neighbouring squares and check which aren't empty 
		// to fill in rects array.
		for (int y = -1; y <= 1; y ++) {
			if (y + map_pos.y < 0 || y + map_pos.y >= MAP_HEIGHT) continue;

			for (int x = -1; x <= 1; x ++) {
				if (x + map_pos.x < 0 || x + map_pos.x >= MAP_WIDTH) continue;

				if (map[(map_pos.y + y) * MAP_WIDTH + (map_pos.x + x)] > 0) {
					rects[(y + 1) * 3 + (x + 1)] = {(float)((map_pos.x + x) * MAP_GRID_SIZE), (float)((map_pos.y + y) * MAP_GRID_SIZE), MAP_GRID_SIZE, MAP_GRID_SIZE};
				}
				else {
					rects[(y + 1) * 3 + (x + 1)] = {(float)((map_pos.x + x) * MAP_GRID_SIZE), (float)((map_pos.y + y) * MAP_GRID_SIZE), 0, 0};
				}
			}
		}

		for (int i = NUM_COLLISION_NEIGHBOURS; i < NUM_COLLISION_NEIGHBOURS + NUM_ADDITIONAL_COLLISION_RECT; i ++) {
			//foreach (&ent : entities) ent.sprite.player_dist = ent.pos.distance(pos);
			// TODO: maybe rename player_dist? it doesn't make a lot of sense in this situation
			//sort::quicksort(entities, fn int(Entity* a, Entity* b) => (int)((b.sprite.player_dist - a.sprite.player_dist) * 1000.0));
			
			Entity* ent = entities.get_ref(i - NUM_COLLISION_NEIGHBOURS);
			if (ent != null && ent.body.collides == true && !ent.dead && ent != this) {
				rects[i] = ent.body.centred_box(ent.pos);
			}
		}

		bool[<2>] can_advance = {true, true};

		for (int i = 0; i < NUM_COLLISION_NEIGHBOURS + NUM_ADDITIONAL_COLLISION_RECT; i ++) {
			if (rects[i].w == 0) continue; // BTEC Rust options :P

			raylib::draw_rectangle((int)(rects[i].x * MINIMAP_SCALE_FACTOR), (int)(rects[i].y * MINIMAP_SCALE_FACTOR), (int)(rects[i].w * MINIMAP_SCALE_FACTOR), (int)(rects[i].h * MINIMAP_SCALE_FACTOR), RED);

			Rect next_hitbox = {(float)(next_pos.x - PLAYER_SIDE_LENGTH / 2.0), (float)(next_pos.y - PLAYER_SIDE_LENGTH / 2.0), (float)PLAYER_SIDE_LENGTH, (float)PLAYER_SIDE_LENGTH};

			if (rects[i].contains_rect(next_hitbox)) {
				Rect intersection = rects[i].intersection(next_hitbox);

				vel.x = (double)(intersection.w);
				vel.y = (double)(intersection.h);
			}

			double next_x = pos.x + body.vel.x * raylib::get_frame_time();
			Rect x_hitbox = {(float)(next_x - PLAYER_SIDE_LENGTH / 2.0), (float)(pos.y - PLAYER_SIDE_LENGTH / 2.0), (float)PLAYER_SIDE_LENGTH, (float)PLAYER_SIDE_LENGTH};
			if (rects[i].contains_rect(x_hitbox)) {
				can_advance.x = false;
			}

			double next_y = pos.y + body.vel.y * raylib::get_frame_time();
			Rect y_hitbox = {(float)(pos.x - PLAYER_SIDE_LENGTH / 2.0), (float)(next_y - PLAYER_SIDE_LENGTH / 2.0), (float)PLAYER_SIDE_LENGTH, (float)PLAYER_SIDE_LENGTH};
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

fn void update_world_occupied_cells(World* world, EntityList entities, Player* player) {
	world.occupied_cells.clear();
	// TODO: shit
	for (int y = 0; y < MAP_HEIGHT; y ++) {
		for (int x = 0; x < MAP_WIDTH; x++) {
			Rect rect = {x, y, 1, 1};

			foreach(&ent: entities) {
				if (!MAP_RECT.contains(ent.pos.round())) continue;

				if (rect.intersection(ent.body.centred_box(ent.pos)).equals(math::ZERO)) {
					if (!world.occupied_cells.contains((ulong)(y * MAP_WIDTH + x))) {
						world.occupied_cells.push((ulong)(y * MAP_WIDTH + x));
					}
				}
			}
		}
	}

	if (!MAP_RECT.contains(player.pos.round())) return;

	usz[<2>] player_map_pos = (usz[<2>])player.pos.round();
	world.occupied_cells.push(player_map_pos.y * MAP_WIDTH + player_map_pos.x);
}


// Fire is alt or main
fn void player_attack(World* world, EntityList* ents, Player* player, bool altfired) {
	// if altfiring a gun w/ no altfire, don't shoot (don't shoot!!)
	if ((altfired && !player.gun.has_altfire()) || player.gun == Weapon.NONE) return; 

	if (!altfired) {

	switch(player.gun) {

		case PISTOL:
			if (world.ray_hits(player.pos, player.dir.angle_to_cart(), ents)) {
				io::printn("Raycast hits");
			}
			else {
				io::printn("Raycast MISSES");
			}
		break;

		default:
			io::printfn("ERROR: attempt to fire weapon that has not yet been implemented. (Sprite: %s)", player.gun.sprite_path);
		break;
	}

	}
}

fn int main() {
	raylib::init_window(WINDOW_WIDTH, WINDOW_HEIGHT, "hello from c3");
	defer raylib::close_window();

	raylib::set_target_fps(60);

	World world;
	world.map = (MapCell*)calloc(MAP_WIDTH * MAP_HEIGHT * MapCell.sizeof);

	Assets assets;
	assets.missing = raylib::load_image("assets/missing.png");
	assets.weapon_textures = assets.load_images({"assets/weapons/pistol.png"});
	assets.world_textures = assets.load_images({"assets/col_test.png","assets/brick_wall.png"});
	assets.sprite_textures = assets.load_images({"assets/sprites/barrel.png","assets/sprites/boy.png"});
	/*Image* textures = (Image*)calloc(TEXTURE_COUNT * Image.sizeof);
	String[TEXTURE_COUNT] image_paths = {
		"assets/col_test.png",
		"assets/brick_wall.png",
		"assets/sprites/barrel.png",
		"assets/sprites/boy.png",
	};
	for (int i = 0; i < TEXTURE_COUNT; i++) {
		textures[i] = raylib::load_image(image_paths[i]);
	}*/

	Image render_img = raylib::gen_image_colour(RENDER_WINDOW_WIDTH, RENDER_WINDOW_HEIGHT, WHITE);
	Texture tex = raylib::load_texture_from_image(render_img);

	defer raylib::unload_texture(tex);

	defer raylib::unload_image(render_img);

	double* z_buffer = (double*)calloc(RENDER_WINDOW_WIDTH * double.sizeof);
	defer free(z_buffer);

	Colour* pixels = (char[<4>]*)calloc(RENDER_WINDOW_HEIGHT * RENDER_WINDOW_WIDTH * 4);
	defer free(pixels);

	defer assets.free();
	//defer free(textures);

	if (assets.assert_loaded() == false) {
		return -1;
	}



	for (int i = 0; i < MAP_HEIGHT; ++i) {
		for (int j = 0; j < MAP_WIDTH; ++j) {
			if (i == 0 && j != 0 || i == j) {
				world.map[(i * MAP_WIDTH + j)] = 3;
			}
		}
	}

	world.map[5 * MAP_WIDTH + 1] = 3;
	Player player = Player {
		.pos = {3.0 * MAP_GRID_SIZE, 6.0f * MAP_GRID_SIZE},
		.body = new_body(PLAYER_SIDE_LENGTH, PLAYER_SIDE_LENGTH),
		.camera_plane = {0.0, 0.66},
		.dir = math::PI,
		.dir_vel = 0.0,
		.gun = NONE,
	};

	SpriteList sprites_to_render;

	EntityList entities;

	entities.push(
		Entity {
			.type = EntityType.INDESTRUCTIBLE_DECORATION,
			.pos = {2, 3},
			.sprite = new_sprite(2, 0, {1.0, 1.0}),
			.body = new_body(1, 1),
			.dead = false,
		}
	);

	entities.push(
		Entity {
			.type = EntityType.PICKUP,
			.pos = {5, 7},
			.sprite = new_sprite(3, 0, {0.5, 1.0}),
			.body = new_body(1, 1),
			.dead = false,
		}
	);

	/*entities.push(
		Entity {
			.type = EntityType.FOLLOWER,
			.pos = {5, 8},
			.sprite = new_sprite(3, 0, {1.0, 1.0}),
			.body = new_body(1, 1),
			.dead = false,
		}
	);*/

	while (!raylib::window_should_close()) {
		time ++;

		sprites_to_render.free();
		foreach (&entity : entities) {
			if (!entity.dead) sprites_to_render.push(entity.get_sprite());
		}

		raylib::begin_drawing();

		raylib::clear_background(BACKGROUND_COL);

		for (int i = 0; i < RENDER_WINDOW_HEIGHT * RENDER_WINDOW_WIDTH; i ++) pixels[i] = BACKGROUND_COL;
		
		// ---------------------------------------------------------------------
		// RAYCAST AND BLIT TEXTURE
		// ---------------------------------------------------------------------

		if (draw_floor_and_ceiling) rendering::raycast_floors(&player, world.map, &assets, pixels);

		for (int i = 0; i < RENDER_WINDOW_WIDTH; i ++) z_buffer[i] = math::DOUBLE_MAX;
		rendering::raycast_walls(&player, world.map, &assets, pixels, z_buffer);

		rendering::render_sprites(&player, &sprites_to_render, &assets, pixels, z_buffer);

		raylib::update_texture(tex, (char*)pixels);

		if (!draw_minimap) {
			raylib::draw_texture_with_params(
				tex, 
				NPatchInfo {
					.source = { 0, 0, RENDER_WINDOW_WIDTH, RENDER_WINDOW_HEIGHT },
				},
				{0, 0, WINDOW_WIDTH, WINDOW_HEIGHT},
				{0, 0},
				0.0,
				WHITE
			);
		}

		// ---------------------------------------------------------------------
		// MINIMAP
		// ---------------------------------------------------------------------

		if (draw_minimap) {
			for (int y = 0; y < MAP_HEIGHT; y ++) {
				for (int x = 0; x < MAP_WIDTH; x ++) {
					if (world.map[y * MAP_WIDTH + x] > 0) {
						raylib::draw_rectangle(x * (int)MINIMAP_SCALE_FACTOR, y * (int)MINIMAP_SCALE_FACTOR, (int)MINIMAP_SCALE_FACTOR, (int)MINIMAP_SCALE_FACTOR, {200, 200, 200, 100});
					}
				}
			}
		}

		Rect random = {5.5, 8, 1, 1};
		if (draw_minimap) {
			Vec2 pos = (player.pos * MINIMAP_SCALE_FACTOR);
			raylib::draw_rectangle(
				(int)((pos.x - PLAYER_SIDE_LENGTH/2)), 
				(int)((pos.y - PLAYER_SIDE_LENGTH/2)), 
				(int)(PLAYER_SIDE_LENGTH * MINIMAP_SCALE_FACTOR), 
				(int)(PLAYER_SIDE_LENGTH * MINIMAP_SCALE_FACTOR), 
				{255, 255, 0, 255}
			);
			// raylib::draw_line_ex(player.pos, (player.pos + player.dir.angle_to_cart() * 100.0), 5.0, {255, 0, 0, 255});

			int[<2>] next = (int[<2>])(pos + player.dir.angle_to_cart() * 100.0);
			int[<2>] perp = (int[<2>])(pos + (player.dir + math::PI_2).angle_to_cart() * RENDER_WINDOW_WIDTH / 2.0);
			int[<2>] perp2 = (int[<2>])(pos + (player.dir - math::PI_2).angle_to_cart() * RENDER_WINDOW_WIDTH / 2.0);
			int[<2>] fovleft = (int[<2>])(pos + (player.dir - FOV_ANGLE/2.0).angle_to_cart() * 100.0);
			int[<2>] fovright = (int[<2>])(pos + (player.dir + FOV_ANGLE/2.0).angle_to_cart() * 100.0);
			int[<2>] cam_plane_middle = (int[<2>])(pos + player.dir.angle_to_cart() * MINIMAP_SCALE_FACTOR);
			int[<2>] cam_plane_left = (int[<2>])((double[<2>])cam_plane_middle + player.camera_plane *
			MINIMAP_SCALE_FACTOR);

			int[<2>] cam_plane_og = (int[<2>])(pos + player.camera_plane) * (int)MINIMAP_SCALE_FACTOR;
			int[<2>] cam_plane = (int[<2>])(pos + player.camera_plane + (player.dir + math::PI_2).angle_to_cart() * 50.0);


			raylib::draw_line((int)pos.x, (int)pos.y, next.x, next.y, {0, 255, 0, 255});
			//raylib::draw_line((int)pos.x, (int)pos.y, perp.x, perp.y, {255, 255, 0, 255});
			//raylib::draw_line((int)pos.x, (int)pos.y, perp2.x, perp2.y, {255, 255, 0, 255});
			//raylib::draw_line((int)pos.x, (int)pos.y, fovleft.x, fovleft.y, {255, 255, 0, 255});
			//raylib::draw_line((int)pos.x, (int)pos.y, fovright.x, fovright.y, {255, 255, 0, 255});
			raylib::draw_line((int)cam_plane_middle.x, (int)cam_plane_middle.y, cam_plane_left.x, cam_plane_left.y, {255, 255, 0, 255});
		}

		// ---------------------------------------------------------------------
		// DRAW PLAYER GUN
		// ---------------------------------------------------------------------

		if (player.gun != Weapon.NONE) {

		}

		raylib::end_drawing();

		// ---------------------------------------------------------------------
		// PROCESS PLAYER CONTROLS
		// ---------------------------------------------------------------------

		if (raylib::is_key_pressed(raylib::KEY_RIGHT_ALT)) {
			//draw_floor_and_ceiling = !draw_floor_and_ceiling;
			draw_minimap = !draw_minimap;
		}

		Vec2 acc = {0.0, 0.0};
		float turn_acc = 0.0;

		if (raylib::is_key_down(raylib::KEY_W)) {
			acc = player.dir.angle_to_cart();
		}
		if (raylib::is_key_down(raylib::KEY_S)) {
			acc = -player.dir.angle_to_cart();
		}

		if (raylib::is_key_down(raylib::KEY_D) && raylib::is_key_down(raylib::KEY_LEFT_ALT)) {
			acc -= player.dir.angle_to_cart().rotate(math::PI_2); 
		}
		else if (raylib::is_key_down(raylib::KEY_D)) {
			turn_acc += PLAYER_TURN_ACCELERATION;
		}

		if (raylib::is_key_down(raylib::KEY_A) && raylib::is_key_down(raylib::KEY_LEFT_ALT)) {
			acc -= player.dir.angle_to_cart().rotate(-math::PI_2); 
		}
		else if (raylib::is_key_down(raylib::KEY_A)) {
			turn_acc -= PLAYER_TURN_ACCELERATION;
		}

		if (raylib::is_key_pressed(raylib::KEY_SPACE)) {
			player_attack(&world, &entities, &player, false);
		}

		acc = acc.normalize() * PLAYER_ACCELERATION;
		
		player.body.vel += acc * raylib::get_frame_time();

		player.pos = process_body_collisions(world.map, entities, player.pos, player.body, null);
		player.body.vel *= PLAYER_VEL_DAMPING;

		player.dir_vel += turn_acc * raylib::get_frame_time();
		player.dir -= player.dir_vel;
		
		player.camera_plane = player.camera_plane.rotate(-(double)player.dir_vel);
		player.dir_vel *= PLAYER_TURN_DAMPING;

		update_entities(&entities, &player);

		foreach (&ent : entities) {
			if (ent.type == EntityType.FOLLOWER) {
				ent.pos = process_body_collisions(world.map, entities, ent.pos, ent.body, ent);
				ent.body.vel *= PLAYER_VEL_DAMPING;
			}
		}

		update_world_occupied_cells(&world, entities, &player);
		
	} // GAMELOOP


	return 0;
}
