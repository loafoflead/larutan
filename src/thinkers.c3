import player;
import entity;
import raylib;
import std::math;


// DEBUG //
import std::io;

fn int default_think(Entity* self, Player* player) {
	// Do nothing
	return 0;
}

fn int slowly_die(Entity* self, Player* _p) {
	if (!self.is_type(EntityType.DECAL)) return -1;

	self.timer.tick_secs(raylib::get_frame_time()); 
	if (self.timer.finished()) {
		self.dead = true;
		// TODO: sort out what the return value means (i.e. whether to remove this ent from the list?)
	}
	return 0;
}

fn int be_pickup(Entity* self, Player* player) {
	if (!self.is_type(EntityType.PICKUP)) return -1;

	if (self.body.collides == true || self.body.simulated) {
		self.body.collides = false;
		self.body.simulated = false;
	}
	self.sprite.z = math::sin(raylib::get_time() / 20.0) * 100;
	if (self.body.centred_box(self.pos).contains_rect(player.centred_hitbox())) {
		self.dead = true;
		player.gun = PISTOL;
		io::printfn("TODO: implement picking up items.");
	}
	return 0;
}

fn int be_follower(Entity* self, Player* player) {
	Vec2 to_player = player.pos - self.pos;
	self.body.vel += to_player * raylib::get_frame_time() * 10;
	return 0;
}