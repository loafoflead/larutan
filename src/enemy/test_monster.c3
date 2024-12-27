module enemy::test_monster;

import entity;
import world;
import enemy;
import player;

import std::io;

def TestMonsterState = MonsterState(<TMState>);

const float TEST_ACTIVATION_TIME = 3.5;

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
	// FIXME: crashed when player is OOB
	switch (s) {
		case IDLE:
			// if seeing the player tick timer
//			if (ent.pos.distance(w.player.pos) < 3.0) {
			if (monster::can_see_player(w, ent, ent.pos)) {
				ent.timer.tick_secs(dt);
				if (ent.timer.finished()) {
					self.state.machine.set(FOLLOWING);
				}
			}
			else {
				ent.timer.reset_to_secs(TEST_ACTIVATION_TIME);
			}
		break;
		default:
			io::printfn("TestMonster: Unimplemented state %s", TMState.names[s]);
	}

	self.state.machine.tick(dt);

	return ThinkResult.OK;
}