module monster(<StateType>);

import test_monster;
import std::math::vector;
import state_machine;

def MonsterStateMachine = StateMachine(<StateType>);

struct PositionGoal {
	Vec2 pos;
	float progress;
}

struct Monster {
	MonsterStateMachine state;
	PositionGoal pos_goal;
}

fn ThinkResult Monster.update(&self, Player* p) {
	
}