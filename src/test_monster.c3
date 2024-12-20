import entity;
import world;
import monster;
import monster_generic;
import thinkers;
import player;
import state_machine;

import std::io;

def TestMonsterState = MonsterState(<TMState>);

enum TMState: usz {
	IDLE,
	FOLLOWING,
	CHARGING,
}

struct TestMonster (Monster) {
	TestMonsterState state;
}

fn void TestMonster.init(&self, TMState initial_state) {
	self.state = TestMonsterState {
		.machine = state_machine::new_machine(<TMState>)(initial_state),
		.pos_goal = {},
	};
}

fn ThinkResult TestMonster.think(&self, Entity* ent, Player* pl) @dynamic {
	TMState s = self.state.machine.get();
	switch (s) {
		case IDLE:
			// do nothing
		break;
		default:
			io::printfn("TestMonster: Unimplemented state %s", TMState.names[s]);
	}

	return ThinkResult.OK;
}