import std::math::vector;
import std::collections::list;
import std::math;

def ModelList = List(<EntityModel*>);

fault SpriteSheetError {
	WIDTH_MISMATCH,
	HEIGHT_MISMATCH,
	NTH_TOO_FAR,
}

fault EntityModelError {
	UNIMPLEMENTED_TYPE,
}

struct EntityModel {
	struct {
		usz texture_index;
		ModelType type;
		union {
			Sprite sprite;
			struct {
				bool is_relative_to_player;
				SpriteSheet sprite_sheet;
			}
		}
	}

	Vec2 uv_scale_division;
	double z;
	Vec2 pos;
	double dir;
	double player_dist;
}

enum ModelType {
	SPRITE_SHEET,
	SPRITE,
}

struct SpriteSheet {
	usz w, h;
	usz rows, cols;
	usz[<2>] sprite_dimensions;
	usz current_index;
}

fn usz[<4>]! SpriteSheet.get_nth(&self, int n = -1) {
	if (n == -1) {
		n = (int)self.current_index;
	}
	usz count = self.rows * self.cols;
	if (n >= count) return SpriteSheetError.NTH_TOO_FAR?; 
	// n = rows * y + x
	// x = n % rows
	// y = (n - x) / self.rows
	usz x = n % self.rows;
	usz img_x  = x * self.sprite_dimensions.x;
	usz img_y  = ((n - x)/self.rows) * self.sprite_dimensions.y;
	usz[<4>] rect = {
		img_x,
		img_y,
		self.sprite_dimensions.x,
		self.sprite_dimensions.y,
	};
	return rect;
}

// TODO: decrement and friends
fn void SpriteSheet.increment(&self) {
	self.current_index += 1;
	self.current_index %= self.cols*self.rows;
}

fn void SpriteSheet.set_index(&self, usz i) {
	self.current_index = i;
	self.current_index %= self.cols*self.rows;
}

struct Sprite {
	usz[<4>] portion;
}


// sprite dimensions is the size of a single sprite in the sheet
// TODO: support sprites of different sizes with a vec
fn EntityModel! new_spritesheet(usz texture_index, usz w, usz h, usz[<2>] sprite_dimensions, bool is_relative = false, double z = 0.0, Vec2 uv_scale_division = {1.0, 1.0}) {
	if (w % sprite_dimensions.x != 0) {
		return SpriteSheetError.WIDTH_MISMATCH?;
	}
	if (h % sprite_dimensions.y != 0) {
		return SpriteSheetError.HEIGHT_MISMATCH?;
	}
	SpriteSheet sprite_sheet = SpriteSheet {
		.w = w, 
		.h = h,
		.rows = w / sprite_dimensions.x,
		.cols = h / sprite_dimensions.y,
		.sprite_dimensions = sprite_dimensions,
	};

	EntityModel new = EntityModel {
		.texture_index = texture_index,
		.type = ModelType.SPRITE_SHEET,
		.sprite_sheet = sprite_sheet,
		.is_relative_to_player = is_relative,
		.z = z,
		.uv_scale_division = uv_scale_division,
		.pos = {0, 0},
		.dir = 0.0,
		.player_dist = 0.0,
	};
	return new;
}

fn void EntityModel.set_spritesheet_portion(&self, Vec2 player_pos) {
	switch (self.type) {
		case ModelType.SPRITE_SHEET:
			if (!self.is_relative_to_player) {
				return;
			}
			Vec2 me_to_player = player_pos - self.pos;
			double ang = math::atan2(me_to_player.x, me_to_player.y) + self.dir; 

			usz n = self.sprite_sheet.rows * self.sprite_sheet.cols;
			usz idx = (usz)((ang / (2.0 * math::PI)) * (double)n);

			self.sprite_sheet.set_index(idx);
		case ModelType.SPRITE:
			return;
	}
}

fn usz[<4>]! EntityModel.image_portion(&self) {
	switch (self.type) {
		case ModelType.SPRITE_SHEET:
			return self.sprite_sheet.get_nth()!;
		case ModelType.SPRITE:
			return self.sprite.portion;
		default:
			return EntityModelError.UNIMPLEMENTED_TYPE?;
	}
}


fn EntityModel new_sprite(usz texture_index, double z = 0.0, Vec2 uv_scale_division = {1.0, 1.0}) {
	EntityModel new = EntityModel {
		.texture_index = texture_index,
		.sprite = Sprite {
			.portion = {0, 0, 0, 0}, // this means the whole image 
									 // TODO: make this type-ifically clear(?)	
		},
		.type = ModelType.SPRITE,
		.z = z,
		.uv_scale_division = uv_scale_division,
		.pos = {0, 0},
		.dir = 0.0,
		.player_dist = 0.0,
	};
	return new;
}