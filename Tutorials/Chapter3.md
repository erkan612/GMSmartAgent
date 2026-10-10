# Chapter 3: What the Agent Knows

An agent decides only from what it knows, and everything it knows reaches it as an **input**. If the goblin has no input for the player's distance, the player might as well not exist; if it has no input for how far each potion is, every potion looks the same. Designing inputs is designing what your agent perceives, and most of the difference between an agent that feels sharp and one that feels oblivious is decided here, before a single curve is drawn.

This chapter covers what an input really is, how to choose its range so that 0 to 1 means something, the two ways an agent gets an input's value, inputs that are different for every target, and the inputs an agent *shouldn't* have. By the end the goblin knows its health without being told every step, notices the player, picks the nearest potion, and flees when it's hurt and the player is close.

---

## What an input is

An input has three things: a **name**, a **range** and a **value**.

- The **name** is how considerations refer to it: `"hp"`, `"player_distance"`.
- The **range** is a minimum and a maximum, in whatever units the value naturally has: health points, pixels, seconds, coins.
- The **value** is what it is right now.

Before a value reaches a curve, GMSmartAgent **normalizes** it: it maps the range onto 0..1. The minimum becomes 0, the maximum becomes 1, and everything in between falls proportionally. Values outside the range are **clamped**: anything below the minimum counts as 0, anything above the maximum as 1.

| Input | Range | Raw value | Normalized |
| --- | --- | --- | --- |
| Health | 0 to 100 | 35 | 0.35 |
| Distance to the player | 0 to 400 px | 100 | 0.25 |
| Distance to the player | 0 to 400 px | 900 | 1 (clamped) |
| Gold carried | 0 to 50 | 12 | 0.24 |
| Seconds since the player was seen | 0 to 5 | 2.5 | 0.5 |
| Is the alarm on? | 0 to 1 | true | 1 |

Normalizing is what makes every input interchangeable. A curve doesn't know or care whether it's looking at health, pixels or seconds; it sees a number from 0 to 1. That's why one curve, like the falling straight line from Chapter 2, can serve health and distance alike, and why you can swap the input behind a consideration without touching anything else.

---

## Choosing a range

A range isn't bookkeeping. It's a statement about **what counts as a lot**. When you write a distance input with a range of 0 to 400 pixels, you're saying: at 400 pixels and beyond, this thing is as far as it gets; I don't care about the difference between 400 and 4000.

Get the range wrong and the agent can't tell apart the situations you care about. Here's the same set of distances under two ranges:

| Distance | Range 0 to 300 | Range 0 to 2000 |
| --- | --- | --- |
| 20 px, right beside it | 0.07 | 0.01 |
| 100 px, a few steps | 0.33 | 0.05 |
| 250 px, across the room | 0.83 | 0.13 |
| 600 px, out of sight | 1 | 0.30 |

With 0 to 2000, everything inside a normal room lands between 0 and 0.13. "Right beside it" and "across the room" are nearly the same number, and any curve you put on top has to work with a sliver of its range. With 0 to 300, the room spreads across the whole of 0 to 1, and everything beyond the room is simply "far".

A few rules of thumb:

- **Cover where the decision changes, and not much more.** If a goblin stops caring about a coin beyond about 300 pixels, 300 is the top of the range. The interesting part of the input should use most of 0 to 1.
- **Let clamping do work for you.** Values beyond the range all count the same, and that's usually right. A potion 5000 pixels away is no more out of reach than one 600 pixels away.
- **Prefer ratios for things with different maximums.** If goblins have different maximum health, "health out of 100" is wrong for a goblin with 40 max. Give the input `hp / hp_max` with a range of 0 to 1 instead, and "half health" means the same for every goblin.
- **The range is part of the design.** Changing it changes behavior as surely as changing a curve. Pick it on purpose, and when a goblin "doesn't notice" something, check the range before the curve.

---

## Push inputs

Chapter 2's health input was a **push** input:

```gml
gmsa_profile_add_input(_p, gmsa_input_push("hp", 0, 100, 100));
```

and the goblin pushed its health into the agent every step:

```gml
gmsa_agent_set_input(agent, "hp", hp);
```

A push input holds whatever you last set. The agent never asks for it; it just uses the value it has when it thinks. The fourth argument, `100`, is the **default**: the value before you've ever set it.

Push inputs suit values your game already knows at a particular moment:

- **Things that happen as events.** An alarm goes off, the goblin takes a hit, a door opens. You set the input when it happens, and it stays set until something changes it.
- **Values computed once and shared.** If your game works out the danger level of a room once per step for its own reasons, push that number into every goblin in the room rather than computing it again inside each agent.
- **Values from somewhere the agent can't reach,** like a network message or a dialogue system's state.

The risk with push inputs is the obvious one: if you forget to set one, it keeps its old value. A goblin whose `"hp"` input was set once at 100 and never again will happily keep looting at 5 health. That's not a bug in the agent; it's acting on what it was told.

---

## Pull inputs

A **pull** input is one the agent reads for itself, by calling a function of yours whenever it thinks:

```gml
gmsa_profile_add_input(_p, gmsa_input_pull("hp", function(_agent, _target) {
    return _agent.owner.hp;
}, 0, 100));
```

The function is called with the agent, and `_agent.owner` is the instance the agent belongs to, the `id` you passed to `gmsa_agent_create` in Chapter 2. So this input reads the goblin's own `hp` variable, fresh, every time the goblin thinks. There's nothing to set in the Step event any more, and nothing to forget.

Three things to know about how pull inputs are read:

- **Only when the agent thinks.** Between thinks the function isn't called. An agent that thinks every ten steps reads its pull inputs every ten steps.
- **Once per think.** If drinking and fleeing both consider `"hp"`, the function runs once, and both use the same value.
- **Bad values become 0.** If the function returns `undefined`, a string or `NaN`, GMSmartAgent treats the value as 0 rather than crashing. That keeps a game running, but it can also hide a mistake: a goblin that never drinks may be reading an input that always comes back as 0. If a consideration in the debug list is stuck at the same value whatever happens, check the function behind its input first.

### Push or pull?

| | Push | Pull |
| --- | --- | --- |
| Who provides the value | You, with `gmsa_agent_set_input` | The agent, by calling your function |
| When it's up to date | When you last set it | Every think |
| Good for | Events, shared values, values from other systems | Anything the agent can read from its owner or the world |
| Cost | Whatever it costs you to set it | Your function, once per think |
| Typical mistake | Forgetting to set it | A function that's slow, or quietly returns nothing |

Most inputs in most games end up as pull inputs, because most of what an agent needs to know can be read from its owner or the room at the moment it thinks. Reach for push when the value comes from an event or from somewhere else entirely.

---

## Knowing about the world

Inputs don't have to be about the agent itself. Anything your game can measure can be an input, and pull functions are where you measure it. Add a player to the room, an object `o_player` with any sprite that follows the mouse:

```gml
// o_player > Step
x = mouse_x;
y = mouse_y;
```

The goblin can now know how far away the player is:

```gml
gmsa_profile_add_input(_p, gmsa_input_pull("player_distance", function(_agent, _target) {
    if (!instance_exists(o_player)) return 400;  // no player: as far as it gets
    var _o = _agent.owner;
    return point_distance(_o.x, _o.y, o_player.x, o_player.y);
}, 0, 400));
```

With that, the goblin can be afraid. A **flee** action that matters when the player is near *and* the goblin is hurt is two considerations, multiplied:

```gml
var _falling = gmsa_curve_make(gmsa_curve.LINEAR, { m : -1, b : 1 });  // 1 at the bottom of the range, 0 at the top

var _flee = gmsa_profile_add_action(_p, "flee");
gmsa_action_add_consideration(_flee, "player_distance", _falling);  // the closer the player, the more it matters
gmsa_action_add_consideration(_flee, "hp", _falling);               // the more hurt, the more it matters
```

The same falling line serves both: near the player is high, far is low; low health is high, full health is low. A healthy goblin with the player right next to it scores fleeing at 0, because the health consideration vetoes it. A badly hurt goblin with the player across the map scores it low, because the distance consideration pulls it down. Only both together make it run.

Notice that `"hp"` is now used by two actions, drinking and fleeing. It's still one input, read once per think.

---

## Inputs that differ for every target

So far every input has had one value per think: the goblin has one health, the player is at one distance. But some things are different for each thing the agent could choose. Each potion is a different distance away. "How far is the potion?" has no single answer until you say *which* potion.

That's a **per-target** input. Its function receives the target being scored as its second argument, and it's called once for each target:

```gml
gmsa_profile_add_input(_p, gmsa_input_pull("potion_distance", function(_agent, _potion) {
    var _o = _agent.owner;
    return point_distance(_o.x, _o.y, _potion.x, _potion.y);
}, 0, 300, true));  // true: per target
```

For it to have targets, the action needs to say what its targets are. An action's `targets` function returns an array of them, and the action then produces **one option per target**, each scored separately:

```gml
var _drink = gmsa_profile_add_action(_p, "drink", {
    targets : function(_agent) {
        var _potions = [];
        with (o_potion) array_push(_potions, id);
        return _potions;
    },
});
gmsa_action_add_consideration(_drink, "hp", _falling);
gmsa_action_add_consideration(_drink, "potion_distance", _falling);
```

With three potions in the room there are three drinking options, each with the same `"hp"` value and its own `"potion_distance"`. The nearest potion scores highest, so the goblin heads for the nearest one, and if you place another potion closer, the goblin's choice moves to it. With no potions in the room there are no drinking options at all, and the goblin simply doesn't consider drinking.

Targets get a whole chapter of their own, Chapter 5: how to gather them, how to keep the list small, and what to do when the best target and the best action aren't the same question. Here, it's enough to see the difference between the two kinds of input:

| | Situational | Per target |
| --- | --- | --- |
| Example | My health, the player's distance, the time of day | Distance to this potion, gold in this chest |
| One value per | Think | Target, per think |
| Function receives | The agent, `undefined` as the target | The agent and the target |
| Last argument of `gmsa_input_pull` | `false`, the default | `true` |
| Can be used by | Any action | Only actions with `targets` |

That last row is checked when the profile is built. Give the per-target `"potion_distance"` to an action without targets, like looting, and the build throws a `GMSA:` error naming the action and the input, because there would be no target to measure the distance to.

---

## The whole profile

Here is the goblin's profile with everything from this chapter. Replace `__goblin_profile_build` in your `Goblin_Profile` script:

```gml
function __goblin_profile_build() {
    var _p = gmsa_profile_create("goblin");

    // what the goblin knows
    gmsa_profile_add_input(_p, gmsa_input_pull("hp", function(_agent, _target) {
        return _agent.owner.hp;
    }, 0, 100));

    gmsa_profile_add_input(_p, gmsa_input_pull("player_distance", function(_agent, _target) {
        if (!instance_exists(o_player)) return 400;
        var _o = _agent.owner;
        return point_distance(_o.x, _o.y, o_player.x, o_player.y);
    }, 0, 400));

    gmsa_profile_add_input(_p, gmsa_input_pull("potion_distance", function(_agent, _potion) {
        var _o = _agent.owner;
        return point_distance(_o.x, _o.y, _potion.x, _potion.y);
    }, 0, 300, true));

    var _falling = gmsa_curve_make(gmsa_curve.LINEAR, { m : -1, b : 1 });

    // drink the nearest potion when hurt
    var _drink = gmsa_profile_add_action(_p, "drink", {
        targets : function(_agent) {
            var _potions = [];
            with (o_potion) array_push(_potions, id);
            return _potions;
        },
    });
    gmsa_action_add_consideration(_drink, "hp", _falling);
    gmsa_action_add_consideration(_drink, "potion_distance", _falling);

    // flee when hurt and the player is close
    var _flee = gmsa_profile_add_action(_p, "flee");
    gmsa_action_add_consideration(_flee, "player_distance", _falling);
    gmsa_action_add_consideration(_flee, "hp", _falling);

    // loot otherwise
    gmsa_profile_add_action(_p, "loot", { weight : 0.5 });

    return gmsa_profile_build(_p);
}
```

And the goblin's Step event no longer pushes anything:

```gml
// o_goblin > Step
if (keyboard_check_pressed(vk_down)) hp = max(0, hp - 10);
if (keyboard_check_pressed(vk_up))   hp = min(100, hp + 10);

var _decision = gmsa_agent_think(agent);
var _chosen = gmsa_decision_get_chosen(_decision);
doing = (_chosen == undefined) ? "nothing" : _chosen.action.name;
```

Create an object `o_potion` with any sprite and place three of them around the room at different distances from the goblin.

---

## Reading the scores

Run it, press down until the goblin is at 30 health, and move the mouse so the player is about 100 pixels from the goblin, with the nearest potion about 60 pixels away. The debug list shows something like:

```
> 0.683  p1.00  drink @ 100004  [hp 0.70, potion_distance 0.80]
  0.650  p0.00  flee  [player_distance 0.75, hp 0.70]
  0.500  p0.00  loot
  0.480  p0.00  drink @ 100005  [hp 0.70, potion_distance 0.52]
  ...
```

The `@ 100004` is the potion's instance id; Chapter 5 shows how to give targets readable names. Look at how drinking's score is made:

| Step | Value |
| --- | --- |
| `hp`: 30 of 100 is 0.3, through the falling line | 0.70 |
| `potion_distance`: 60 of 300 is 0.2, through the falling line | 0.80 |
| Multiplied | 0.56 |
| Corrected for two considerations | 0.683 |

The correction from Chapter 2 is visible here. Two considerations of 0.7 and 0.8 multiply to 0.56, which would make drinking look worse than it is just for having two considerations. The correction lifts it to 0.683, in proportion to how many considerations there are and how much room is left above the score. Fleeing gets the same treatment: 0.75 times 0.7 is 0.525, corrected to 0.650.

Now play with it:

- **Move the player right up to the goblin.** `player_distance` climbs toward 1, fleeing overtakes drinking, and the label changes.
- **Move the player away.** Fleeing sinks, and the goblin goes back to the potion.
- **Press up to heal the goblin.** Both drinking and fleeing fall together, because both consider health, and looting takes over at full health.
- **Watch the second drinking option.** The farther potion is always scored, and always lower, here even below looting. If the nearest potion were removed, it would simply move up.

None of those changes was written as a rule. Every one of them is the same three inputs, measured fresh each think, meeting the same curves.

---

## Inputs the agent shouldn't have

It's tempting to give an agent everything, because everything is easy to measure. But Chapter 1's list of qualities included **fair**: an agent should act on what it could plausibly know. `"player_distance"` as written above reads the player's position through walls, from across the map, at all times. A goblin that flees from a player it can't possibly see feels like it's cheating, even if the player can't say exactly why.

The fix isn't in the agent; it's in the input. Measure what the goblin could actually perceive, and let the goblin remember what it saw:

```gml
// o_goblin > Create (add)
last_seen = -1000000;   // a long time ago
seen_x = x;
seen_y = y;
```

```gml
// o_goblin > Step (add, before thinking)
if (instance_exists(o_player)
    && point_distance(x, y, o_player.x, o_player.y) < 200
    && !collision_line(x, y, o_player.x, o_player.y, o_wall, false, true)) {  // o_wall: whatever blocks sight in your game
    last_seen = current_time;
    seen_x = o_player.x;
    seen_y = o_player.y;
}
```

```gml
// inputs the goblin can honestly have
gmsa_profile_add_input(_p, gmsa_input_pull("since_seen", function(_agent, _target) {
    return (current_time - _agent.owner.last_seen) / 1000;  // seconds
}, 0, 5));

gmsa_profile_add_input(_p, gmsa_input_pull("seen_distance", function(_agent, _target) {
    var _o = _agent.owner;
    return point_distance(_o.x, _o.y, _o.seen_x, _o.seen_y);
}, 0, 400));
```

Now the goblin knows *where it last saw the player* and *how long ago*. A flee action that considers both runs from where the player was, and calms down as the memory fades. When the player slips out of sight, the goblin doesn't instantly forget them, and doesn't magically track them either: it acts on a memory, the way a person would. Players read that as awareness.

The general rule: **an input is a sense.** Before adding one, ask whether the agent could plausibly know it. If not, give it a way to find out, through sight, sound or memory, and make that the input instead.

---

## Bools, kinds and derived values

Not everything is a distance or a health bar. A few patterns cover most of the rest.

**Yes or no.** A yes-or-no fact works as an input with a range of 0 to 1: return 1 for yes and 0 for no.

```gml
gmsa_profile_add_input(_p, gmsa_input_pull("alarm", function(_agent, _target) {
    return global.alarm_on ? 1 : 0;
}, 0, 1));
```

Used with a curve that passes 1 through and turns 0 into 0, it becomes a gate: the option is only possible while the alarm is on.

**Kinds.** Say coins come in gold, silver and copper, stored as `kind` 0, 1 and 2. It's tempting to make one input with a range of 0 to 2. Don't: a curve would then treat copper as "more" than silver and silver as "more" than gold, as if kinds were amounts. Instead, give each kind its own yes-or-no input:

```gml
gmsa_profile_add_input(_p, gmsa_input_pull("is_gold", function(_agent, _coin) {
    return (_coin.kind == 0) ? 1 : 0;
}, 0, 1, true));
```

and one each for silver and copper. Now each kind can matter independently, and a later chapter's learning models can tell them apart.

**Derived values.** An input's function can compute anything. Some of the most useful inputs are comparisons rather than raw measurements:

- **Ratios:** `hp / hp_max`, so half health means the same for every goblin.
- **Relative strength:** the goblin's attack against the player's health, so "can I win this fight?" is one number.
- **Counts:** how many other goblins are within 150 pixels, so a goblin can be braver in a crowd.
- **Time:** seconds since something happened, so feelings fade.

The cost of an input's function is paid once per think, or once per target per think. A distance is nothing. A `collision_line` is a little more. A path search or a loop over every instance in the room is real work, and fifty goblins doing it every few steps adds up. Keep pull functions cheap, and when something is expensive, compute it once somewhere else and push it.

---

## Try this

- **Change `potion_distance`'s range to 0 to 2000.** Every potion in the room now scores nearly the same, and the goblin stops caring which one is nearest. Change it back.
- **Make a goblin that's braver in a crowd.** Add a `"friends_near"` input that counts other goblins within 150 pixels, with a range of 0 to 4, and give fleeing a consideration that falls as friends rise. Place a few goblins together and one alone, hurt them all, and bring the player close.
- **Break an input on purpose.** Change the `"hp"` function to return `_agent.owner.hit_points` (a variable that doesn't exist). The game errors when the goblin thinks. Now make it return `undefined` instead: the goblin no longer crashes, `hp` shows as a constant in the debug list, and drinking and fleeing behave as if the goblin were at 0 health. That's the quiet failure to watch for.
- **Turn fleeing honest.** Replace `"player_distance"` in fleeing with `"seen_distance"` and add `"since_seen"` with the falling line, so the fear fades over five seconds after the player is last seen.

---

## What you've learned

- An **input** has a name, a range and a value. Values are **normalized** to 0..1 and **clamped** at the ends, so any input can feed any curve.
- A **range** says what counts as a lot. It should cover where the decision changes, so the interesting values use most of 0 to 1. Ratios beat raw values when maximums differ.
- **Push** inputs hold what you set, and suit events and shared values. **Pull** inputs call your function every think, and suit anything the agent can read from its owner or the world. Pull functions run once per think, and a bad return value quietly becomes 0.
- **Per-target** inputs have a value for every target, need an action with `targets`, and are checked for that when the profile is built.
- An input is a **sense**. An agent that knows things it couldn't plausibly know feels like it's cheating; give it sight and memory instead.
- Bools are 0 and 1, kinds become one yes-or-no input each, and some of the best inputs are derived: ratios, comparisons, counts and time.

## What's next

[Chapter 4](Chapter4.md) is about curves: the shapes that turn an input into how much it matters, how to read one, how to choose one, and how to make a goblin that barely cares about its health until suddenly it cares about nothing else.