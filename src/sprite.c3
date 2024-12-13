import std::math::vector;
import std::collections::list;

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
				SpriteSheet sprite_sheet;
			}
		}
	}

	Vec2 uv_scale_division;
	double z;
	Vec2 pos;
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

struct Sprite {
	usz[<4>] portion;
}


// sprite dimensions is the size of a single sprite in the sheet
// TODO: support sprites of different sizes with a vec
fn EntityModel! new_spritesheet(usz texture_index, usz w, usz h, usz[<2>] sprite_dimensions, double z = 0.0, Vec2 uv_scale_division = {1.0, 1.0}) {
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
		.z = z,
		.uv_scale_division = uv_scale_division,
		.pos = {0, 0},
		.player_dist = 0.0,
	};
	return new;
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
		.player_dist = 0.0,
	};
	return new;
}