# Chapter 9: Seeing Why

Every chapter so far has had the debug list on screen, and every chapter has leaned on it a little: a number to point at, a consideration to check. This chapter reads it properly. Utility AI has one real weakness, which Chapter 1 named: scores are invisible. An agent that does something odd for a reason you can't see feels like a black box, and tuning a black box is guessing. GMSmartAgent's answer is to show everything, and the skill this chapter teaches is turning what it shows into fixes.

By the end you'll be able to read every character of a debug line, rebuild any score by hand, inspect one goblin in a crowd, see the raw inputs behind the considerations, catch dithering as it happens, and change a profile while the game runs. Then three real tuning problems, each solved by looking rather than guessing.

---

## One goblin at a time

Since Chapter 8 there's a problem with the debug view: every goblin draws its own list in its Draw GUI event, all at the same spot on screen. With twenty goblins, that's twenty lists on top of each other. The fix is to draw only one, the goblin you're interested in, and let the controller do it.

Delete the debug drawing from the goblin's Draw GUI, and give the controller an **inspected** goblin, chosen with a right click:

```gml
// o_controller > Create (add)
global.inspected = noone;
```

```gml
// o_controller > Step (add)
if (mouse_check_button_pressed(mb_right)) {
    global.inspected = instance_nearest(mouse_x, mouse_y, o_goblin);
}
```

```gml
// o_controller > Draw (add)
if (instance_exists(global.inspected)) {
    draw_circle(global.inspected.x, global.inspected.y, 20, true);
}
```

```gml
// o_controller > Draw GUI (add)
if (instance_exists(global.inspected)) {
    gmsa_debug_draw(global.inspected.agent.decision, 10, 40, 10, goblin_namer);
}
```

The namer from Chapter 5 moves into a script of its own, so anything can use it:

```gml
/// Readable names for the goblin's targets.
function goblin_namer(_target) {
    if (_target == undefined) return "-";
    if (is_struct(_target)) return "point";
    if (!instance_exists(_target)) return "gone";
    if (_target.object_index == o_coin) return "coin (" + string(_target.value) + ")";
    return object_get_name(_target.object_index);
}
```

Right-click near any goblin and its list appears, with a circle around it in the room. One list, one goblin, and you always know which.

---

## Reading a line

Here's a line from a hurt goblin heading for a potion:

```
> 0.468  p1.00  drink @ o_potion  [hp 0.68, distance 0.44]
```

From left to right:

| Part | Meaning |
| --- | --- |
| `>` | This option was chosen. Every other line starts with two spaces |
| `0.468` | The option's final score: what it was ranked by |
| `p1.00` | The chance it was picked. With the default selection, 1 for the winner and 0 for the rest |
| `drink` | The action |
| `@ o_potion` | The target, named by your namer. Missing for targetless actions |
| `[hp 0.68, distance 0.44]` | Each consideration's value **after its curve**, in the order they were added |

Four more things can appear:

- **`(designer 0.512)`** after the target. That's the score your profile gave the option, shown only when something changed it afterwards. Nothing in the Basic chapters does; learning models, later in the series, can, and this is how you see by how much.
- **`... 6 more`** at the bottom, when there are more options than the list's limit. The fourth argument of `gmsa_debug_draw` is that limit.
- **`no selectable options`** as the only line: nothing could be chosen (Chapter 7).
- **Lines in red, starting with `!`.** These are consistency checks on the decision itself: a score that isn't a number, options out of order. Normal use never produces them. If you ever see one, it names the option and what's wrong, and it points at something broken, like a custom curve function returning garbage.

The most important thing in the line is the bracket. **Those are curve outputs, not inputs.** `hp 0.68` doesn't mean the goblin is at 68% health; it means the thirst curve, given the goblin's health, says drinking matters 0.68. To see the health itself, you need the inputs, which come shortly.

---

## Rebuilding a score by hand

Every score is arithmetic you can redo, and doing it once makes every list after that readable at a glance. Take the line above. The goblin is at 30 health, and the potion is 100 pixels away:

| Step | Value |
| --- | --- |
| `hp`: 30 of 100 is 0.3, through the thirst S-curve | 0.679 |
| `distance`: 100 of 300 is 0.333, through the near curve | 0.444 |
| Multiplied | 0.302 |
| Corrected for two considerations | 0.407 |
| Weight 1 | 0.407 |
| Commitment: this is what the goblin is already doing, times 1.15 | **0.468** |

The last row is the one that catches people out. If the option is the agent's **current** one, the same action on the same target, its listed score includes the commitment bonus from Chapter 6. Rebuild a score by hand, get 0.407, see 0.468 on screen, and you've found the goblin's current target. The 15% is also exactly the margin anything else has to beat to take over, so a chosen option's score tells you how secure it is.

The table also shows the order of the whole pipeline: curves, multiply, correct, weight, commitment, rank. The API Reference's [Scoring Pipeline](../ApiReference.md#scoring-pipeline) lists it in full.

---

## Seeing the inputs

When a consideration looks wrong, the next question is whether the curve is wrong or the input is. The debug list only shows curve outputs, so draw the inputs too. A profile lists its inputs, and each input knows its range, its source and, for a pull input, its function:

```gml
// o_controller > Draw GUI (add)
if (instance_exists(global.inspected)) {
    var _agent = global.inspected.agent;
    var _inputs = _agent.profile.inputs;
    var _y = 260;
    for (var _i = 0; _i < array_length(_inputs); _i++) {
        var _in = _inputs[_i];
        if (_in.per_target) continue;  // one value per target: shown in the list instead
        var _raw = (_in.source == gmsa_source.PUSH) ? _agent.push[_i] : _in.callback(_agent, undefined);
        draw_text(10, _y, _in.name + "   raw " + string_format(_raw, 0, 1) + "   normalized " + string_format(gmsa_input_normalize(_in, _raw), 0, 2));
        _y += 16;
    }
}
```

`gmsa_input_normalize` maps a raw value through an input's range exactly as scoring does. For the hurt goblin:

```
hp   raw 30.0   normalized 0.30
player_distance   raw 400.0   normalized 1.00
```

Now the picture is complete: health is 30, which normalizes to 0.3, which the thirst curve turns into 0.68. If the goblin seemed oblivious to its injuries, you'd now know whether the problem was the input (reading the wrong variable, a range that's too wide) or the curve (in the wrong place). Per-target inputs are skipped here because they have a value per target; for those, the bracket in each line already shows the curve output for that target.

Calling pull functions from Draw GUI is fine for a debug panel. It's an extra call per input per frame, for one goblin, and it never affects the agent's decisions.

---

## The margin

Reading only the winning line misses half of what the list is telling you. Look at the gap between the first and second lines:

```
> 0.468  p1.00  drink @ o_potion  [hp 0.68, distance 0.44]
  0.465  p0.00  loot @ coin (1)  [distance 0.64, coin_value 0.50, player_to_target 1.00]
```

Drinking wins by 0.003, and only because of commitment: without the 15% bonus it would be 0.407 and looting would win. That's a goblin on a knife's edge. It's not wrong, but it means two things:

- **Small changes flip it.** One step closer to the coin, one point of health, and the decision changes. If you're tuning and a tiny adjustment makes a big difference, a narrow margin is why.
- **Commitment is doing the work.** If you see goblins turning between two things despite commitment, look for margins this close: the two options cross back and forth over the 15%.

Wide margins mean confident decisions that tuning won't easily disturb. Narrow ones are where behavior is decided, and where tuning has the most effect.

---

## Catching dithering

Dithering, turning back and forth between two choices, is the most visible failure there is, and it's hard to spot by watching a crowd. Count it instead. Each time the goblin's choice changes, note the time:

```gml
// o_goblin > Create (add)
switches = [];
```

```gml
// o_goblin > Step, in part 2, where a fresh decision is acted on, before doing and goal change
if (_chosen != undefined && (_chosen.action.name != doing || _chosen.target != goal)) {
    array_push(switches, current_time);
}
while (array_length(switches) > 0 && current_time - switches[0] > 3000) array_delete(switches, 0, 1);
```

`switches` holds the times of the changes in the last three seconds. A goblin that picks a coin, walks to it and picks another changes its mind about once per coin. A dithering goblin changes three, five, ten times in three seconds. Show it for the inspected goblin, or, better, tint every goblin by it:

```gml
// o_goblin > Draw (add)
if (array_length(switches) >= 4) {
    draw_set_colour(c_red);
    draw_circle(x, y, 14, true);
    draw_set_colour(c_white);
}
```

Now a red ring marks any goblin that changed its mind four or more times in three seconds. Right-click it and read its list: the margin will be thin, and the two options trading places will tell you exactly which choice it can't make.

---

## Changing a profile while the game runs

Profiles are locked once built, and that's what makes them safe to share. But tuning means trying values, and restarting the game for every try is slow. The way around it is to build profiles from a struct of tuning values, and rebuild on a key press.

Start by giving the goblin's profile a home you can replace, instead of Chapter 2's `static`:

```gml
// Goblin_Profile, replace goblin_profile
function goblin_profile() {
    if (!variable_global_exists("goblin_profile_built")) global.goblin_profile_built = __goblin_profile_build();
    return global.goblin_profile_built;
}
```

Then put the numbers you're tuning in a struct, and read them in the build:

```gml
// o_controller > Create (add)
global.tune = {
    watch_weight : 0.15,
    flee_c       : 0.3,
};
```

```gml
// __goblin_profile_build, wherever these numbers appear
var _too_close = gmsa_curve_make(gmsa_curve.LOGISTIC, { k : -12, c : global.tune.flee_c });
var _watch = gmsa_profile_add_action(_p, "watch", { weight : global.tune.watch_weight, targets : ... });
```

And rebuild on demand. Agents keep the profile they were made with, so each goblin gets a fresh agent:

```gml
function goblin_profile_rebuild() {
    global.goblin_profile_built = __goblin_profile_build();
    with (o_goblin) {
        gmsa_scheduler_remove(global.ai, agent);
        agent = gmsa_agent_create(goblin_profile(), id, { interval : 100000 });
        gmsa_scheduler_add(global.ai, agent);
        doing = "nothing";
        goal = noone;
    }
}
```

```gml
// o_controller > Step (add)
if (keyboard_check_pressed(ord("1"))) { global.tune.watch_weight -= 0.01; goblin_profile_rebuild(); }
if (keyboard_check_pressed(ord("2"))) { global.tune.watch_weight += 0.01; goblin_profile_rebuild(); }
if (keyboard_check_pressed(ord("3"))) { global.tune.flee_c -= 0.05; goblin_profile_rebuild(); }
if (keyboard_check_pressed(ord("4"))) { global.tune.flee_c += 0.05; goblin_profile_rebuild(); }
```

Show the current values on screen with the rest of the overlay, and you can nudge a weight, watch the goblins respond, and nudge again, without ever stopping the game. When it feels right, copy the numbers into the profile as plain values and remove the tuning struct, or keep it for the next round.

---

## Tuning by looking: three problems

Everything above comes together in a routine: **see the wrong behavior, inspect the goblin, find the option that should have won, find the consideration dragging it down, and decide whether to fix the input, the curve or the weight.** Chapter 4's rule decides the last part: if the agent does the right kind of thing at the wrong moment, it's a curve or an input; if it does the right things but too eagerly or too reluctantly against everything else, it's a weight.

### "It ignores the potion when it's badly hurt"

The goblin is at 25 health. A potion sits 250 pixels away, a 1-coin 60 pixels away. The goblin walks to the coin. Right-click it:

```
> 0.465  p1.00  loot @ coin (1)  [distance 0.64, coin_value 0.50, player_to_target 1.00]
  0.034  p0.00  drink @ o_potion  [hp 0.82, distance 0.03]
```

Drinking's thirst is 0.82: the goblin knows it's hurt. The culprit is the other value: `distance 0.03`. The near curve, `(1 - x)²`, was chosen for coins, where "near is much better than far" is exactly right. For a potion when you're dying, 250 pixels is not much of a reason to stay thirsty. The input is fine and shared; the **curve** is wrong for this action.

Fix: the same `"distance"` input, a gentler curve for drinking only.

```gml
var _reachable = gmsa_curve_make(gmsa_curve.LINEAR, { m : -0.6, b : 1 });  // far is less good, never hopeless
gmsa_action_add_consideration(_drink, "distance", _reachable);
```

At 250 pixels that's 0.5 instead of 0.03, and drinking scores 0.53 against looting's 0.465. The hurt goblin goes for the potion, and at full health, where thirst is near 0, the gentler curve changes nothing. An input can feed different curves in different actions; that's what considerations are for.

### "It only flees when the player is right on top of it"

The goblin is at 20 health, the player 150 pixels away, a coin nearby. The goblin keeps looting until the player is almost touching it:

```
> 0.465  p1.00  loot @ coin (1)  [...]
  0.349  p0.00  flee  [player_distance 0.29, hp 0.88]
```

The goblin knows it's weak, `hp 0.88`. The player's distance is what's low: at 150 pixels, the fear curve only says 0.29. Check the input with the inputs panel: `player_distance raw 150.0, normalized 0.38`. The input is right. The fear curve's middle, `c` 0.3, is at 120 pixels, so 150 is still on its low side. The **curve is in the wrong place**.

Fix: move the middle out. With the tuning keys, press 4 three times to take `flee_c` from 0.3 to 0.45, 180 pixels. Now 150 pixels reads 0.71, fleeing scores 0.743, and the goblin runs while the player is still a few steps away. Because it's an S-curve, a healthy goblin still doesn't care: the `hp` consideration keeps fleeing near 0 until the goblin is hurt.

### "It would rather stare at the player than pick up coins"

With the player standing around 150 pixels away, goblins stand watching even with 1-coins lying 200 pixels off:

```
> 0.150  p1.00  watch @ o_player  [distance 1.00]
  0.091  p0.00  loot @ coin (1)  [distance 0.11, coin_value 0.50, player_to_target 1.00]
```

Nothing here is happening at the wrong moment. Watching is correctly at its best at 150 pixels, and the coin is correctly modest. The problem is that watching is too attractive **overall**: it's the right behavior with the wrong importance. That's a **weight**.

Fix: press 1 a few times, lowering `watch_weight` to 0.08. Watching now scores 0.08 at its best, the coin wins at 0.091, and the goblins go about their business while still keeping an eye on the player when there's truly nothing else to do.

Each of the three fixes touched one number, and each one was found by reading two lines.

---

## Text for the log

Sometimes you want a decision in the output window rather than on screen: to compare two moments, or to paste into a bug report. `gmsa_debug_explain` returns the same lines as one string:

```gml
// o_controller > Step (add)
if (keyboard_check_pressed(ord("L")) && instance_exists(global.inspected)) {
    show_debug_message(gmsa_debug_explain(global.inspected.agent.decision, 20, goblin_namer));
}
```

And `gmsa_debug_lines` returns them as an array, for drawing them your own way, in a panel, above the goblin's head, or into a file. Chapter 7's `gmsa_agent_evaluate` works with all three, for when the question is about the options that were vetoed.

---

## Try this

- **Rebuild a score.** Inspect a goblin heading for a coin, note its distance, the coin's value and the player's distance, and rebuild the score by hand. Check whether commitment is in the number.
- **Make a goblin dither.** Set commitment to 0, put two equal coins at the same distance, and watch for the red ring. Then find the two lines trading places in its list.
- **A fourth problem.** Make goblins flee from a healthy-looking player too readily by lowering `_weak`'s `c`, then diagnose it from the list as if you didn't know what you changed.
- **A tuning panel.** Show `global.tune`'s values on screen next to the inspected goblin's list, and add keys for the thirst curve's `c`.

---

## What you've learned

- Inspect one agent at a time: select it, circle it, and draw only its list.
- Every line shows the choice marker, final score, chance, action, target and each consideration **after its curve**. `(designer ...)`, `... more`, `no selectable options` and red `!` checks complete the picture.
- A score rebuilds by hand: curves, multiply, correct for the number of considerations, weight, then commitment for the current option. A score 15% above your arithmetic is the agent's current choice.
- The inputs panel shows raw and normalized inputs, so you can tell a wrong input from a wrong curve.
- The **margin** between the top two lines shows how secure a decision is, and where tuning will bite.
- Counting changes of mind catches **dithering** in a crowd.
- Building profiles from a tuning struct and rebuilding on a key lets you tune while the game runs.
- The routine: see it, inspect it, find the option that should have won, find the consideration dragging it down, then fix the input, the curve or the weight.

## What's next

[Chapter 10](Chapter10.md) locks the tuning in. Once the goblin behaves the way you want, a later change to a weight or a curve can quietly break it, and nobody notices until a playtest. Tests catch that: small checks that set up a situation and confirm the goblin still makes the right choice, run in a second, every time you change anything.