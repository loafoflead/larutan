import std::math::vector;
import math;
import assets;
import raylib;
import entity;
import world;
import main;

import std::io;

const float PLAYER_ACCELERATION = 50.0; // Grid squares per second
const float PLAYER_VEL_DAMPING = 0.9;

const float MINIMUM_MOVEMENT_THRESHOLD = 0.01; // sq metres per second (squared?)

const float PLAYER_TURN_ACCELERATION = math::PI_2; // RADIANS per second per second
const float PLAYER_TURN_DAMPING = 0.7; // RADIANS per second
const float PLAYER_SIDE_LENGTH = 0.2f;


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


struct Player {
	Vec2 pos;
	Body body;
	Vec2 camera_plane;
	// in radians
	float dir;
	float dir_vel;
	// inv
	Weapon gun;
	// flags
	bool moving;
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


// FIXME: weird hardcoded values extravaganza!
fn void display_held(Player* player, Assets* assets, Texture* tex, Weapon prev) {
	if (player.gun != prev) {
		Image* img = &assets.weapon_textures[(usz)player.gun - 1];
		if (img == null) img = &assets.missing;
		*tex = raylib::load_texture_from_image(*img);
	}
	if (tex == null) return;

	int gun_x = 0;//WINDOW_WIDTH / 2 + tex.width;
	int gun_y = player.moving ? (int)(math::sin((float)(raylib::get_time() % 360)*10) * player.body.vel.length()) : 0;

	switch (player.gun) {
		case Weapon.PISTOL:
			raylib::draw_texture_with_params(
				*tex, 
				NPatchInfo {
					.source = { 0, 0, tex.width, tex.height },
				},
				{0, (float)(gun_y + tex.height / 6), main::WINDOW_WIDTH, main::WINDOW_HEIGHT},
				{gun_x, gun_y},
				0.0,
				main::WHITE
			);
		break;
		default:
		break;
	}
}

// Fire is alt or main
fn void attack(World* world, EntityList* ents, Player* player, bool altfired) {
	// if altfiring a gun w/ no altfire, don't shoot (don't shoot!!)
	if ((altfired && !player.gun.has_altfire()) || player.gun == Weapon.NONE) return; 

	if (!altfired) {

	switch(player.gun) {

		case Weapon.PISTOL:
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
