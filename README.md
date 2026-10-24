# CarCross: an Arcade Game in x86 Assembly

A car-dodging arcade game written in 32-bit x86 assembly (80386 protected mode), built by a team of two for the Computersystemen course at Vrije Universiteit Brussel (2023).

Your car drives at the bottom of a five-lane road. Enemy cars appear in random lanes and drive towards you, and you switch lanes with the arrow keys to avoid them. The longer you survive, the faster the enemies drive and the more often they appear. Hit one and it's game over.

## Team

- **Setayesh Baghery:** sprites and graphics (VGA rendering, sprite loading and drawing)
- **Ozioma Olisa:** enemy logic and level progression
- **Together:** keyboard controls

## How it works

- **Graphics:** VGA mode 13h (320×200, 256 colours), drawing straight into video memory at `0xA0000`. Lanes are drawn as vertical lines, and moving objects are redrawn by clearing their old position and drawing the sprite at the new one.
- **Sprites:** car images are stored as raw pixel data in `.bin` files, read with DOS file interrupts and copied to the screen row by row.
- **Timing:** the game loop waits for the monitor's vertical refresh (VBLANK) through the VGA status port, which gives a steady speed and avoids flicker.
- **Input:** a custom keyboard interrupt handler reads raw scan codes. Left/right arrows change lanes, Esc quits.
- **Enemies:** five enemy slots, one per lane. A random lane is activated after each spawn delay, and an enemy that leaves the screen is reset.
- **Collision:** an enemy in the player's lane that overlaps the player's vertical position ends the game.
- **Difficulty:** at regular intervals, enemy speed goes up by one and the spawn delay is halved, down to a minimum.

## Files

| File | Description |
|---|---|
| `CARCROSS.ASM` | The game (started from the course's video-mode template) |
| `KEYB.ASM`, `KEYB.INC` | Keyboard interrupt handler, provided by the course |
| `RAND.ASM`, `RAND.INC` | Random number generator by Tim Bruylants and David Blinder, provided by the course (BSD licence, see file header) |
| `CAR.bin`, `ENE.bin` | Sprite data |
| `MAKEFILE` | Watcom makefile |

## Known limitations

- Enemy cars load the player's sprite (`car_file`) instead of their own, so all cars look the same. The code also looks for `ENEMY.bin`, while the file is named `ENE.bin`.
- There is no score display yet.

## Running it

Requires [DOSBox](https://www.dosbox.com/) with Turbo Assembler (TASM) and the Watcom linker, as set up in the course.

```
wmake
CARCROSS.EXE
```
