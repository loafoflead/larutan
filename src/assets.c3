import std::collections::list;
import std::math;
import std::math::vector;
import raylib;

import std::io;

def ImageList = List(<Image>);

struct Assets {
	ImageList world_textures;
	ImageList sprite_textures;
	ImageList weapon_textures;
	Image missing;
}

fn ImageList Assets.load_images(Assets this, String[] paths) {
	ImageList images;
	images.new_init();
	io::printn("TODO: don't do this, make it similar to the '@get' interface, and make the sizes not be constants because that's a bit schewpid in the year of our lord twenty twenty four");

	foreach (path: paths) {
		images.push(raylib::load_image(path));
		// TODO: don't do this, make it similar to the '@get'
		// interface, and make the sizes not be constants because that's a 
		// bit schewpid in the year of our lord twenty twenty four
	}
	return images;
}

fn void Assets.free(Assets this) {
	foreach (asset: this.world_textures) {
		raylib::unload_image(asset);
	}

	foreach (asset: this.sprite_textures) {
		raylib::unload_image(asset);
	}

	foreach (asset: this.weapon_textures) {
		raylib::unload_image(asset);
	}

	raylib::unload_image(this.missing);
}

fn bool Assets.assert_loaded(Assets this) {
	io::printfn("TODO: IMPLEMENT CHECKING ASSETS LOADED CORRECTLY");

	return true;
	//for (int i = 0; i < TEXTURE_COUNT; i ++) {
	//	if (textures[i].data == null) {
	//		io::printfn("Failed to load '%s', file not found or corrupt.", image_paths[i ]);
	//		return -1;
	//	}
	//	else if (textures[i].format != 7) {
	//		io::printfn("Failed to load '%s', file is in the wrong pixel format (need R8G8B8A8, soit 32bpp)\n", image_paths[i]);
	//		return -1;
	//	}
	//}
}
