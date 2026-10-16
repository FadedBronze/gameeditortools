# IMPORTANT

if you run the release you won't be able to run a lot of the dev tools (which I am working on and you need to review)
this is intentional because this is a game development toolkit not a standalone game yet (it may become one at some point during terra)
but don't worry its really easy to build!

# Building The Program

download this version of the odin compiler linked here:
[odin version dev-2026-06:285f6d87b](https://github.com/odin-lang/Odin/releases#release-dev-2026-06)

if you don't have msvc (microsoft c++ compiler I think) you will need to install that aswell but its just a few clicks (you'll get an error along the lines Windows SDK not installed)

```
odin run . -collection:project=.
```

# Project Info
This is a game making toolkit to help me make a game eventually (I haven't decided what I want to do)
Right now you can try some of the editor if you use WASD you can move around the cube (drag the grid and scroll to zoom out and move to the bottom)
You can toggle some of the menus via dropdown flags (I implemented the dropdowns and all UI from scratch - it reads the type information like a "game engine style" inpector eg unity)


# Prep Week 1
I joined week two but I did work before week 2 

# Prep Week 2
During the first week I wrote a grid meshing function (you can see the outlines around section of grid that share the same collider)
the main part of this is in ./src/greedymeshing.odin (I also wrote testing code to verify)

# Prep Week 3
week 3 stuff is work in progress and technically your experiencing some week 3 ui but it looks the same as what I had before but its using a new system (ill ship week two when its done enough)

During the third second week, I have been working on reworking the way type information is read (from a runtime model to compile time code generation) in order to see what I like better right now I am bug fixing the code and testing out how I am going to coordinate all the files and what can be updated

# Releases
You can find windows releases in the side (although its being developed on linux - im pretty sure linux binaries aren't transferrable so im not adding those) 
although I think should be easier to just build if you have the odin compiler installed
