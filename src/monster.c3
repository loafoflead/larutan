import test_monster;
import std::math::vector;
import state_machine;
import thinkers;
import entity;
import player;
import world;
import rendering;

const usz DEFAULT_ENEMY_VIEWCHK_RAYCOUNT = 15;
const float DEFAULT_ENEMY_VIEW_DIST = 50.0;


struct PositionGoal {
	Vec2 pos;
	float progress;
}

fn bool can_see_player(World* world, Entity* ent, Vec2 pos, float range = DEFAULT_ENEMY_VIEW_DIST) {
	Vec2 fov_left = ent.body.dir.angle_to_cart() - ent.body.camera_plane;
	Vec2 fov_right = ent.body.dir.angle_to_cart() + ent.body.camera_plane;

	for (int i = 0; i < DEFAULT_ENEMY_VIEWCHK_RAYCOUNT; i++) {
		Vec2 ray_dir = fov_left.lerp(fov_right, ((double)i/(double)DEFAULT_ENEMY_VIEWCHK_RAYCOUNT));

		if ( try hit = world.hits_player(pos, ray_dir, range) ) {
			return true;
		}
	}

	return false;
}

interface Monster {
	fn ThinkResult think(Entity* ent, World* w, float dt);
}