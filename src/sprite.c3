import std::math::vector;
import std::collections::list;

def SpriteList = List(<Sprite*>);

struct Sprite {
	usz texture_index;
	Vec2 uv_scale_division;
	double z;
	// effectively private variables
	Vec2 pos;
	double player_dist;
}

fn Sprite new_sprite(usz texture_index, double z, Vec2 uv_scale_division) {
	Sprite new = Sprite {
		.texture_index = texture_index,
		.z = z,
		.uv_scale_division = uv_scale_division,
		.pos = {0, 0},
		.player_dist = 0.0,
	};
	return new;
}

struct Decal {
	usz texture_index;
	double z;
}