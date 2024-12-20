import test_monster;
import std::math::vector;
import state_machine;
import thinkers;
import entity;
import player;

struct PositionGoal {
	Vec2 pos;
	float progress;
}

interface Monster {
	fn ThinkResult think(Entity* ent, Player* pl);
}