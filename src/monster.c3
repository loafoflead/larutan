import test_monster;
import std::math::vector;
import state_machine;
import thinkers;
import entity;
import player;
import world;
import rendering;

const usz DEFAULT_ENEMY_VIEWCHK_RAYCOUNT = 15;

struct PositionGoal {
	Vec2 pos;
	float progress;
}

fn bool can_see_player(World* world, Entity* ent, Vec2 pos) {
	Vec2 fov_left = ent.body.dir.angle_to_cart() - ent.body.camera_plane;
	Vec2 fov_right = ent.body.dir.angle_to_cart() + ent.body.camera_plane;

	for (int i = 0; i < DEFAULT_ENEMY_VIEWCHK_RAYCOUNT; i++) {
		Vec2 ray_dir = fov_left.lerp(fov_right, ((double)i/(double)DEFAULT_ENEMY_VIEWCHK_RAYCOUNT));

		RaycastHit hit = world.cast_ray(pos, ray_dir, exclude: ent);
		if (hit.hit && hit.hit_player) {
			return true;
		}
	}

	return false;
}

interface Monster {
	fn ThinkResult think(Entity* ent, World* w, float dt);
}