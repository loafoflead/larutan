module enemy::monster_generic(<StateType>);

import enemy::state_machine, enemy::monster;

def Machine = StateMachine(<StateType>);

struct MonsterState {
	Machine machine;
	PositionGoal pos_goal;
}

fn MonsterState new_state(StateType initial, PositionGoal goal = {}) {
	return MonsterState {
		.machine = state_machine::new_machine(<StateType>)(initial),
		.pos_goal = goal,
	};
}