
# Building The Program
run with

```
odin run src -collection:project=.
```
odin version dev-2026-06:285f6d87b

you can run the new meta ui generation script with
(delete the file or files in src/*.widget.odin and rerun)

```
odin run meta -collection:project=.
```

# Project Info
This is a game making toolkit to help me make a game eventually (I haven't decided what I want to do)
Right now you can try some of the editor if you use WASD you can move around the cube (drag the grid and scroll to zoom out and move to the bottom)
You can toggle some of the menus via dropdown flags (I implemented the dropdowns and all UI from scratch - it reads the type information like a "game engine style" inpector eg unity)


# Week 1
I joined week two but I did work before week 2 

# Week 2
During the first week I wrote a grid meshing function (you can see the outlines around section of grid that share the same collider)
the main part of this is in ./src/greedymeshing.odin (I also wrote testing code to verify)

# Week 3
During the second week, I have been working on reworking the way type information is read (from a runtime model to compile time code generation) in order to see what I like better right now I am bug fixing the code and testing out how I am going to coordinate all the files and what can be updated

# Releases
You can find windows releases in the side (although its being developed on linux - im pretty sure linux binaries aren't transferrable so im not adding those) 
although I think should be easier to just build if you have the odin compiler installed
