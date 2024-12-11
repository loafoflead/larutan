/*
	Timer struct, to be used with raylib::get_frame_time().

	Methods: 
		- void tick_secs(delta_time) 	-> advances the timer by that amount of time
		- bool finished() 				-> returns whether or not the timer is 0
		- void reset() 					-> resets the timer to 0
*/

struct Timer {
	float maxtime;
	float time;
}

fn Timer new_secs(float duration_secs) {
	return Timer { .maxtime = duration_secs, .time = duration_secs };
}

fn void Timer.tick_secs(Timer* this, float dt) {
	this.time -= dt;
}

fn bool Timer.finished(Timer* this) {
	if (this.time <= 0.0) {
		return true;
	}
	else {
		return false;
	}
}

fn void Timer.reset(Timer* this) {
	this.time = this.maxtime;
}

fn void Timer.set_length_secs(Timer* this, float maxtime_secs) {
	this.maxtime = maxtime_secs;
}