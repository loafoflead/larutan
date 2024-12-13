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
