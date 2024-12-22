import std::math::vector;
import utils;
import assets;
import bindings;
import entity;
import world;
import main;
import rendering;

import std::io;

const float PLAYER_ACCELERATION = 50.0; // Grid squares per second
const float PLAYER_VEL_DAMPING = 0.9;

const float MINIMUM_MOVEMENT_THRESHOLD = 0.01; // sq metres per second (squared?)

const float PLAYER_TURN_ACCELERATION = math::PI*20; // RADIANS per second per second
const float PLAYER_TURN_DAMPING = 0.8; // RADIANS per second
const float PLAYER_SIDE_LENGTH = 0.2f;

const double PROJECTILE_SPAWN_DIST = 2.0;

enum AmmoType {
	LIGHT_BULLET,
	POLYMER,
}

struct WeaponStats {
	usz max_ammo;
	AmmoType ammo_type;
	usz clip_ammo; // 0 means no clip
	usz primary_atk_delay_ms, secondary_atk_delay_ms;
	bool can_hold_fire;
	float range;
	float dmg;
	String projectile_graphic_name;
}

enum WeaponDesc : int (String sprite_path, short byte_index, WeaponStats stats)
{
	NONE = { "missing", 0b00_00_00_00, {} },
	PISTOL = { "pistol", 0b00_00_00_01, 
		{
			32,
			AmmoType.LIGHT_BULLET,
			0,
			100, 0,
			true,
			256f,
			15f,
			"",
		} 
	},
	GLUE_GUN = { "glugun", 0b00_00_00_10,
		{
			120,
			AmmoType.POLYMER,
			0,
			250, 1000,
			false,
			3f,
			25f,
			"glueball",
		}
	},
}

fn bool WeaponDesc.has_altfire(WeaponDesc weapon) {
	switch(weapon) {
		case PISTOL:
			return false;
		case GLUE_GUN:
			return true;
		default:
			return false;
	}
}

struct Player {
	inline Body body;
	
	Vec2 pos;
	// inv
	short weapons_unlocked;
	WeaponDesc gun;
	// flags
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

fn void Player.unlock_weapon(&self, WeaponDesc weapon) {
	self.weapons_unlocked |= weapon.byte_index;
	// automatically hand a gun when picked
	if (self.gun == WeaponDesc.NONE) {
		self.gun = weapon;
	}
}

fn void Player.select_weapon_slot(&self, short slot) {
	short byte = (1 << slot);
	io::printfn("%b", byte);
	if (self.weapons_unlocked & byte == 0) {
		return;
	}

	self.gun = (WeaponDesc)(slot + 1);
}

// FIXME: weird hardcoded values extravaganza!
fn void display_held(Player* player, Assets* assets, Texture* tex, WeaponDesc prev) {
	if (player.gun != prev) {
		raylib::unload_texture(*tex);
		Image* img = (Image*)(assets.get_name(player.gun.sprite_path) ?? assets.get_default(AssetType.PNGIMAGE)!!).data;
		*tex = raylib::load_texture_from_image(*img);
	}
	if (tex == null) return;

	int gun_x = 0;//WINDOW_WIDTH / 2 + tex.width;
	int gun_y = player.moving ? (int)(math::sin((float)(raylib::get_time() % 360)*10) * player.body.vel.length()) : 0;

	switch (player.gun) {
		case WeaponDesc.PISTOL:
		// TODO: make higher level rendering functions for spritesheets etc..
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
		case WeaponDesc.GLUE_GUN:
			raylib::draw_texture_with_params(
				*tex, 
				NPatchInfo {
					.source = { 0, 0, tex.width, tex.height },
				},
				{0, (float)(gun_y + tex.height / 6), main::WINDOW_WIDTH, main::WINDOW_HEIGHT},
				{gun_x, gun_y},
				0.0,
				{255, 255, 255, 50}
			);
		break;
		default:
		break;
	}
}

// Fire is alt or main
fn void attack(World* world, Assets* assets, EntityList* ents, Player* player, bool altfired) {
	// if altfiring a gun w/ no altfire, don't shoot (don't shoot!!)
	if ((altfired && !player.gun.has_altfire()) || player.gun == WeaponDesc.NONE) return; 

	Vec2 player_facing = player.dir.angle_to_cart(); 
	// TODO: prevent spam

	if (!altfired) {

	switch(player.gun) {

		case WeaponDesc.PISTOL:
			RaycastHit hit = world.cast_ray(player.pos, player_facing, exclude_player: true);
			if (hit.hit) {
				double z = 0.5;
				
				world.entities.push(
					entity::new_decal(player.pos + player_facing * hit.dist, z, 9999, 5.0)
				);

				io::printfn("Raycast hits: %s", hit);
			}
			else {
				io::printn("Raycast MISSES");
			}
		break;

		case WeaponDesc.GLUE_GUN:
			ProjectileState* state = calloc(ProjectileState.sizeof);
			state.dmg = 25;
			world.entities.push(
				entity::new_projectile(
					player.pos + player_facing * PROJECTILE_SPAWN_DIST,
					player_facing * PROJECTILE_SPAWN_DIST,
					sprite::new_sprite(assets.index_of_name(player.gun.stats.projectile_graphic_name) ?? assets.index_of_default(AssetType.PNGIMAGE)!!),
					entity::new_body(0.25, 0.25),
					state,
				)
			);
		break;

		default:
			io::printfn("ERROR: attempt to fire weapon that has not yet been implemented. (Sprite: %s)", player.gun.sprite_path);
		break;
	}

	}
}
