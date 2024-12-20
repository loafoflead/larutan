import entity;
import world;
import monster;
import monster_generic;
import thinkers;
import player;
import state_machine;

import std::io;

def TestMonsterState = MonsterState(<TMState>);

const float TEST_ACTIVATION_TIME = 1.5;

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

fn ThinkResult TestMonster.think(&self, Entity* ent, World* w, float dt) @dynamic {
	TMState s = self.state.machine.get();
	switch (s) {
		case IDLE:
			// if seeing the player tick timer
			//if (self.state.can_see_player(w)) {
			if (ent.pos.distance(w.player.pos) < 3.0) {
				ent.timer.tick_secs(dt);
				if (ent.timer.finished()) {
					self.state.machine.set(FOLLOWING);
				}
			}
			else {
				ent.timer.reset_to_secs(TEST_ACTIVATION_TIME);
			}
			// TODO: implement checking if player is in FOV
		break;
		default:
			io::printfn("TestMonster: Unimplemented state %s", TMState.names[s]);
	}

	self.state.machine.tick(dt);

	return ThinkResult.OK;
}