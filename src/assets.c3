import std::collections::list;
import std::collections;
import std::math;
import std::math::vector;
import raylib;

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
	io::printfn("%d -> %d", type, self.default_names.get(type)!!);
}

fn AssetHandleList! Assets.load_many(Assets* self, AssetDescriptor[] descs) {
	self.assets.reserve(descs.len);
	// TODO: find a way to reserve more stuff for hashmap?
	// self.assets_named.resize(self.assets_named.len + descs.len);
	AssetHandleList list; list.new_init();
	foreach (i, desc: descs) {
		list.push(self.load(desc.filepath, desc.type, desc.name)!);
		io::printfn("INFO: Loaded %s from %s.", desc.name, desc.filepath);
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

fn AssetHandle! Assets.load(Assets* self, String filepath, AssetType type, String name="") {
	switch (type) {
		case AssetType.PNGIMAGE:
			Image* img = calloc(Image.sizeof);
			*img = raylib::load_image(filepath);
			// TODO: check image is loaded
			if (img.format <= 0||img.format != 7) { 
				return AssetError.COULD_NOT_LOAD_IMAGE?;
			}
			String realname = name == "" ? filepath : name;
			Asset new = Asset {
				.desc = AssetDescriptor {
					.name = realname,
					.filepath = filepath,
					.type = type
				},
				.ready = false,
				.data = (void*)img,
			};
			usz new_idx = self.assets.len();
			self.assets.push(new);
			AssetHandle handle = AssetHandle { .name = realname };
			self.assets_named[handle] = new_idx;
			return handle;
		default:
			return AssetError.UNIMPLEMENTED_TYPE?;
	}
}

fn Asset*! Assets.get(Assets* self, AssetHandle* handle) {
	if (handle == null) {
		return AssetError.BAD_HANDLE?;
	}
	usz idx = self.assets_named.get(*handle)!;
	Asset* ass = self.assets.get_ref(idx); // TODO: maybe AssetError.NOT_FOUND?
	if (ass == null) return AssetError.NOT_FOUND?;
	if (!ass.ready) return AssetError.LOADING?;
	/*switch (ass.type) {
		case AssetType.PNGIMAGE:
			// FIXME: this is so uggers yo
			// !raylib::is_image_ready(*((Image*)ass.data)) || 
		default:
			return AssetError.UNIMPLEMENTED_TYPE?;
	}*/
	
	return ass;
}

fn Asset*! Assets.get_name(Assets* self, String name) {
	AssetHandle handle = AssetHandle { .name = name };
	return self.get(&handle)!;
}

fn Asset*! Assets.get_default(Assets* self, AssetType type) {
	if (!self.default_names.has_key(type)) {
		return AssetError.NOT_FOUND?;
	}
	Asset* ass = self.assets.get_ref(self.default_names[type]!);
	if (!ass.ready) return AssetError.LOADING?;
	return ass;
}