import std::math;
import main;
import math;
import world;
import player;
import assets;
import sprite;
import raylib;
import entity;
import std::sort;

import std::io;

const uint MAX_DDA_DEPTH = 50;
const double MAX_DDA_DIST = 45.0;
const double FADEOUT_DIST = 30.0;
const bool FADEOUT = true;

struct RaycastHit (Printable) {
	double dist;
	int side;
	int[<2>] map_pos;
	bool hit;
	bool hit_player;
	union {
		Entity* entity;
		Player* player;
	}
}

fn usz! RaycastHit.to_format(&self, Formatter* formatter) @dynamic
{
	return formatter.printf(
		"RaycastHit { dist: %f, side: %d, map pos: (%d,%d), hit: %s, %s: %p }", 
		self.dist,
		self.side,
		self.map_pos.x, 
		self.map_pos.y,
		self.hit,
		self.hit_player ? "player" : "entity",
		self.hit_player ? (void*)self.player : (void*)self.entity,		 
	);
}

fn String RaycastHit.to_new_string(&self, Allocator allocator = allocator::heap()) @dynamic
{
	return string::format("%s", *self, allocator: allocator);
}

fn RaycastHit cast_ray(MapCell* map, Vec2 og, Vec2 dir) {
	int map_x = (int)math::floor(og.x);
	int map_y = (int)math::floor(og.y);

	double side_dist_x = 0;
	double side_dist_y = 0;

	double d_dist_x = ((dir.x == 0) ? math::DOUBLE_MAX : math::abs( 1.0 / dir.x ));
	double d_dist_y = ((dir.y == 0) ? math::DOUBLE_MAX : math::abs( 1.0 / dir.y ));

	int step_x = 0;
	int step_y = 0;

	bool hit = false;
	int side = 0;

	// calculate step 

	if (dir.x < 0) {
		step_x = -1;
		side_dist_x = (og.x - (double)(map_x)) * d_dist_x;
	} 
	else {
		step_x = 1;
		side_dist_x = ((double)(map_x) + 1.0 - og.x) * d_dist_x;
	}

	if (dir.y < 0) {
		step_y = -1;
		side_dist_y = (og.y - (double)(map_y)) * d_dist_y;
	}
	else {
		step_y = 1;
		side_dist_y = ((double)(map_y) + 1.0 - og.y) * d_dist_y;
	}

	uint depth = 0;
	double dist = 0;
	// do DDA algorithm
	while (hit == false) {
		if (side_dist_x < side_dist_y) {
			dist = side_dist_x;
			side_dist_x += d_dist_x;
			map_x += step_x;
			side = 0;
		}
		else {
			dist = side_dist_y;
			side_dist_y += d_dist_y;
			map_y += step_y;
			side = 1;
		}

		depth ++;

		if (depth > MAX_DDA_DEPTH) {
			break;
		}
		else if (dist > MAX_DDA_DIST) {
			break;
		}

		if ((map_y * world::MAP_WIDTH + map_x) >= world::MAP_WIDTH*world::MAP_HEIGHT) continue;
		if ((map_y * world::MAP_WIDTH + map_x) < 0) continue;
		
		if (map[map_y * world::MAP_WIDTH + map_x] > 0) {
			hit = true;
		}

		if (map_x >= world::MAP_WIDTH || map_x < 0 || map_y < 0 || map_y >= world::MAP_HEIGHT) {
			hit = false;
			continue;
		}	
	}

	// FIXME: busted ass logic lmao
	if (!hit) {
		return RaycastHit { 0, 0, {0, 0}, false, false, null };
	}
	
	if (map_x >= world::MAP_WIDTH || map_x < 0 || map_y < 0 || map_y >= world::MAP_HEIGHT) {
		return RaycastHit { math::DOUBLE_MAX, 0, {0, 0}, false, false, null };
	}
	
	return RaycastHit { 
		.dist = dist, 
		.side = side, 
		.map_pos = {map_x, map_y}, 
		.hit = true,
		.hit_player = false,
		.entity = null,
	};
}

fn void! raycast_walls(Player* player, MapCell* map, Assets* assets, AssetHandleList* world_textures, Colour* pixels, double* z_buffer) {
	int num_rays = main::RENDER_WINDOW_WIDTH;
	Vec2 fov_left = player.dir.angle_to_cart() - player.camera_plane;
	Vec2 fov_right = player.dir.angle_to_cart() + player.camera_plane;

	for (int i = 0; i < num_rays; i ++) {
		Vec2 ray_dir = fov_left.lerp(fov_right, ((double)i/(double)main::RENDER_WINDOW_WIDTH));

		Vec2 player_map_pos = player.pos;
		
		RaycastHit hit = //RaycastHit { 0, 0, {0, 0}, {0, 0}, false };
			cast_ray(map, player.pos, ray_dir);

		if (!hit.hit) {
			continue;
		}

		double perp_wall_dist = hit.dist;
		int side = hit.side;

		int line_height = 0;
		if (perp_wall_dist == 0) {
			line_height = main::RENDER_WINDOW_HEIGHT;
		}
		else {
			line_height = (int)(main::RENDER_WINDOW_HEIGHT / perp_wall_dist);
		}

		int draw_start = -line_height / 2 + main::RENDER_WINDOW_HEIGHT / 2;
		if (draw_start < 0) {
			draw_start = 0;
		}

		int draw_end = line_height / 2 + main::RENDER_WINDOW_HEIGHT / 2;
		if (draw_end >= main::RENDER_WINDOW_HEIGHT) {
			draw_end = main::RENDER_WINDOW_HEIGHT - 1;
		}

		int map_index = hit.map_pos.y * world::MAP_WIDTH + hit.map_pos.x;

		if (map[map_index] != 0) z_buffer[i] = perp_wall_dist;
		int texture_index = map[map_index];
		if (texture_index <= world_textures.len()) {
			texture_index--;

			Asset* ass = assets.get(&(*world_textures)[texture_index]) ?? assets.get_default(AssetType.PNGIMAGE)!;
			Image* texture = (Image*)ass.data;
			double wall_x = 0.0;

			if (side == 0) {
				wall_x = player_map_pos.y + perp_wall_dist * ray_dir.y;
			}
			else {
				wall_x = player_map_pos.x + perp_wall_dist * ray_dir.x;
			}
			wall_x -= math::floor(wall_x);

			int tex_x = (int)(wall_x * (double)texture.width);
			if ((side == 0 && ray_dir.x > 0) || (side == 1 && ray_dir.y < 0)) {
				tex_x = texture.width - tex_x - 1;
			}

			double step = 1.0 * texture.height / line_height;
			double tex_pos = (double)(draw_start - main::RENDER_WINDOW_HEIGHT / 2 + line_height / 2) * step;
			for (int y = draw_start; y < draw_end; y ++) {
				int tex_y = (int)tex_pos & (texture.height - 1);
				tex_pos += step;
				int idx = (texture.width * tex_y + tex_x);
				if (idx >= texture.width*texture.height || idx < 0) {
					continue;
				}
				Colour col = texture.data[idx];
				if (FADEOUT) {
					float[<4>] col_lerp = (float[<4>])col / 255.0;
					col_lerp = col_lerp.lerp(float[<4>] {1.0, 1.0, 1.0, 1.0}, (float)(perp_wall_dist / FADEOUT_DIST));
					col_lerp *= 255.0;
					pixels[y * main::RENDER_WINDOW_WIDTH + i] = (Colour)col_lerp;
				}
				else {
					pixels[y * main::RENDER_WINDOW_WIDTH + i] = col;
				}
			}
		}
		else {
			Colour col;
			switch(map[map_index]) {
				case 0:
					col = {0, 0, 0, 255};
				break;
				case 2: 
					col = {255, 100, 100, 255}; 
				break;
				default:
					col = {255, 0, 255, 255};
				break;
			}

			if (side == 1) {
				col = col;
			}

			for (int y = draw_start; y < draw_end; ++y) {
				pixels[(y * main::RENDER_WINDOW_WIDTH + i)] = col;
			}
		}	
	}
}

fn void! raycast_floors(Player* player, MapCell* map, Assets* assets, AssetHandleList* world_textures, Colour* pixels) {
	Vec2 fov_left = player.dir.angle_to_cart() - player.camera_plane;
	Vec2 fov_right = player.dir.angle_to_cart() + player.camera_plane;
	
	Vec2 player_map_pos = player.pos;

	for (int y = 0; y < main::RENDER_WINDOW_HEIGHT; y++) {

		int p = y - (main::RENDER_WINDOW_HEIGHT / 2); // y compared to horizon (h / 2)
		
		if (p == 0) {
			p = main::RENDER_WINDOW_HEIGHT/2;
		}

		// vertical position of the camera in "3D" space
		float pos_z = 0.5 * main::RENDER_WINDOW_HEIGHT; 

		// horizontal distance from camera to the floor for this row
		float row_distance = pos_z / p;

		Vec2 floor_step = row_distance * (fov_right - fov_left) / main::RENDER_WINDOW_WIDTH;

		// world coords of the leftmost collumn
		Vec2 floor_pos = (player_map_pos + row_distance * fov_left);
		double dist = floor_pos.distance(player.pos);

		for (int x = 0; x < main::RENDER_WINDOW_WIDTH; x ++) {
			int[<2>] cell = (int[<2>])math::floor(floor_pos);

			int floor_tex_idx = 1;
			int ceiling_tex_idx = 1;

			if (cell.x % 2 == 0 && cell.y % 2 == 0) {
				floor_tex_idx = 0;	
				ceiling_tex_idx = 0;
			}

			Asset* floor_ass = assets.get(&(*world_textures)[floor_tex_idx])!;
			Image* floor_texture = (Image*)floor_ass.data;
			Asset* ceiling_ass = assets.get(&(*world_textures)[ceiling_tex_idx])!;
			Image* ceiling_texture = (Image*)ceiling_ass.data;

			int[<2>] tex_pos = {
				(int)(floor_texture.width * (floor_pos.x - cell.x)) & (floor_texture.width - 1),
				(int)(floor_texture.height * (floor_pos.y - cell.y)) & (floor_texture.height - 1),
			};

			floor_pos += floor_step;

			Colour col;

			col = floor_texture.data[floor_texture.width * tex_pos.y + tex_pos.x];
			float[<4>] col_lerp;
			if (FADEOUT) {
				col_lerp = (float[<4>])col / 255.0;
				col_lerp = col_lerp.lerp(float[<4>] {1.0, 1.0, 1.0, 1.0}, (float)(dist / FADEOUT_DIST));
				col_lerp *= 255.0;
				if (math::abs(y - main::RENDER_WINDOW_HEIGHT / 2) < 3) col_lerp = main::WHITE;			
				//col = (Colour)(((int)col >> 1) & 8355711); // darken colour through magic
				pixels[y * main::RENDER_WINDOW_WIDTH + x] = (Colour)col_lerp;
			}
			else {
				if (math::abs(y - main::RENDER_WINDOW_HEIGHT / 2) < 3) col = main::WHITE;			
				//col = (Colour)(((int)col >> 1) & 8355711); // darken colour through magic
				pixels[y * main::RENDER_WINDOW_WIDTH + x] = col;
			}
			//pixels[y][x] = col;

			tex_pos = {
				(int)(ceiling_texture.width * (floor_pos.x - cell.x)) & (ceiling_texture.width - 1),
				(int)(ceiling_texture.height * (floor_pos.y - cell.y)) & (ceiling_texture.height - 1),
			};
			
			col = ceiling_texture.data[ceiling_texture.width * tex_pos.y + tex_pos.x];
			if (FADEOUT) {
				col_lerp = (float[<4>])col / 255.0;
				col_lerp = col_lerp.lerp(float[<4>] {1.0, 1.0, 1.0, 1.0}, (float)(dist / FADEOUT_DIST));
				col_lerp *= 255.0;
				if (math::abs(y - main::RENDER_WINDOW_HEIGHT / 2) < 2) col_lerp = main::WHITE;
				//col = (Colour)(((int)col >> 1) & 8355711); // darken colour through magic
				pixels[(main::RENDER_WINDOW_HEIGHT - y - 1) * main::RENDER_WINDOW_WIDTH + x] = (Colour)col_lerp;
			}
			else {
				if (math::abs(y - main::RENDER_WINDOW_HEIGHT / 2) < 2) col = main::WHITE;
				//col = (Colour)(((int)col >> 1) & 8355711); // darken colour through magic
				pixels[(main::RENDER_WINDOW_HEIGHT - y - 1) * main::RENDER_WINDOW_WIDTH + x] = col;
			}
		}
	}
}

fn void! render_sprites(Player* player, ModelList* models, Assets* assets, AssetHandleList* sprite_textures, Colour* pixels, double* z_buffer) {
	for (int i = 0; i < models.len(); i++) {
		models.get(i).player_dist = player.pos.distance(models.get(i).pos);
	}

	sort::quicksort(*models, fn int(EntityModel* a, EntityModel* b) => (int)((b.player_dist - a.player_dist) * 1000.0));

	foreach (model : models) {
		Vec2 rel_pos = model.pos - player.pos;
	
		// did this in maths expertes, inverse of a matrix to find A or whatever
		Vec2 player_dir = player.dir.angle_to_cart();
		double inverse_determinant = 1.0 / (player.camera_plane.x * player_dir.y - player_dir.x * player.camera_plane.y);

		Vec2 transform;
		transform.x = inverse_determinant * (player_dir.y * rel_pos.x - player_dir.x * rel_pos.y);
		transform.y = inverse_determinant * (-player.camera_plane.y * rel_pos.x + player.camera_plane.x * rel_pos.y);

		int z_move = (int) (model.z / transform.y);

		if (transform.y == 0) continue;
		int sprite_screen_x = (int)( (main::RENDER_WINDOW_WIDTH / 2) * ( 1 + transform.x / transform.y ) );

		int sprite_height = math::abs((int)((double)main::RENDER_WINDOW_HEIGHT / transform.y));
		if (model.uv_scale_division.y != 0) {
			sprite_height = (int)( (double)sprite_height / model.uv_scale_division.y);
		}

		int draw_start_y = -sprite_height / 2 + main::RENDER_WINDOW_HEIGHT / 2 + z_move;
		if (draw_start_y < 0) {
			draw_start_y = 0;
		}

		int draw_end_y = sprite_height / 2 + main::RENDER_WINDOW_HEIGHT / 2 + z_move;
		if (draw_end_y >= 0) {
			draw_end_y = main::RENDER_WINDOW_HEIGHT-1;
		}
		
		int sprite_width = math::abs( (int)(main::RENDER_WINDOW_HEIGHT / transform.y) );
		if (model.uv_scale_division.x != 0) {
			sprite_width = (int)( (double)sprite_width / model.uv_scale_division.x);
		}

		int draw_start_x = -sprite_width / 2 + sprite_screen_x;
		if (draw_start_x < 0) {
			draw_start_x = 0;
		}

		int draw_end_x = sprite_width / 2 + sprite_screen_x;
		if (draw_end_x >= main::RENDER_WINDOW_WIDTH) {
			draw_end_x = main::RENDER_WINDOW_WIDTH - 1;
		}

		model.set_spritesheet_portion(player.pos);
		Asset* ass;
		if (model.texture_index >= sprite_textures.len()) {
			ass = assets.get_default(AssetType.PNGIMAGE)!;
		}
		else {
			ass = assets.get(sprite_textures.get_ref(model.texture_index)) ?? assets.get_default(AssetType.PNGIMAGE)!;
		}
		Image* full = (Image*)ass.data;
		usz[<4>] portion = model.image_portion()!;
		if (portion == {0,0,0,0}) {
			portion = {0, 0, full.width, full.height};
		}
		Image tex = raylib::image_from_image(*full, math::rect_from_usz(portion));

		for (int stripe = draw_start_x; stripe < draw_end_x; stripe++) {
			int tex_x = (int) (256 * (stripe - (-sprite_width / 2 + sprite_screen_x)) * tex.width / sprite_width) / 256;

			if (transform.y > 0 && stripe > 0 && stripe < main::RENDER_WINDOW_WIDTH && transform.y < z_buffer[stripe])
			{
				for (int y = draw_start_y; y < draw_end_y; y++) {
					int d = (y-z_move) * 256 - main::RENDER_WINDOW_HEIGHT * 128 + sprite_height * 128;
					int tex_y = ((d * tex.height) / sprite_height) / 256;
					if (tex_y * tex.width + tex_x >= tex.width * tex.height) continue;
					Colour col = tex.data[tex_y * tex.width + tex_x];
					if (FADEOUT) {
						float[<4>] col_lerp = (float[<4>])col / 255.0;
						col_lerp = col_lerp.lerp(float[<4>] {1.0, 1.0, 1.0, 1.0}, (float)(model.player_dist / FADEOUT_DIST));
						col_lerp *= 255.0;
						if (col.a != 0) pixels[y * main::RENDER_WINDOW_WIDTH + stripe] = (Colour)col_lerp;						
					}
					else {
						if (col.a != 0) pixels[y * main::RENDER_WINDOW_WIDTH + stripe] = col;						
					}
				}
			}
		}
	}
}