# Chapter 4: How Much It Matters

Inputs tell an agent what's true. **Curves** tell it how much each truth matters. Two goblins can know exactly the same things, the same health, the same distances, and still behave completely differently, because one cares about its health in a straight line and the other doesn't care at all until suddenly it cares about nothing else. That difference lives entirely in curves.

So far the goblin has used one shape, the falling straight line. This chapter covers every curve GMSmartAgent has, how to read one, how to choose one by asking the right question, how curves interact with the multiplication from Chapter 2, and how to draw them on screen so you can see what you're tuning. By the end, the goblin's fear and thirst have shapes you chose on purpose.

---

## Reading a curve

A curve takes a normalized input, a number from 0 to 1, and returns a consideration, another number from 0 to 1. Picture it as a graph:

- **Across the bottom, x:** the input, from 0 on the left to 1 on the right. For health, 0 is dead and 1 is full. For distance, 0 is right here and 1 is the far end of the range.
- **Up the side, y:** how much the option cares, from 0 at the bottom, "not at all, veto", to 1 at the top, "as much as it gets".

Reading a curve is reading that graph left to right and asking at every point: at this value, how much does it matter? The falling line from the earlier chapters reads: at 0 it matters fully, and it matters a little less with every step to the right, evenly, until it doesn't matter at all at 1.

Three features of a curve's shape are worth naming, because they're what you'll actually be choosing:

- **Where it changes.** Is the interesting part at the low end, the high end, or somewhere in the middle?
- **How sharply it changes.** Does it drift gently from one end to the other, or flip from low to high over a short stretch?
- **Where it ends.** Does it reach 0, vetoing the option, or level off above 0 so the option always stays possible?

Every curve type below is a different answer to those three questions.

---

## Seeing your curves

Curves are much easier to tune when you can see them. Here's a small function that draws one in a box, with a marker showing where the current input value sits on it. Add it to any script:

```gml
/// Draws a curve in a box, with the current input marked on it.
function draw_curve_box(_curve, _x, _y, _w, _h, _label, _value = undefined) {
    draw_rectangle(_x, _y, _x + _w, _y + _h, true);

    var _px = _x;
    var _py = _y + _h * (1 - gmsa_curve_eval(_curve, 0));
    for (var _i = 1; _i <= 50; _i++) {
        var _cx = _x + _w * _i / 50;
        var _cy = _y + _h * (1 - gmsa_curve_eval(_curve, _i / 50));
        draw_line(_px, _py, _cx, _cy);
        _px = _cx;
        _py = _cy;
    }

    if (_value != undefined) {
        var _vx = _x + _w * clamp(_value, 0, 1);
        var _vy = _y + _h * (1 - gmsa_curve_eval(_curve, _value));
        draw_line(_vx, _y, _vx, _y + _h);
        draw_circle(_vx, _vy, 3, false);
    }

    draw_text(_x, _y + _h + 4, _label);
}
```

`gmsa_curve_eval(curve, x)` is the function GMSmartAgent itself uses when it scores: it takes a curve and an input from 0 to 1 and returns the consideration. Calling it yourself is the most direct way to check a curve, in a test, in the debug console, or on screen.

Try it with the falling line. Make the curve once, in Create, and draw it every frame:

```gml
// o_goblin > Create (add)
view_falling = gmsa_curve_make(gmsa_curve.LINEAR, { m : -1, b : 1 });
```

```gml
// o_goblin > Draw GUI (add)
draw_curve_box(view_falling, 400, 40, 160, 100, "drink: hp", hp / 100);
```

Press up and down and watch the marker slide along the line. Keep this function; the rest of the chapter uses it to look at every shape.

---

## The four parameters

Every curve type in GMSmartAgent takes the same four parameters, so switching from one type to another never means learning a new set of knobs:

| Parameter | Meaning |
| --- | --- |
| `m` | **Scale.** Stretches the curve vertically. Negative flips it upside down |
| `k` | **Shape.** The exponent of a power curve, or the steepness of an S-curve |
| `b` | **Shift up or down.** Added at the end |
| `c` | **Shift left or right.** Where the interesting part sits: the threshold of a step, the middle of an S-curve |

Plus one switch, `invert`, which flips the finished output: every `y` becomes `1 - y`.

Whatever the parameters produce, the result is **clamped** to 0..1 before it's used. A curve can't go above 1 or below 0, however the numbers work out. That turns out to be useful: you can shift a curve down so that part of it falls below 0, and that part simply becomes 0, a region where the option is vetoed.

---

## LINEAR: an even change

```gml
gmsa_curve_make(gmsa_curve.LINEAR, { m : ..., b : ..., c : ... })
```

```
y = m * (x - c) + b
```

A straight line. `m` is its slope, `b` where it starts, `c` slides it sideways. The defaults, `m` 1 and `b` 0, give the plain rising line: `y = x`.

| x | 0 | 0.2 | 0.4 | 0.6 | 0.8 | 1 |
| --- | --- | --- | --- | --- | --- | --- |
| Rising, default | 0 | 0.2 | 0.4 | 0.6 | 0.8 | 1 |
| Falling, `{ m : -1, b : 1 }` | 1 | 0.8 | 0.6 | 0.4 | 0.2 | 0 |
| Floor at 0.2, `{ m : 0.8, b : 0.2 }` | 0.2 | 0.36 | 0.52 | 0.68 | 0.84 | 1 |

A straight line says: every bit of change matters equally. Going from 90 health to 80 makes the goblin exactly as much more thirsty as going from 30 to 20. That's honest when it's true, like "more gold is better, proportionally", and wrong for most things that feel urgent. People don't care about health in a straight line: the difference between 90 and 80 is nothing, and the difference between 20 and 10 is everything.

Lines are also useful for squeezing the interesting part into a stretch of the input. A steep line hits the clamp early. `{ m : -2.5, b : 1.5 }` is 1 all the way to x = 0.2, then falls evenly to 0 at x = 0.6, and stays 0 beyond: a goblin that cares fully below 20% health, not at all above 60%, and evenly in between.

The third row is a **floor**. The line never drops below 0.2, so the option is never vetoed by this consideration: it can be weakened, but not ruled out. That matters more than it looks, and there's a section on it below.

---

## POWER: a slow start or a fast one

```gml
gmsa_curve_make(gmsa_curve.POWER, { k : ..., m : ..., c : ... })
```

```
y = m * (x - c)^k + b
```

`k` is the exponent, 2 by default. Above 1, the curve starts slowly and rises steeply at the end. Below 1, it rises steeply at first and levels off.

| x | 0 | 0.1 | 0.2 | 0.3 | 0.5 | 0.7 | 0.9 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `k` 2, the default | 0 | 0.01 | 0.04 | 0.09 | 0.25 | 0.49 | 0.81 | 1 |
| `k` 0.5, a root | 0 | 0.32 | 0.45 | 0.55 | 0.71 | 0.84 | 0.95 | 1 |

These two answer opposite questions:

- **`k` above 1: only a lot matters.** A little danger is nothing, a lot of danger is everything. A small crowd doesn't worry the goblin; a big one terrifies it.
- **`k` below 1: a little goes a long way.** The first coin in the goblin's pouch makes it much happier than the fiftieth. A small chance of being seen is already a big deal to a thief.

Shifting with `c` moves where the curve bottoms out. `{ c : 1 }` with the default `k` of 2 gives `(x - 1)^2`, which is 1 at x = 0 and falls to 0 at x = 1, steeply at first:

| x | 0 | 0.1 | 0.2 | 0.3 | 0.5 | 0.7 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `{ c : 1 }`, near is much better | 1 | 0.81 | 0.64 | 0.49 | 0.25 | 0.09 | 0 |

For distance, that reads: right beside it is best, a few steps away is still good, and attraction fades quickly after that. Compare it with the falling line, where something halfway across the range is still worth half: the power curve says it's worth a quarter. Close things win more clearly.

And with `c` in the middle and a bigger `m`, a power curve becomes a **U**:

| x | 0 | 0.2 | 0.4 | 0.5 | 0.6 | 0.8 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `{ m : 4, c : 0.5 }` | 1 | 0.36 | 0.04 | 0 | 0.04 | 0.36 | 1 |

A U says: the extremes matter, the middle doesn't. Invert it, with `invert : true`, and you get an upside-down U, **best in the middle**: an archer that likes being at medium range, not too close and not too far.

---

## LOGISTIC: barely, then suddenly

```gml
gmsa_curve_make(gmsa_curve.LOGISTIC, { k : ..., c : ... })
```

```
y = m / (1 + e^(-k * (x - c))) + b
```

The S-curve. It stays low, rises fast around `c`, and levels off high. `c` is the middle of the rise, where the curve passes 0.5, and `k` is how steep the rise is: 10 by default. A negative `k` turns it around, so it starts high and falls.

| x | 0 | 0.1 | 0.2 | 0.3 | 0.4 | 0.5 | 0.6 | 0.7 | 1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Default, `k` 10, `c` 0.5 | 0.007 | 0.018 | 0.047 | 0.119 | 0.269 | 0.5 | 0.731 | 0.881 | 0.993 |
| `{ k : -15, c : 0.35 }` | 0.995 | 0.977 | 0.905 | 0.679 | 0.321 | 0.095 | 0.023 | 0.005 | 0 |

The second row is the shape this series has been promising: a goblin that **barely cares about its health until suddenly it cares about nothing else**. Above half health, drinking is close to nothing. Around 35%, it climbs through the middle fast. Below 20%, it's nearly at the top. That's how urgency feels, and it's the most useful single shape for anything that should become pressing past a point: health, ammo, hunger, a timer running out.

The logistic is the smooth cousin of a threshold. Where an if-statement says "below 35, drink", the S-curve says "around 35, drinking becomes important, and the farther below, the more". There's no cliff at 35 and 36: a goblin at 36 is only slightly less thirsty than one at 34, and the other considerations, like how far the potion is, still get their say.

One thing to know: **a logistic curve never quite reaches 0 or 1.** At the far ends it gets very close, 0.007 in the default's case, but not all the way. So a logistic consideration never fully vetoes an option, it just makes it very small. Usually that's what you want. When you do want a true 0 past some point, shift the curve down a hair with `b`, and the clamp turns the tail into a real 0:

| x | 0 | 0.2 | 0.3 | 0.4 | 0.5 | 0.6 | 0.8 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `{ k : -15, c : 0.3, b : -0.012 }` | 0.977 | 0.806 | 0.488 | 0.17 | 0.035 | 0 | 0 |

That's also the answer to Chapter 2's first exercise: ignore potions completely above 60% health, care a little at 50%, and switch to drinking at about 30%, against looting's steady 0.5. Three points no straight line passes through, one S-curve with a nudge.

---

## STEP: a hard rule

```gml
gmsa_curve_make(gmsa_curve.STEP, { c : ... })
```

```
y = (x >= c ? m : 0) + b
```

A step is 0 below the threshold `c` and 1 from `c` up. With `invert : true`, the other way around: 1 below, 0 from `c` up.

Steps are for **rules**, things that are simply true or false for an option: the goblin can't throw a bomb without one, a mage can't cast without mana, a door can't be opened while locked. Combined with multiplication, a step that's 0 vetoes the option, so it's the cleanest way to say "this is impossible right now":

```gml
// can only throw with at least one bomb: bombs is an input from 0 to 5
var _has_one = gmsa_curve_make(gmsa_curve.STEP, { c : 0.2 });  // 1 bomb of 5 is 0.2
gmsa_action_add_consideration(_throw, "bombs", _has_one);
```

Use them for rules, and only for rules. A step on something that should feel gradual brings back exactly the cliffs Chapter 1 complained about.

---

## CUSTOM: your own shape

When none of the shapes fits, write your own:

```gml
// best between 30% and 70%, fading outside
var _band = gmsa_curve_make(gmsa_curve.CUSTOM, { func : function(_x) {
    if (_x >= 0.3 && _x <= 0.7) return 1;
    return max(0, 1 - abs(_x - clamp(_x, 0.3, 0.7)) / 0.2);
} });
```

The function gets the input from 0 to 1 and returns the consideration, clamped like every other curve.

A custom curve can also be an **animation curve asset**. GameMaker has a curve editor built in: create an Animation Curve asset, draw the shape with the mouse, and hand it over:

```gml
var _drawn = gmsa_curve_make(gmsa_curve.CUSTOM, { animcurve : ac_goblin_fear, channel : 0 });
```

That's a natural fit when someone who isn't writing code wants to tune how an agent feels: they draw the shape, the game reads it, and nothing needs to be recompiled in their head as parameters.

---

## invert

Every type takes `invert : true`, which turns `y` into `1 - y` after everything else. It's often the clearest way to say what you mean:

- A rising S-curve says "the more of it, the more it matters". Inverted, it says "the less of it, the more it matters", without working out a negative `k`.
- A step says "only from here up". Inverted, "only below here".
- An upside-down U, from inverting the U shape, says "best in the middle".

Use whichever reads more naturally to you. `{ k : -15, c : 0.35 }` and `{ k : 15, c : 0.35, invert : true }` are the same curve.

---

## Choosing a curve

You don't choose a curve by its formula. You choose it by saying, in plain words, how the option feels about the input, and picking the shape that says the same thing:

| You'd describe it as | Shape | For example |
| --- | --- | --- |
| More is better, evenly | LINEAR, rising | Gold in a chest, compared proportionally |
| Less is better, evenly | LINEAR, falling | A rough "nearer is better" |
| Only a lot matters | POWER, `k` above 1 | The size of a crowd, the strength of a smell |
| A little goes a long way | POWER, `k` below 1 | The first coins, the first hint of being seen |
| Near is much better than far | POWER, `{ c : 1 }` | Distance to an item |
| Barely, then suddenly | LOGISTIC | Low health, low ammo, a deadline |
| The extremes matter | POWER, U shape | Too hot or too cold |
| Best in the middle | POWER U, inverted | An archer's preferred range |
| A hard rule | STEP | Has a key, has ammo, is the door open |
| None of these | CUSTOM | Whatever your game needs |

When you're unsure, start with the shape that matches the words, look at it with `draw_curve_box`, and run the game. Curves are cheap to change and easy to see, so tuning them is a matter of watching the agent and adjusting until its behavior reads the way you described it.

---

## Hard curves and soft curves

Chapter 2 showed that considerations multiply, and that a 0 vetoes the option. That gives every curve a second job beyond its shape: deciding whether it can **rule an option out**.

- A **hard** curve reaches 0 somewhere. Past that point, the option is impossible, whatever every other consideration says. The falling line, the step and the shifted logistic are hard.
- A **soft** curve never reaches 0. It can weaken an option but never forbid it. A line with a floor, `{ m : 0.8, b : 0.2 }`, and an unshifted logistic are soft.

Choose on purpose. **Rules get hard curves:** a goblin with no potion in reach really can't drink, so distance can be hard. **Matters of taste get soft curves:** a goblin that prefers near coins should still pick up a far coin when nothing else is going on, so if distance is only about preference, give it a floor.

It matters even more later in the series. Learning models, which come in the Advanced chapters, can reorder options but never bring back a vetoed one. A hard curve is a rule no amount of learning will overturn; a soft one leaves room for an agent to pick something up from the player. Getting into the habit now, of asking "is this a rule or a preference?" for every curve, pays off then.

---

## Curves or weights?

Both change how much an option scores, and it's easy to reach for the wrong one:

- **A weight** scales the whole option, in every situation equally. Use it when an option is generally more or less important: this goblin is greedier, so looting weighs 0.7 instead of 0.5.
- **A curve** changes how the option responds to one input. Use it when the option is right in some situations and wrong in others: the goblin should drink when hurt, not when healthy.

If an agent does the right *kind* of thing at the wrong *moment*, it's a curve. If it does the right thing at the right moments but too eagerly or too reluctantly against everything else, it's a weight.

---

## The goblin, with shapes

Time to give the goblin from Chapter 3 curves that say what we mean. Replace the curves in `__goblin_profile_build`:

```gml
// "barely, then suddenly": thirst rises fast below about 35% health
var _thirst = gmsa_curve_make(gmsa_curve.LOGISTIC, { k : -15, c : 0.35 });

// "near is much better than far"
var _near = gmsa_curve_make(gmsa_curve.POWER, { c : 1 });

// fear of the player: panic within about a third of the range
var _too_close = gmsa_curve_make(gmsa_curve.LOGISTIC, { k : -12, c : 0.3 });

// fear of being hurt: starts mattering below about 40% health
var _weak = gmsa_curve_make(gmsa_curve.LOGISTIC, { k : -10, c : 0.4 });

var _drink = gmsa_profile_add_action(_p, "drink", {
    targets : function(_agent) {
        var _potions = [];
        with (o_potion) array_push(_potions, id);
        return _potions;
    },
});
gmsa_action_add_consideration(_drink, "hp", _thirst);
gmsa_action_add_consideration(_drink, "potion_distance", _near);

var _flee = gmsa_profile_add_action(_p, "flee");
gmsa_action_add_consideration(_flee, "player_distance", _too_close);
gmsa_action_add_consideration(_flee, "hp", _weak);

gmsa_profile_add_action(_p, "loot", { weight : 0.5 });
```

A curve is just a struct describing a shape, and it's never changed after it's made, so one curve can be shared by as many considerations as you like. Naming curves after what they mean, `_thirst`, `_near`, `_too_close`, makes the profile read almost like the description of the goblin it is.

Show them while you play, the same way:

```gml
// o_goblin > Create (add)
view_thirst = gmsa_curve_make(gmsa_curve.LOGISTIC, { k : -15, c : 0.35 });
view_too_close = gmsa_curve_make(gmsa_curve.LOGISTIC, { k : -12, c : 0.3 });
```

```gml
// o_goblin > Draw GUI, replace the falling line's box
draw_curve_box(view_thirst, 400, 40, 160, 100, "drink: hp", hp / 100);
if (instance_exists(o_player)) {
    var _d = point_distance(x, y, o_player.x, o_player.y) / 400;
    draw_curve_box(view_too_close, 400, 180, 160, 100, "flee: player distance", _d);
}
```

Now play the goblin again and compare it with the straight-line one:

- **At 70% health,** the old goblin's health consideration for drinking was already 0.3. The new one's is about 0.005: it barely thinks about potions while healthy.
- **Around 35%,** the new goblin's thirst jumps. It goes from looting to drinking over a few points of health, not gradually across fifty.
- **A potion at the far side of the room** is worth much less than one nearby, so a hurt goblin with a potion close and another far goes for the close one with a clear margin, instead of a near tie.
- **The player at the edge of the range** barely registers. Within about 120 pixels, if the goblin is also hurt, fleeing takes over sharply.

The goblin's logic hasn't changed: the same inputs, the same actions, the same multiplication. What changed is how much each thing matters, and the goblin now behaves the way we'd describe it out loud.

---

## When a curve looks wrong

Most curve bugs come down to a handful of mistakes. When a consideration in the debug list isn't what you expected:

- **Rising when you meant falling.** The most common one. Check it with `gmsa_curve_eval(curve, 0)` and `gmsa_curve_eval(curve, 1)`: which end is high?
- **The interesting part is off the edge.** An S-curve centred at `c` 0.8 on an input whose values never go above 0.3 is stuck at its low tail. Check where the input's values actually fall, in the debug list or with the marker in `draw_curve_box`, and move `c` there, or fix the input's range.
- **A logistic that should veto doesn't.** Its tail never reaches 0. Shift it down with `b`.
- **A floor that isn't there.** A falling line reaches 0 at the top of the range and vetoes. If that wasn't meant to be a rule, give it a floor.
- **Too steep.** A logistic with `k` 50 is a step with extra steps. If the behavior flips too suddenly, lower `k`.

The fastest way to find any of these is to look: draw the curve, mark the current value, and watch the marker while you play.

---

## Try this

- **Make a cowardly goblin and a brave one** from one profile function, the way Chapter 2 made greedy and cautious ones. Give the cowardly one `_too_close` with `c` 0.5 and the brave one `c` 0.15. Bring the player in slowly and watch when each one breaks.
- **Give looting a reason.** Add a `"gold"` input, the goblin's own gold from 0 to 20, and a consideration on looting that says "a little goes a long way": a power curve with `k` 0.5, inverted, so the first coins matter most and a goblin with a full pouch is lazy about the next one.
- **Draw a fear curve.** Create an Animation Curve asset, draw a shape that's flat, then jumps, then flattens again, and use it for `_too_close` through `animcurve`. Tune it by dragging points in the curve editor while comparing the goblin's behavior.
- **Find a cliff.** Replace `_thirst` with a step at `c` 0.35, inverted, and play. The goblin is now a goblin with an if-statement. Put the logistic back and notice how much more natural the switch looks.

---

## What you've learned

- A curve maps a normalized input to how much an option cares, both from 0 to 1. Read it left to right: where does it change, how sharply, and where does it end?
- Every curve type shares the same parameters: `m` scales, `k` shapes, `b` shifts up and down, `c` shifts left and right, and `invert` flips the result. The output is always clamped to 0..1.
- **LINEAR** changes evenly. **POWER** starts slowly or quickly, and makes U shapes. **LOGISTIC** stays low, then rises fast around a point: the shape of urgency. **STEP** is a hard rule. **CUSTOM** is any function or a drawn animation curve.
- Choose a curve by describing in words how the option feels about the input, then picking the shape that says the same thing.
- **Hard** curves reach 0 and can veto. **Soft** curves never do. Rules get hard curves, preferences get soft ones.
- Weights scale an option everywhere. Curves change when it matters.
- `gmsa_curve_eval` evaluates a curve exactly as scoring does, and drawing curves while you play is the fastest way to tune them.

## What's next

[Chapter 5](Chapter5.md) is about targets: gathering the things an agent could act on, scoring each one, giving them readable names in the debug list, and keeping the list small enough that a room full of coins doesn't cost a room full of time.