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
import room_gen;
import world;
import assets;
import entity;
import sprite;
import player;
import thinkers;


const String MISSING_FILEPATH = "assets/missing.png";

const Colour RED = {255, 0, 0, 255};
const Colour WHITE = {255, 255, 255, 255};
const Colour BACKGROUND_COL = {0x18, 0x18, 0x18, 0xFF};

const double FOV_ANGLE = 30 * (math::PI/180);//math::PI/2.0;
const double PITCH_ANGLE = 0.66;


const int WIDTH_FACTOR = 4;
const int HEIGHT_FACTOR = 3;
const int WINDOW_SCALING_FACTOR = 100;
const float RENDER_SCREEN_PERCENT = 0.6;

const uint RENDER_WINDOW_WIDTH = (uint)((float)(WIDTH_FACTOR * WINDOW_SCALING_FACTOR) * RENDER_SCREEN_PERCENT);
const uint RENDER_WINDOW_HEIGHT = (uint)((float)(HEIGHT_FACTOR * WINDOW_SCALING_FACTOR) * RENDER_SCREEN_PERCENT);

const uint WINDOW_WIDTH = WIDTH_FACTOR * WINDOW_SCALING_FACTOR;
const uint WINDOW_HEIGHT = HEIGHT_FACTOR * WINDOW_SCALING_FACTOR;

const float MINIMAP_SCALE_FACTOR = 50.0;
const uint COLUMN_PIXEL_WIDTH = 1;
const uint PIXEL_HEIGHT = 1;

// DEBUG

bool draw_minimap = false;
bool draw_floor_and_ceiling = true;

//------

fn Vec2 float.angle_to_cart(float this) {
	return {math::cos(this), math::sin(this)};
}

fn Vec2 double.angle_to_cart(double this) {
	return {math::cos(this), math::sin(this)};
}

usz time = 0;


fn void! main() {
	// FIXME: prototype
	room_gen::generate_rooms();

	raylib::init_window(WINDOW_WIDTH, WINDOW_HEIGHT, "hello from c3");
	defer raylib::close_window();

	raylib::set_target_fps(60);

	World world;
	world.map = (MapCell*)calloc(world::MAP_WIDTH * world::MAP_HEIGHT * MapCell.sizeof);

	Image missing = raylib::load_image(MISSING_FILEPATH);
	while(!raylib::is_image_ready(missing)) {}
	Assets assets; 
	assets.new_init();

	assets.set_type_default(
		AssetType.PNGIMAGE,
		Asset {
			.desc = AssetDescriptor {
				.name = "missing",
				.filepath = MISSING_FILEPATH,
				.type = AssetType.PNGIMAGE
			},
			.data = (void*)&missing,
			.ready = false,
		}
	);

	io::printfn("%d", assets.default_names.get(AssetType.PNGIMAGE)!!);

	(void)assets.load_many({
		{"pistol", "assets/weapons/pistol.png", AssetType.PNGIMAGE},
	})!;
	AssetHandleList world_textures = assets.load_many({
		{"col_test", "assets/col_test.png", AssetType.PNGIMAGE},
		{"brick_wall", "assets/brick_wall.png", AssetType.PNGIMAGE},
	})!;
	AssetHandleList sprite_textures = assets.load_many({
		{"barrel", "assets/sprites/barrel.png", AssetType.PNGIMAGE},
		{"boy", "assets/sprites/boy.png", AssetType.PNGIMAGE},
	})!;
	sprite_textures.len();
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
		return; // TODO: Error handling
	}



	for (int i = 0; i < world::MAP_HEIGHT; ++i) {
		for (int j = 0; j < world::MAP_WIDTH; ++j) {
			if (i == 0 && j != 0 || i == j) {
				world.map[(i * world::MAP_WIDTH + j)] = 2;
			}
		}
	}

	world.map[5 * world::MAP_WIDTH + 1] = 1;
	Player player = Player {
		.pos = {3.0, 6.0f},
		.body = entity::new_body(player::PLAYER_SIDE_LENGTH, player::PLAYER_SIDE_LENGTH),
		.camera_plane = {0.0, 0.66},
		.dir = math::PI,
		.dir_vel = 0.0,
		.gun = NONE,
		.moving = false,
	};
	Weapon player_prev_gun = Weapon.NONE;
	Texture player_gun_tex;

	SpriteList sprites_to_render;

	world.entities.push(
		entity::new_dummy(
			EntityType.INDESTRUCTIBLE_DECORATION,
			{2, 3},
			sprite::new_sprite(0, 0, {1.0, 1.0})
		)
	);


	world.entities.push(
		entity::new_thinker(
			EntityType.PICKUP,
			{5, 7},
			sprite::new_sprite(1, 0, {0.5, 1.0}),
			entity::new_body(0.5, 0.5, false),
			&thinkers::be_pickup,
		)
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

	bool poll_assets = true;

	while (!raylib::window_should_close()) {
		time ++;

		if (poll_assets) {
			poll_assets = assets.poll_ready()!!;
		}

		sprites_to_render.clear();
		foreach (&entity : world.entities) {
			// TODO: make this line of sight lmao? it's not fucking impossible, you can do 
			// ANYTHING (maybe not anything)
			if (!entity.dead) {
				sprites_to_render.push(entity.get_sprite());
			}
		}

		raylib::begin_drawing();

		raylib::clear_background(BACKGROUND_COL);

		for (int i = 0; i < RENDER_WINDOW_HEIGHT * RENDER_WINDOW_WIDTH; i ++) pixels[i] = BACKGROUND_COL;
		
		// ---------------------------------------------------------------------
		// RAYCAST AND BLIT TEXTURE
		// ---------------------------------------------------------------------

		if (draw_floor_and_ceiling) (void)rendering::raycast_floors(&player, world.map, &assets, &world_textures, pixels);

		for (int i = 0; i < RENDER_WINDOW_WIDTH; i ++) z_buffer[i] = math::DOUBLE_MAX;
		(void)rendering::raycast_walls(&player, world.map, &assets, &world_textures, pixels, z_buffer);

		(void)rendering::render_sprites(&player, &sprites_to_render, &assets, &sprite_textures, pixels, z_buffer);

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
			for (int y = 0; y < world::MAP_HEIGHT; y ++) {
				for (int x = 0; x < world::MAP_WIDTH; x ++) {
					if (world.map[y * world::MAP_WIDTH + x] > 0) {
						raylib::draw_rectangle(x * (int)MINIMAP_SCALE_FACTOR, y * (int)MINIMAP_SCALE_FACTOR, (int)MINIMAP_SCALE_FACTOR, (int)MINIMAP_SCALE_FACTOR, {200, 200, 200, 100});
					}
				}
			}
		}

		Rect random = {5.5, 8, 1, 1};
		if (draw_minimap) {
			Vec2 pos = (player.pos * MINIMAP_SCALE_FACTOR);
			raylib::draw_rectangle(
				(int)((pos.x - player::PLAYER_SIDE_LENGTH/2)), 
				(int)((pos.y - player::PLAYER_SIDE_LENGTH/2)), 
				(int)(player::PLAYER_SIDE_LENGTH * MINIMAP_SCALE_FACTOR), 
				(int)(player::PLAYER_SIDE_LENGTH * MINIMAP_SCALE_FACTOR), 
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
			player::display_held(&player, &assets, &player_gun_tex, player_prev_gun);
		}
		player_prev_gun = player.gun;

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
			turn_acc += player::PLAYER_TURN_ACCELERATION;
		}

		if (raylib::is_key_down(raylib::KEY_A) && raylib::is_key_down(raylib::KEY_LEFT_ALT)) {
			acc -= player.dir.angle_to_cart().rotate(-math::PI_2); 
		}
		else if (raylib::is_key_down(raylib::KEY_A)) {
			turn_acc -= player::PLAYER_TURN_ACCELERATION;
		}

		if (raylib::is_key_pressed(raylib::KEY_SPACE)) {
			player::attack(&world, &assets, &world.entities, &player, false);
		}

		acc = acc.normalize() * player::PLAYER_ACCELERATION;
		
		player.body.vel += acc * raylib::get_frame_time();

		player.pos = entity::process_body_collisions(world.map, world.entities, player.pos, player.body, null);
		player.body.vel *= player::PLAYER_VEL_DAMPING;

		player.dir_vel += turn_acc * raylib::get_frame_time();
		player.dir -= player.dir_vel;
		
		player.camera_plane = player.camera_plane.rotate(-(double)player.dir_vel);
		player.dir_vel *= player::PLAYER_TURN_DAMPING;

		entity::update_entities(&world.entities, &player);

		if (player.body.vel.length_sq() < player::MINIMUM_MOVEMENT_THRESHOLD) {
			player.body.vel = {0,0};
			player.moving = false;
		}
		else {
			player.moving = true;
		}

		foreach (&ent : world.entities) {
			if (!ent.dead && ent.type == EntityType.FOLLOWER) {
				ent.pos = entity::process_body_collisions(world.map, world.entities, ent.pos, ent.body, ent);
				ent.body.vel *= player::PLAYER_VEL_DAMPING;
			}
		}

		world::update_world_occupied_cells(&world, world.entities, &player);
		
	} // GAMELOOP
}
