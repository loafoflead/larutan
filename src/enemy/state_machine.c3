module enemy::state_machine(<StateType>);

import utils::timer;
import std::collections::list;
import std::collections::tuple;
import std::io;

struct StateQueueElement {
	float time_secs;
	StateType next_state;
}

def StateQueue = List(<StateQueueElement>);

const usz STATE_QUEUE_LENGTH = 10;

struct StateMachine (Printable) {
	StateType state;
	StateType previous;
	Timer timer;
	StateQueue queue;
}

fn StateMachine new_machine(StateType initial) {
	return StateMachine {
		.state = initial,
		.previous = initial,
		.timer = timer::new_secs(1.0),
		.queue = StateQueue {},
	};
}

fn usz! StateMachine.to_format(&self, Formatter* formatter) @dynamic
{
	return formatter.printf("{ state: %s, timer: %s, queue: %s }", StateType.names[self.state], self.timer, self.queue);
}

fn String StateMachine.to_new_string(&self, Allocator allocator = allocator::heap()) @dynamic
{
	return string::format("%s", *self, allocator: allocator);
}

fn StateType StateMachine.get(&self) {
	return self.state;
}

fn bool StateMachine.changed(&self) {
	return self.previous != self.state;
}

// Return the previous state
fn StateType StateMachine.set(&self, StateType newstate) {
	self.previous = self.state;
	self.state = newstate; // ooo c3 is so fucking cool
	return self.previous;
}

// Return the current state
fn StateType StateMachine.queue_state(&self, StateType next, float secs_until) {
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
	self.previous = self.state;

	if (self.timer.finished()) {
		if (try StateQueueElement next = self.queue.pop_first()) {
			self.previous = self.state;
			self.state = next.next_state;

			if (self.queue.len() != 0) {
				self.timer.reset_to_secs(self.queue[0].time_secs);
			}
		}
	}
}