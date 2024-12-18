import player;
import entity;
import raylib;
import sprite;
import std::math;

enum ThinkResult {
	OK,
	KILLME,
	NOT_ME_ERROR,
	FINISHED,
}

// DEBUG \\
import std::io;

fn ThinkResult default_think(Entity* self, Player* player) {
	// Do nothing
	return ThinkResult.OK;
}

fn ThinkResult default_monster(Entity* self, Player* player) {
	if (!self.is_type(EntityType.SMART_FELLA)) return ThinkResult.NOT_ME_ERROR;

	self.state.update(player);

	io::printfn("TODO: process monsters");

	return ThinkResult.OK;
}

fn ThinkResult Entity.be_ticking_timer(Entity* self) {
	self.timer.tick_secs(raylib::get_frame_time());
	if (self.timer.finished()) {
		return ThinkResult.FINISHED;
	}
	else {
		return ThinkResult.OK;
	}
}

fn ThinkResult Entity.be_spinner(Entity* self, Player* _p) {
	ThinkResult res = self.be_ticking_timer();

	if (res == ThinkResult.FINISHED) {
		// TODO: make it so that spritesheets with multiple collumns 
		// can be set to diff collumns with the rows representing the 
		// facing and rows representing frame of animation.
		self.body.dir_vel = 8.0;
		self.timer.reset();
	}
	return ThinkResult.OK;
}

fn ThinkResult Entity.be_animated(Entity* self, Player* _p) {
	if (self.model.type != ModelType.SPRITE_SHEET) return ThinkResult.NOT_ME_ERROR;

	ThinkResult res = self.be_ticking_timer();

	if (res == ThinkResult.FINISHED) {
		// TODO: make it so that spritesheets with multiple collumns 
		// can be set to diff collumns with the rows representing the 
		// facing and rows representing frame of animation.
		self.model.sprite_sheet.increment();
		self.timer.reset();
	}

	return ThinkResult.OK;

}

fn ThinkResult default_projectile(Entity* self, Player* _p) {
	if (!self.is_type(EntityType.PROJECTILE)) return ThinkResult.NOT_ME_ERROR;

	// TODO: die if hitting wall

	return slowly_die(self, _p);
}

fn ThinkResult slowly_die(Entity* self, Player* _p) {
	self.be_ticking_timer();

	if (self.timer.finished()) {
		self.dead = true;
		return ThinkResult.KILLME;
		// TODO: sort out what the return value means (i.e. whether to remove this ent from the list?)
	}
	return ThinkResult.OK;
}

fn ThinkResult be_pickup(Entity* self, Player* player) {
	if (!self.is_type(EntityType.PICKUP)) return ThinkResult.NOT_ME_ERROR;

	if (self.body.collides || self.body.simulated) {
		self.body.collides = false;
		self.body.simulated = false;
	}

	self.model.z = math::sin(raylib::get_time() / 20.0) * 100;
	if (self.body.centred_box(self.pos).contains_rect(player.centred_hitbox())) {
		self.dead = true;
		player.unlock_weapon(WeaponDesc.PISTOL);
		player.unlock_weapon(WeaponDesc.GLUE_GUN);
		io::printfn("TODO: implement picking up items.");
		return ThinkResult.KILLME;
	}
	return ThinkResult.OK;
}

fn ThinkResult be_follower(Entity* self, Player* player) {
	if (!self.is_type(EntityType.FOLLOWER)) return ThinkResult.NOT_ME_ERROR;

	Vec2 to_player = player.pos - self.pos;
	self.body.vel += to_player * raylib::get_frame_time() * 10;
	return ThinkResult.OK;
}