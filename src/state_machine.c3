module state_machine(<StateType>);

import timer;
import std::collections::list;
import std::collections::tuple;
import std::io;

def State = int;

struct StateQueueElement {
	float time_secs;
	StateType next_state;
}

def StateQueue = List(<StateQueueElement>);

const usz STATE_QUEUE_LENGTH = 10;

struct StateMachine (Printable) {
	StateType state;
	Timer timer;
	StateQueue queue;
}

fn usz! StateMachine.to_format(&self, Formatter* formatter) @dynamic
{
	return formatter.print("{ state: %d, timer: %s, queue: %s }", self.state, self.timer, self.queue);
}

fn String List.to_new_string(&self, Allocator allocator = allocator::heap()) @dynamic
{
	return string::format("%s", *self, allocator: allocator);
}

// Return the previous state
fn State StateMachine.set(&self, StateType newstate) {
	defer self.state = newstate; // ooo c3 is so fucking cool
	return self.state;
}

// Return the current state
fn State StateMachine.queue(&self, StateType next, float secs_until) {
	self.queue.push(
		StateQueueElement {
			.time_secs = secs_until,
			.next_state = next,
		}
	);

	return self.state;
}

fn void StateMachine.tick(&self, float dt_secs) {
	self.timer.tick_secs(dt_secs);

	if (self.timer.finished()) {
		if (self.queue.len() != 0) {
			StateType next = self.queue.pop_first();

			self.state = next.next_state;

			if (self.queue.len() != 0) 
				self.timer.reset_to_secs(self.queue[0].time_secs);
		}
	}
}

fn StateMachine new(StateType initial) {
	return StateMachine {
		.state = initial,
		.timer = timer::new_secs(1.0),
		.queue = {},
	};
}