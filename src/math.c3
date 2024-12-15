import std::math;

struct Rect {
	float x, y, w, h;
}

enum RectCorner {
	TOP_LEFT,
	TOP_RIGHT,
	BOTTOM_LEFT,
	BOTTOM_RIGHT,
}

const Rect ZERO = {0, 0, 0, 0};

macro bool Rect.equals(Rect *this, Rect that) {
	return this.x == that.x && this.y == that.y && this.w == that.x && this.h == that.h;
}

fn Rect rect_from_usz(usz[<4>] rect) {
	Rect r = {
		(float)rect.r,
		(float)rect.g,
		(float)rect.b,
		(float)rect.a,
	};
	return r;
}

fn bool Rect.contains(Rect this, Vec2 point) {
	return 
		(float)point.x >= this.x 				&& 
		(float)point.y >= this.y 				&&
		(float)point.x <= (this.x + this.w) 	&&
		(float)point.y <= (this.y + this.h);
}

fn bool Rect.contains_rect(Rect this, Rect other) {
	Vec2 tl = other.corner(RectCorner.TOP_LEFT);
	Vec2 tr = other.corner(RectCorner.TOP_RIGHT);
	Vec2 bl = other.corner(RectCorner.BOTTOM_LEFT);
	Vec2 br = other.corner(RectCorner.BOTTOM_RIGHT);
	return 
		this.contains(tl) ||
		this.contains(tr) ||
		this.contains(bl) ||
		this.contains(br);
}

fn Rect Rect.intersection(Rect this, Rect other) {
	// TODO: write working intersection check
	if (!this.contains_rect(other)) {
		return {0, 0, 0, 0};
	}

	float left = math::max(this.x, other.x);
	float width = math::min(this.x + this.w, other.x + other.w) - left;
	float top = math::max(this.y, other.y);
	float height = math::min(this.y + this.h, other.y + other.h) - top;

	return Rect { left, top, width, height };
}

fn Vec2 Rect.corner(Rect this, RectCorner corner) {
	switch (corner) {
		case RectCorner.TOP_LEFT:
			return {this.x, this.y};
		case RectCorner.BOTTOM_LEFT:
			return {this.x, (double)(this.y + this.h)};
		case RectCorner.BOTTOM_RIGHT:
			return {(double)(this.x + this.w), (double)(this.y + this.h)};
		case RectCorner.TOP_RIGHT:
			return {(double)(this.x + this.w), this.y};
	}
}

// Code from: en.m.wikipedia.oog/wiki/Cohen%E2%80%92Sutherland_alogrithm
distinct Outcode = int;
const int INSIDE 	= 0b0000;
const int LEFT 		= 0b0001;
const int RIGHT 	= 0b0010;
const int BOTTOM 	= 0b0100;
const int TOP 		= 0b1000;

fn Outcode Rect.compute_out_code(self, Vec2 pos) {
	Outcode out = INSIDE;

	if (pos.x < self.x) out |= LEFT;
	if (pos.x > (double)(self.x + self.w)) out |= RIGHT;
	if (pos.y < self.y) out |= BOTTOM;
	if (pos.y > (double)(self.y + self.h)) out |= TOP;

	return out;
}

fn bool Rect.cohen_suher_line_clips(self, Vec2 origin, Vec2 end) {
	Outcode outcode_0 = self.compute_out_code(origin);
	Outcode outcode_1 = self.compute_out_code(end);
	bool accept = false;

	usz i = 0;

	while (true) {
		i ++;
		if (i > 1000) break;
		
		if (!(outcode_0 | outcode_1)) {
			accept = true;
			break;
		}
		else if (outcode_0 & outcode_1) {
			break;
		}
		else {
			Vec2 pos;
			Outcode outcode_out = (outcode_1 > outcode_0) ? outcode_1 : outcode_0;

			if (outcode_out & TOP) {
				pos.x = origin.x + (end.x - origin.x) * ((double)(self.y + self.h) - origin.y) / (end.y - origin.y);
				pos.y = (double)(self.y + self.h);
			}
			else if (outcode_out & BOTTOM) {
				pos.x = origin.x + (end.x - origin.x) * (self.y - origin.y) / (end.y - origin.y);
				pos.y = self.y;
			}
			if (outcode_out & TOP) {
				pos.y = origin.y + (end.y - origin.y) * ((double)(self.x + self.w) - origin.x) / (end.x - origin.x);
				pos.x = (double)(self.x + self.w);
			}
			else if (outcode_out & BOTTOM) {
				pos.y = origin.y + (end.y - origin.y) * (self.x - origin.x) / (end.x - origin.x);
				pos.x = self.x;
			}

			if (outcode_out == outcode_0) {
				origin = pos;
				outcode_0 = self.compute_out_code(origin);
			}
			else {
				end = pos;
				outcode_1 = self.compute_out_code(end);
			}
		}
	}
	return accept;
}