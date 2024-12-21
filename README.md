# LARUTAN

LARUTAN (Natural backwards) is a raycasting game in the style of Wolfenstein 3D inspired (the rendering code is entirely copied in fact) by the tutorial by [https://lodev.org/cgtutor/raycasting.html](Lodev). The game is implemented in [https://c3-lang.org](C3), which is a work-in-progress evolution of the C language with built-in vectors and cool macro stuff. 

LARUTAN (NATUREL à l'envers) est un jeu de 'raycasting' dans le style de Wolfenstein 3D, inspiré (en très grande partie, notamment pour le rendu graphique) par le tutoriel de [https://lodev.org/cgtutor/raycasting.html](Lodev). Le jeu est écrit en [https://c3-lang.org](C3), une évolution du langage C avec support pour des vecteurs multi-dimensionnels et de la magie avec les macros qui n'est pas disponible en C.

# Controls

ZQSD (WASD) to move around (ZS/WS to move backwards and forwards, QD/AD to turn), hold LEFT-ALT to strafe (move from side to side), and space (TODO) to fire with the weapon you're currently holding.

# Building

In order to build LARUTAN you will need the C3 compiler, which can be found on the [https://c3-lang.org/install-c3/prebuilt-binaries/](c3 website). Follow that tutorial and once you have the compiler installed (no worries if its in the same directory as the project, that may make things easier, especially if you get a problem with finding the standard library).

You will also need raylib 5.0, which can be found on the [https://raylib.com](raylib) website, although I reccommend finding the binaries in the [https://github.com/raysan5/raylib/releases](github releases page) and installing them in the same directory as this folder. My file structure looks like this:

```
*-- larutan
|
\-- src/
\-- build/
\-- assets/
\-- ...

# -- ELSEWHERE --

*-- /usr/local/lib/
|
\-- raylib-5.5
   \-- lib
   \-- include
   \-- ...
\-- c3
   \-- lib
   \-- c3c
   \-- ...
```

If you installed raylib under a different name then edit the makefile to take this into account, change the variable ```RAYLIB_LIBRARY_SEARCH_PATH``` to the name of your folder containing raylib binaries. If you installed c3 into this directory, then set the ```C3_STD``` variable to be empty. 

Then just run make and hope for the best. Linker errors will be something to do with the folders being called the wrong thing. If you can't get it to work, try just using c3c. 

Additionally, you will need to set up the ```LD_LIBRARY_PATH``` variable to point to wherever you're keeping your raylib. I reccommend putting it in /usr/local/lib (as people do).

Your command should look something like this:

```
user$ c3c compile-run src/*.c3 -lraylib -L<your path to raylib's binaries> --std-lib <your path to C3 standard library>
```

If you have any further issues, try googling around or asking an elder. Or open an issue.

# NOTES

The reason for this project are the recreational programming streams by [github.com/tsoding](Tosding). This isn't the first raycaster I've made but his streams encouraged me to try a new language so... I recommend his streams/vids. I'll list more inspirations as the project advances. 

The code structure is at some points very much inspired by DOOM 1993, for instance the entity think system, the hitboxes and physics and stuff. I recommend checking out the [https://github.com/id-Software/DOOM](source code). It's not exactly an easy read, and in fact I haven't actually read any of it myself, but have seen a few videos about it. I recommend [https://m.youtube.com/decino](decino) for breakdowns on Entity and weapon systems.  

The project is in its very early stages... not many things work but the very basic engine. Plans are to optimise (very slow) and add real gameplay, notably using weapons, picking up weapons, enemy ai that works, and a physics implementation that isn't simply: 'try everything against everything else and hope for the best.' Thank you for your patience. 

# CREDITS

Credit for brick wall texture: [https://www.the3rdsequence.com/texturedb/texture/9/brick+wall/](TODO: find this person's name)

TODO: 
 - License (same as raylib)
 - Version française.