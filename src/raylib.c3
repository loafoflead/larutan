import std::math;
import math;

const int KEY_S = 83;
const int KEY_W = 87;
const int KEY_D = 68;
const int KEY_A = 65;
const int KEY_SPACE = 32;
const int KEY_LEFT_ALT = 342;
const int KEY_RIGHT_ALT = 346;

def Colour = char[<4>];


// Raylib Image struct 
struct Image {
    char[<4>] *data;             // Image raw data
    int width;              // Image base width
    int height;             // Image base height
    int mipmaps;            // Mipmap levels, 1 by default
    int format;             // Data format (PixelFormat type)
}

struct Texture {
    uint id;        // OpenGL texture id
    int width;              // Texture base width
    int height;             // Texture base height
    int mipmaps;            // Mipmap levels, 1 by default
    int format;             // Data format (PixelFormat type)
}

struct NPatchInfo {
    Rect source;       // Texture source rectangle
    int left;               // Left border offset
    int top;                // Top border offset
    int right;              // Right border offset
    int bottom;             // Bottom border offset
    int layout;             // Layout of the n-patch: 3x3, 1x3 or 3x1
}

// Ray, ray for raycasting
struct Ray {
    Vec3f position;       // Ray position (origin)
    Vec3f direction;      // Ray direction
}

// RayCollision, ray hit information
struct RayCollision {
    bool hit;               // Did the ray hit something?
    float distance;         // Distance to the nearest hit
    Vec3f point;          // Point of the nearest hit
    Vec3f normal;         // Surface normal of hit
}

// BoundingBox
struct BoundingBox {
    Vec3f min;            // Minimum vertex box-corner
    Vec3f max;            // Maximum vertex box-corner
}

extern fn void init_window(int width, int height, char* title) @extern("InitWindow");
extern fn void close_window() @extern("CloseWindow");
extern fn bool window_should_close() @extern("WindowShouldClose"); 
extern fn void begin_drawing() @extern("BeginDrawing");
extern fn void end_drawing() @extern("EndDrawing");

extern fn void clear_background(Colour color) @extern("ClearBackground");

extern fn void draw_rectangle(int posX, int posY, int width, int height, Colour color) @extern("DrawRectangle"); 
fn void draw_rect(Rect rect, Colour colour) {
    draw_rectangle((int)rect.x, (int)rect.y, (int)rect.w, (int)rect.h, colour);
}
extern fn void draw_line_ex(Vec2 startPos, Vec2 endPos, float thick, Colour color) @extern("DrawLineEx");
extern fn void draw_line_v(Vec2 startPos, Vec2 endPos, Colour color) @extern("DrawLineV");
extern fn void draw_line(int startPosX, int startPosY, int endPosX, int endPosY, Colour color) @extern("DrawLine");
extern fn void draw_grid(int slices, float spacing) @extern("DrawGrid");                                                          // Draw a grid (centered at (0, 0, 0))


extern fn float get_frame_time() @extern("GetFrameTime"); 
extern fn double get_time() @extern("GetTime");                                       // Get elapsed time in seconds since InitWindow()

extern fn void set_target_fps(int max_fps) @extern("SetTargetFPS");

extern fn bool is_key_pressed(int key) @extern("IsKeyPressed");
extern fn bool is_key_down(int key) @extern("IsKeyDown");

extern fn Image gen_image_colour(int width, int height, Colour color) @extern("GenImageColor");                                           // Generate image: plain color
extern fn Image load_image(char* file_path) @extern("LoadImage");
extern fn Image load_image_from_memory(char *fileType, char *fileData, int dataSize) @extern ("LoadImageFromMemory");
extern fn Image load_image_from_screen() @extern("LoadImageFromScreen");                                                                   // Load image from screen buffer and (screenshot)
extern fn void update_texture(Texture texture, char *pixels) @extern("UpdateTexture");                                         // Update GPU texture with new data
extern fn Texture load_texture_from_image(Image image) @extern("LoadTextureFromImage");                                                       // Load texture from image data
extern fn void draw_texture(Texture texture, int posX, int posY, Colour tint) @extern("DrawTexture");
extern fn void unload_texture(Texture texture) @extern("UnloadTexture");

extern fn void draw_texture_with_params(Texture texture, NPatchInfo nPatchInfo, Rect dest, Vec2 origin, float rotation, Colour tint) @extern("DrawTextureNPatch"); // Draws a texture (or part of it) that stretches or shrinks nicely

extern fn Image image_from_image(Image image, Rect rec) @extern("ImageFromImage");                                                  // Create an image from another image piece

extern fn bool is_image_ready(Image image) @extern("IsImageReady");                                                                    // Check if an image is ready

extern fn void unload_image(Image image) @extern("UnloadImage");


extern fn RayCollision get_ray_collision_box(Ray ray, BoundingBox box) @extern("GetRayCollisionBox");                                    // Get collision info between ray and box
extern fn void draw_ray(Ray ray, Colour color) @extern("DrawRay");                                                                // Draw a ray line
extern fn bool check_collision_lines(Vec2f startPos1, Vec2f endPos1, Vec2f startPos2, Vec2f endPos2, Vec2f *collisionPoint) @extern("CheckCollisionLines"); // Check the collision between two lines defined by two points each, returns collision point by reference

fault HitError {
    NOT_HIT,
}

fn Vec2f! line_collides_rect(Rect rect, Vec2f start_1, Vec2f start_2) {
    Vec2f point;
    bool hits = false;

    /*
        a----b
        |    |
        c----d

        a: (x, y)
        b: (x + w, y)
        c: (x, y + h)
        d: (x + w, y + h)
    */

    // ab
    hits = check_collision_lines(
        start_1, start_2,
        {rect.x, rect.y},
        {rect.x + rect.w, rect.y},
        &point,
    );

    if (hits) {
        return point;
    }

    // ac
    hits = check_collision_lines(
        start_1, start_2,
        {rect.x, rect.y},
        {rect.x, rect.y + rect.h},
        &point,
    );

    if (hits) {
        return point;
    }

    // cd
    hits = check_collision_lines(
        start_1, start_2,
        {rect.x, rect.y + rect.h},
        {rect.x + rect.x, rect.y + rect.h},
        &point,
    );

    if (hits) {
        return point;
    }

    // bd
    hits = check_collision_lines(
        start_1, start_2,
        {rect.x + rect.w, rect.y},
        {rect.x + rect.w, rect.y + rect.h},
        &point,
    );

    if (hits) {
        return point;
    }

    return HitError.NOT_HIT?;
}