import std::sort;
import std::io;
import std::math;
import std::core::mem;
import libc;
import std::thread;
import std::collections::list;

import bindings;
import rendering;
import utils;
import world @norecurse;
import assets;
import entity, entity::thinkers;
import player;

import enemy;

import astar;

const String MISSING_FILEPATH = "assets/missing.png";

const Colour RED = {255, 0, 0, 255};
const Colour WHITE = {255, 255, 255, 255};
const Colour BACKGROUND_COL = {0x18, 0x18, 0x18, 0xFF};

const double FOV_ANGLE = 30 * (math::PI/180);//math::PI/2.0;
const double PITCH_ANGLE = 0.66;

const int WIDTH_FACTOR = 4;
const int HEIGHT_FACTOR = 3;
const int WINDOW_SCALING_FACTOR = 300;
const float RENDER_SCREEN_PERCENT = 0.2;

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
//	room_gen::generate_rooms();

	raylib::init_window(WINDOW_WIDTH, WINDOW_HEIGHT, "hello from c3");
	defer raylib::close_window();

	raylib::set_target_fps(60);

	World world;
	world.map = Grid {
		.w = world::MAP_WIDTH,
		.h = world::MAP_HEIGHT,
		.grid = mem::new_array(GridCell, world::MAP_WIDTH*world::MAP_HEIGHT),
		.empties = {0},
		.costs = {},
	};
//	(MapCell*)calloc(world::MAP_WIDTH * world::MAP_HEIGHT * MapCell.sizeof);

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
		{"pistol", "assets/weapons/pistol.png", AssetType.PNGIMAGE, {}},
	})!;
	AssetHandleList world_textures = assets.load_many({
		{"col_test", "assets/col_test.png", AssetType.PNGIMAGE, {}},
		{"brick_wall", "assets/brick_wall.png", AssetType.PNGIMAGE, {}},
	})!;
	AssetHandleList sprite_textures = assets.load_many({
		{"barrel", "assets/sprites/barrel.png", AssetType.PNGIMAGE, {}},
		{"boy", "assets/sprites/boy.png", AssetType.PNGIMAGE, {}},
		{"ball", "assets/sprites/bouncing_ball.png", AssetType.PNGIMAGE, {}},
		{
			"guy", "assets/sprites/direction_tester.png", 
			AssetType.SPRITESHEET, 
			assets::spritesheet(8*16, 16, {16,16})!! 
		},
	})!!;

	Image render_img = raylib::gen_image_colour(RENDER_WINDOW_WIDTH, RENDER_WINDOW_HEIGHT, WHITE);
	Texture tex = raylib::load_texture_from_image(render_img);

	defer raylib::unload_texture(tex);

	defer raylib::unload_image(render_img);

	double* z_buffer = (double*)calloc(RENDER_WINDOW_WIDTH * double.sizeof);
	defer free(z_buffer);

	Colour* pixels = (char[<4>]*)calloc(RENDER_WINDOW_HEIGHT * RENDER_WINDOW_WIDTH * 4);
	defer free(pixels);

	defer assets.free();

	if (assets.assert_loaded() == false) {
		return; // TODO: Error handling
	}



	for (int i = 0; i < world::MAP_HEIGHT; ++i) {
		for (int j = 0; j < world::MAP_WIDTH; ++j) {
			if (i == 0 && j != 0 || i == j) {
				world.map.grid[(i * world::MAP_WIDTH + j)] = 1;
			}
		}
	}

	world.map.grid[5 * world::MAP_WIDTH + 1] = 1;
	Player player = Player {
		.pos = {3.0, 6.0f},
		.body = entity::new_body(
			player::PLAYER_SIDE_LENGTH, player::PLAYER_SIDE_LENGTH,
			dir: math::PI, // has to be PI because if it was 0
						   // cam plane would be {0.0, -0.78}, which is ugly
		),
		.camera_plane = {0.0, 0.78}, // sort of a measure of how far on either side the FOV 
									 // extends to, initially perpendicular
		.gun = NONE,
		.weapons_unlocked = 0,
		.moving = false,
	};
	world.player = &player;
	WeaponDesc player_prev_gun = WeaponDesc.NONE;
	Texture player_gun_tex;

	ModelList to_render;

	world.entities.push(
		entity::new_dummy(
			EntityType.INDESTRUCTIBLE_DECORATION,
			{2, 3},
			sprite::new_sprite(0, 0, {1.0, 1.0})
		)
	);

	world.entities.push( entity::new_thinker
	  ( EntityType.INDESTRUCTIBLE_DECORATION,{4,10}, sprite::new_spritesheet
	  (3, &((AssetDescriptor*)assets.get_name_desc
	  ("guy")!!).spritesheet_info, is_relative: true)!,
	  think_fn: &Entity.be_spinner, body: entity::new_body(1.25, 1.25),
	  timer: timer::new_secs(1.25), ) 
	);

	TestMonster* tm = calloc(TestMonster.sizeof);
	tm.init(TMState.IDLE);
	io::printfn("%s", tm.state.machine);

	world.entities.push(
		entity::new_monster(
			{8,10},
			sprite::new_spritesheet(3, &((AssetDescriptor*)assets.get_name_desc("guy")!!).spritesheet_info, is_relative: true)!,
			any_make(tm, TestMonster.typeid),
			body: entity::new_body(1.25, 1.25),
		)
	);

	world.entities.push(
		entity::new_thinker(
			EntityType.PICKUP,
			{5, 7},
			sprite::new_sprite(1, 0, {0.5, 1.0}),
			&thinkers::be_pickup,
			entity::new_body(0.5, 0.5, false),
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

		to_render.clear();
		foreach (&entity : world.entities) {
			// TODO: make this line of sight lmao? it's not fucking impossible, you can do 
			// ANYTHING (maybe not anything)
			if (!entity.dead) {
				to_render.push(entity.get_model());
			}
		}

		raylib::begin_drawing();

		raylib::clear_background(BACKGROUND_COL);

		for (int i = 0; i < RENDER_WINDOW_HEIGHT * RENDER_WINDOW_WIDTH; i ++) pixels[i] = BACKGROUND_COL;
		
		// ---------------------------------------------------------------------
		// RAYCAST AND BLIT TEXTURE
		// ---------------------------------------------------------------------

		if (draw_floor_and_ceiling) (void)rendering::raycast_floors(&player, world.map.grid, &assets, &world_textures, pixels);

		for (int i = 0; i < RENDER_WINDOW_WIDTH; i ++) z_buffer[i] = math::DOUBLE_MAX;
		(void)rendering::raycast_walls(&player, world.map.grid, &assets, &world_textures, pixels, z_buffer);

		(void)rendering::render_sprites(&player, &to_render, &assets, &sprite_textures, pixels, z_buffer);

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
					if (world.map.grid[y * world::MAP_WIDTH + x] > 0) {
						raylib::draw_rectangle(x * (int)MINIMAP_SCALE_FACTOR, y * (int)MINIMAP_SCALE_FACTOR, (int)MINIMAP_SCALE_FACTOR, (int)MINIMAP_SCALE_FACTOR, {200, 200, 200, 100});
					}
				}
			}
		}

		Rect random = {5.5, 8, 1, 1};
		if (draw_minimap) {
			Vec2 pos = (player.pos * MINIMAP_SCALE_FACTOR);
			raylib::draw_rectangle(
				(int)((pos.x - (player::PLAYER_SIDE_LENGTH*MINIMAP_SCALE_FACTOR)/2)), 
				(int)((pos.y - (player::PLAYER_SIDE_LENGTH*MINIMAP_SCALE_FACTOR)/2)), 
				(int)(player::PLAYER_SIDE_LENGTH * MINIMAP_SCALE_FACTOR), 
				(int)(player::PLAYER_SIDE_LENGTH * MINIMAP_SCALE_FACTOR), 
				{255, 255, 0, 255}
			);
			// raylib::draw_line_ex(player.pos, (player.pos + player.dir.angle_to_cart() * 100.0), 5.0, {255, 0, 0, 255});


			Vec2 fov_left = player.pos + player.body.dir.angle_to_cart() - player.body.camera_plane;
			Vec2 fov_right = player.pos + player.body.dir.angle_to_cart() + player.body.camera_plane;

			fov_left *= MINIMAP_SCALE_FACTOR;
			fov_right *= MINIMAP_SCALE_FACTOR;

			int[<2>] i_fov_left = (int[<2>])fov_left;
			int[<2>] i_fov_right = (int[<2>])fov_right;

			raylib::draw_line((int)pos.x, (int)pos.y, i_fov_left.x, i_fov_left.y, {255, 0, 0, 255});
			raylib::draw_line((int)pos.x, (int)pos.y, i_fov_right.x, i_fov_right.y, {255, 0, 0, 255});

			foreach (ent: world.entities) {
				pos = ent.pos * MINIMAP_SCALE_FACTOR;
				raylib::draw_rectangle(
					(int)((pos.x - (player::PLAYER_SIDE_LENGTH*MINIMAP_SCALE_FACTOR)/2)), 
					(int)((pos.y - (player::PLAYER_SIDE_LENGTH*MINIMAP_SCALE_FACTOR)/2)), 
					(int)(player::PLAYER_SIDE_LENGTH * MINIMAP_SCALE_FACTOR), 
					(int)(player::PLAYER_SIDE_LENGTH * MINIMAP_SCALE_FACTOR), 
					{255, 255, 0, 255}
				);

				fov_left = ent.pos + ent.body.dir.angle_to_cart() - ent.body.camera_plane;
				fov_right = ent.pos + ent.body.dir.angle_to_cart() + ent.body.camera_plane;
				Vec2 r_fov_left = ent.body.dir.angle_to_cart() - ent.body.camera_plane;
				Vec2 r_fov_right = ent.body.dir.angle_to_cart() + ent.body.camera_plane;

				for (int i = 0; i < monster::DEFAULT_ENEMY_VIEWCHK_RAYCOUNT; i++) {
					Vec2 ray_dir = r_fov_left.lerp(r_fov_right, ((double)i/(double)monster::DEFAULT_ENEMY_VIEWCHK_RAYCOUNT));

					Colour col = {255, 0, 0, 255};

					if ( try hit = world.hits_player(ent.pos, ray_dir) ) {
						col = {0, 255, 0, 255};
					}
					ray_dir += ent.pos;
					ray_dir *= MINIMAP_SCALE_FACTOR;

					int[<2>] iraydir= (int[<2>])ray_dir;

					raylib::draw_line((int)pos.x, (int)pos.y, iraydir.x, iraydir.y, col);				
				}

				fov_left *= MINIMAP_SCALE_FACTOR;
				fov_right *= MINIMAP_SCALE_FACTOR;

				i_fov_left = (int[<2>])fov_left;
				i_fov_right = (int[<2>])fov_right;

				raylib::draw_line((int)pos.x, (int)pos.y, i_fov_left.x, i_fov_left.y, {255, 0, 0, 255});
				raylib::draw_line((int)pos.x, (int)pos.y, i_fov_right.x, i_fov_right.y, {255, 0, 0, 255});
			}
		}

		// ---------------------------------------------------------------------
		// DRAW PLAYER GUN
		// ---------------------------------------------------------------------

		if (player.gun != WeaponDesc.NONE) {
			player::display_held(&player, &assets, &player_gun_tex, player_prev_gun);
		}
		player_prev_gun = player.gun;

		raylib::end_drawing();

		float dt = raylib::get_frame_time();

		// ---------------------------------------------------------------------
		// PROCESS PLAYER CONTROLS
		// ---------------------------------------------------------------------

		if (raylib::is_key_pressed(raylib::KEY_RIGHT_ALT)) {
			draw_floor_and_ceiling = !draw_floor_and_ceiling;
			draw_minimap = !draw_minimap;
		}

		for (int i = raylib::KEY_ONE; i <= raylib::KEY_NINE; i++) {
			if (raylib::is_key_pressed(i)) {
				short slot = (short)(i - raylib::KEY_ONE);
				io::printfn("%d", slot);
				player.select_weapon_slot(slot);
			}
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
		
		player.body.vel += acc * dt;

		player.pos = entity::process_body_collisions(world.map.grid, world.entities, player.pos, player.body, null);

		player.dir_vel += turn_acc * (double)dt;
		
		player.body.update(dt);

		entity::update_entities(&world, &world.entities);

		

		foreach (&ent : world.entities) {
			if (!ent.dead && ent.can_collide()) {
				ent.pos = entity::process_body_collisions(world.map.grid, world.entities, ent.pos, ent.body, ent);

				ent.body.update(dt);	
			}
		}

//		world::update_world_occupied_cells(&world, world.entities, &player);
		
	} // GAMELOOP
}

fn double double.rem(self, double b) {
	return self - (b * (int)(self/b));
}
