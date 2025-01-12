import std::collections::list;
import std::collections;
import std::math;
import std::math::vector;
import bindings;
import main;
import rendering;

import std::io;

def AssetList = List(<Asset>);
def AssetNameMap = HashMap(<AssetHandle, usz>);
def DefaultAssetsMap = HashMap(<AssetType, usz>);
def AssetHandleList = List(<AssetHandle>);

fault AssetError {
	UNIMPLEMENTED_TYPE,
	COULD_NOT_LOAD_IMAGE,
	NOT_FOUND,
	LOADING,
	BAD_HANDLE,
	FAILED_TO_LOAD_ALL,
	MISSING_DESCRIPTION_OF_SPRITESHEET,
}

struct Assets {
	AssetList assets;
	AssetNameMap assets_named;
	DefaultAssetsMap default_names;
}

struct Asset {
	inline AssetDescriptor desc;
	bool ready;
	void* data;
}

struct AssetDescriptor 
{
	String name;
	String filepath;
	AssetType type;
	union {
		SpriteSheetData spritesheet_info;
		SpriteData sprite_info;
	}
}

struct SpriteSheetData {
	usz w, h;
	usz rows, cols;
	usz[<2>] sprite_dimensions;
	usz index_of_zero;
}

fn SpriteSheetData! spritesheet(usz w, usz h, usz[<2>] dims, usz zero = 0) {
	if (w % dims.x != 0) {
		return SpriteSheetError.WIDTH_MISMATCH?;
	}
	if (h % dims.y != 0) {
		return SpriteSheetError.HEIGHT_MISMATCH?;
	}

	return SpriteSheetData {
		.w = w,
		.h = h,
		.rows = w / dims.x,
		.cols = h / dims.y,
		.sprite_dimensions = dims,
		.index_of_zero = 0,
	};
}

struct SpriteData {
	Colour tint;
}

fn bool SpriteData.equals(SpriteData self, SpriteData other) {
	return self.tint == other.tint;
}

fn bool SpriteSheetData.equals(SpriteSheetData self, SpriteSheetData other) {
	return self.w == other.w 
	&& self.h == other.h 
	&& self.rows == other.rows 
	&& self.cols == other.cols 
	&& self.sprite_dimensions == other.sprite_dimensions;
}

struct AssetHandle(Printable) {
	String name;
}

fn uint AssetHandle.hash(AssetHandle* ah) @dynamic {
	return ah.name.hash();
}

fn bool AssetHandle.equals(AssetHandle ah, AssetHandle bh) {
	return ah.name == bh.name;
}

fn AssetHandle new_asset_handle(String name) {
	return AssetHandle { .name = name };
}

enum AssetType: usz {
	PNGIMAGE,
	SPRITESHEET,
	MAP,
}

fn uint AssetType.hash(AssetType* self) @dynamic {
	return ((iptr)*self).hash();
}

fn void Assets.new_init(Assets* self) {
	self.assets.new_init();
	self.assets_named.new_init();
	self.default_names.new_init();
}

fn void Assets.free(Assets* self) {
	io::printfn("TODO: free assets (no way! what a great price!)");
}

fn bool Assets.assert_loaded(Assets* self) {
	io::printfn("TODO: validate 'loaded' assets");
	return true;
}

fn void Assets.set_type_default(&self, AssetType type, Asset a) {
	usz idx = self.assets.len();
	self.assets.push(a);
	self.default_names.set(type, idx);
	io::printfn("%s -> %d", AssetType.names[type], self.default_names.get(type)!!);
}

fn AssetHandleList! Assets.load_many(Assets* self, AssetDescriptor[] descs) {
	self.assets.reserve(descs.len);
	// TODO: find a way to reserve more stuff for hashmap?
	// self.assets_named.resize(self.assets_named.len + descs.len);
	AssetHandleList list; list.new_init();
	foreach (i, desc: descs) {
		if (try new = self.load(desc)) {
			list.push(new);
			io::printfn("INFO: Loaded %s from %s.", desc.name, desc.filepath);
		}
		else if (catch err = self.load(desc)) {
			io::printfn("Failed to load %s: %s", desc.filepath, err);
		}
	}
	return list;
}

// returns false if we should stop polling
fn bool! Assets.poll_ready(Assets* self) {
	bool keep_goin = false;
	foreach (&ass: self.assets) {
		if (ass.ready) continue;

		switch (ass.type) {
			case AssetType.PNGIMAGE:
				if ( raylib::is_image_ready(*((Image*)ass.data)) ) {
					ass.ready = true;
				}
				else {
					keep_goin = true;					
				}
			default:
				return AssetError.UNIMPLEMENTED_TYPE?;
		}
	}
	if (keep_goin == false) {
		io::printn("Finished loading assets!");
	}
	return keep_goin;
}

fn AssetHandle! Assets.load(Assets* self, AssetDescriptor desc) {
	Asset new;
	switch (desc.type) {
		case AssetType.PNGIMAGE:
			Image* img = calloc(Image.sizeof);
			*img = raylib::load_image(desc.filepath);
			// TODO: check image is loaded
			if (img.format <= 0||img.format != 7) { 
				return AssetError.COULD_NOT_LOAD_IMAGE?;
			}
			String realname = desc.name == "" ? desc.filepath : desc.name;
			SpriteData info = {};
			if (desc.sprite_info.equals(info)) {
				info.tint = main::WHITE;
			}
			else {
				info = desc.sprite_info;
			}
			new = Asset {
				.desc = AssetDescriptor {
					.name = realname,
					.filepath = desc.filepath,
					.type = AssetType.PNGIMAGE,
					.sprite_info = info,
				},
				.ready = false,
				.data = (void*)img,
			};
		case AssetType.SPRITESHEET:
			Image* img = calloc(Image.sizeof);
			*img = raylib::load_image(desc.filepath);
			// TODO: check image is loaded
			if (img.format <= 0||img.format != 7) { 
				return AssetError.COULD_NOT_LOAD_IMAGE?;
			}
			String realname = desc.name == "" ? desc.filepath : desc.name;
			SpriteSheetData info = {};
			if (desc.spritesheet_info.equals(info)) {
				return AssetError.MISSING_DESCRIPTION_OF_SPRITESHEET?;
			}
			else {
				info = desc.spritesheet_info;
			}
			new = Asset {
				.desc = AssetDescriptor {
					.name = realname,
					.filepath = desc.filepath,
					.type = AssetType.PNGIMAGE,
					.spritesheet_info = info,
				},
				.ready = false,
				.data = (void*)img,
			};
		default:
			return AssetError.UNIMPLEMENTED_TYPE?;
	}

	usz new_idx = self.assets.len();
	self.assets.push(new);
	AssetHandle handle = AssetHandle { .name = new.name };
	self.assets_named[handle] = new_idx;
	return handle;
}

fn Asset*! Assets.get(Assets* self, AssetHandle* handle) {	
	if (handle == null) {
		return AssetError.BAD_HANDLE?;
	}
	usz idx = self.assets_named.get(*handle)!;
	Asset* ass = self.assets.get_ref(idx);
	if (ass == null) return AssetError.NOT_FOUND?;
	if (!ass.ready) return AssetError.LOADING?;
	
	return ass;
}

fn usz! Assets.index_of_name(Assets* self, String name) {
	AssetHandle handle = AssetHandle { .name = name };

	usz idx = self.assets_named.get(handle)!;
	return idx;
}

fn usz! Assets.index_of_default(Assets* self, AssetType type) {
	usz idx = self.default_names.get(type)!;
	return idx;
}

fn Asset*! Assets.get_name(Assets* self, String name) {
	AssetHandle handle = AssetHandle { .name = name };
	return self.get(&handle)!;
}

fn AssetDescriptor*! Assets.get_name_desc(Assets* self, String name) {
	AssetHandle handle = AssetHandle { .name = name };
	usz idx = self.assets_named.get(handle)!;
	Asset* ass = self.assets.get_ref(idx);
	if (ass == null) return AssetError.NOT_FOUND?;
	return &ass.desc;
}

fn Asset*! Assets.get_default(Assets* self, AssetType type) {
	if (!self.default_names.has_key(type)) {
		return AssetError.NOT_FOUND?;
	}
	Asset* ass = self.assets.get_ref(self.default_names[type]!);
	if (!ass.ready) return AssetError.LOADING?;
	return ass;
}