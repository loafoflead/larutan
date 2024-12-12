import player;
import entity;
import raylib;
import std::math;

enum ThinkResult {
	NONE,
	KILLME,
	NOT_ME_ERROR,
}

// DEBUG //
import std::io;

fn ThinkResult default_think(Entity* self, Player* player) {
	// Do nothing
	return ThinkResult.NONE;
}

fn ThinkResult slowly_die(Entity* self, Player* _p) {
	if (!self.is_type(EntityType.DECAL)) return ThinkResult.NOT_ME_ERROR;

	self.timer.tick_secs(raylib::get_frame_time()); 
	if (self.timer.finished()) {
		self.dead = true;
		return ThinkResult.KILLME;
		// TODO: sort out what the return value means (i.e. whether to remove this ent from the list?)
	}
	return ThinkResult.NONE;
}

fn ThinkResult be_pickup(Entity* self, Player* player) {
	if (!self.is_type(EntityType.PICKUP)) return ThinkResult.NOT_ME_ERROR;

	if (self.body.collides || self.body.simulated) {
		self.body.collides = false;
		self.body.simulated = false;
	}

	self.sprite.z = math::sin(raylib::get_time() / 20.0) * 100;
	if (self.body.centred_box(self.pos).contains_rect(player.centred_hitbox())) {
		self.dead = true;
		player.gun = PISTOL;
		io::printfn("TODO: implement picking up items.");
		return ThinkResult.KILLME;
	}
	return ThinkResult.NONE;
}

fn ThinkResult be_follower(Entity* self, Player* player) {
	if (!self.is_type(EntityType.FOLLOWER)) return ThinkResult.NOT_ME_ERROR;

	Vec2 to_player = player.pos - self.pos;
	self.body.vel += to_player * raylib::get_frame_time() * 10;
	return ThinkResult.NONE;
}