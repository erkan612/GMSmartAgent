# Chapter 7: When Nothing Is Worth Doing

Clear the room of coins and potions, keep the goblin at full health, and watch the goblin from Chapter 6. Two strange things can happen.

With the player somewhere in the room, even far away, the goblin slowly backs away from them. It isn't hurt and the player isn't close, so why is it fleeing? Look at the debug list: fleeing shows `0.000`. Its real score is about 0.000001, too small for three decimals. Its two S-curves never quite reach 0, so a far player and full health make it tiny, but not nothing, and a tiny score is still the best score on offer. With nothing else to choose, the goblin picks it.

Take the player out of the room, and the goblin stops dead instead. Fleeing has nobody to run from, so it does nothing, and there's nothing else. The goblin doesn't twitch, doesn't look around, doesn't wander. It stands in the middle of the room until something changes.

Neither is a bug. Both are GMSmartAgent telling the truth: nothing the goblin knows how to do is really worth doing, and it either picks the least bad of a set of near-zero options or, when even those are gone, nothing at all. But both are the wrong look. Players read a motionless character as switched off, and nothing breaks the feeling of a living world faster. This chapter is about that moment: why it happens, how to see it, and how to give an agent something sensible to do when nothing is worth doing, from wandering, to idling, to waiting for its moment.

---

## Why an agent stops

An agent has nothing to do when its decision has no options left to choose from. Every way that can happen comes from earlier chapters:

- **Every option was vetoed.** One of its considerations was exactly 0, and multiplication made the whole score 0 (Chapter 2). A goblin at full health with a hard thirst curve doesn't consider drinking at all.
- **There were no targets.** An action whose targets function found nothing produces no options (Chapter 5). No coins in range, no looting.
- **The action was skipped.** A targets function returned `undefined`, switching the action off for this think.
- **Every action was cooling down** (Chapter 6).

When that happens, `gmsa_decision_get_chosen` returns `undefined`, and the debug list shows a single line:

```
no selectable options
```

The engine never invents behavior you didn't define. It won't pick the "least bad" vetoed option, because a vetoed option isn't a bad option, it's a forbidden one: drinking without a potion, looting with no coin. Picking it anyway would be choosing something you said was impossible. So the honest answer is: nothing.

The fix is never to make the engine choose something it shouldn't. It's to give the agent something it *should* do when there's nothing else.

---

## Idle is a behavior

In a lot of games, more of each character's time is spent with nothing urgent to do than doing anything exciting. Guards spend most of their lives guarding, villagers spend most of theirs milling around, enemies spend most of the level waiting for the player to arrive. Those quiet moments are what players see most, and they're where a world feels alive or doesn't.

So treat "nothing to do" as a design question: **what does this character do when nothing is going on?** A goblin might wander, poke around the room, sit and scratch, keep an eye on the player from a safe distance, or go back to its hiding place. Each of those is an action, scored like any other, and the trick is to make them win exactly when nothing better is on offer.

---

## The fallback action

The simplest answer is an action that's always possible and always weak: no considerations, or only soft ones, so it can never be vetoed, and a small weight, so anything real beats it.

Chapter 2 already used this idea: looting with no considerations and a weight of 0.5 was a baseline that drinking had to beat. A fallback is the same idea taken to the bottom of the scale:

```gml
gmsa_profile_add_action(_p, "idle", { weight : 0.02 });
```

`idle` scores 0.02, every think, whatever's going on. When a coin is in range and the goblin wants it, looting scores far more and wins. When nothing else is possible, `idle` is the only option left, and it wins. The goblin is never without a decision again.

What the goblin *does* while idle is your game's business, like every action: an idle animation, a little shuffle, a look around. GMSmartAgent's job ends at deciding that idling is what's called for.

---

## A fallback weight is a threshold

A fallback has a second effect that's easy to miss, and it's worth using on purpose. Because it scores its weight every time, **any option that scores below the fallback's weight can never win.** A wander at 0.05 means a coin whose score has sunk to 0.04, far, small and near the player, is simply never worth going for: the goblin wanders instead.

That turns the fallback's weight into a bar: **how good does something have to be to be worth doing at all?**

- **Very low, like 0.01:** the goblin will go for almost anything rather than idle. A hard-working, never-resting goblin.
- **Higher, like 0.15:** the goblin only bothers with things that are clearly worth it, and spends the rest of its time doing its own thing. A lazy goblin, or a cautious one.

This is also the cure for the creeping goblin from the start of the chapter. Chapter 4's S-curves never quite reach 0, so an option they suppress still has a tiny score rather than being vetoed. Without a fallback, such an option wins whenever nothing else is available: a healthy goblin backs away from a distant player, or drinks a potion it doesn't need, simply because 0.000001 is more than nothing. With a fallback at 0.05, it never will. A fallback cleans up all the near-zero scores that soft curves leave behind.

---

## Wandering

Idling in place is fine for a guard. For a goblin, wandering looks better: it moves around the room, and it's more likely to stumble into coins. Wandering needs somewhere to go, which makes it an action with a target: a **point**.

Targets don't have to be instances (Chapter 5). A struct with an `x` and a `y` works with the distance input and with the movement code, because both only read `x` and `y`:

```gml
// o_goblin > Create (add)
home_x = x;
home_y = y;

pick_wander_point = function() {
    var _angle = random(360);
    var _reach = random_range(40, 160);
    wander_point = {
        x : clamp(home_x + lengthdir_x(_reach, _angle), 16, room_width - 16),
        y : clamp(home_y + lengthdir_y(_reach, _angle), 16, room_height - 16),
    };
};
pick_wander_point();
```

```gml
// __goblin_profile_build, with the other actions
gmsa_profile_add_action(_p, "wander", {
    weight  : 0.05,
    targets : function(_agent) { return [_agent.owner.wander_point]; },
});
```

And in the acting code:

```gml
// o_goblin > Step, in the switch
case "wander":
    if (move_to(goal.x, goal.y, 1.5)) {
        pick_wander_point();
        finish();
    }
    break;
```

The goblin strolls to a point near home, picks another when it arrives, and goes back to work the moment a coin shows up, because looting outscores wandering by far.

### The same point, every think

There's a detail in that code that matters more than it looks. The targets function returns the goblin's **current** wander point, the same struct every think, and only `pick_wander_point` replaces it, on arrival.

The obvious alternative, picking a new random point inside the targets function, breaks wandering completely. The goblin thinks every ten steps, so every ten steps it gets a brand new destination and turns toward it. It jitters around one spot, changing direction six times a second. And commitment can't help: commitment favours the *same action on the same target*, and every new random point is a different target.

Returning the same struct lets everything from Chapter 6 work: each think chooses the same wander point again, commitment recognizes it, and the goblin walks a smooth line to it. That's a general rule for any target your code invents: **create it once, keep it until it's used up, and return the same one every think.**

### Wandering with sense

A bit of thought in `pick_wander_point` goes a long way:

- **A leash.** Points are picked around `home_x` and `home_y`, not around wherever the goblin is now, so it drifts but never strays far. A guard's home is its post; a goblin's is its corner of the room.
- **Avoid the player.** Reject points close to the player and try again, so an idle goblin doesn't wander up to the player and back.
- **Walls.** Points inside walls are useless. If your game has solid objects, pick again until the point is free, or let your pathfinding find the nearest walkable cell.

The debug list now shows targets that aren't instances. The namer from Chapter 5 already handles that, with its `is_struct` check, and shows them as `point`.

---

## Waiting for its moment

Wandering is a good answer when the goblin is alone. When the player is around, a goblin that wanders aimlessly looks oblivious. What would a goblin actually do with the player nearby, when it's healthy and has nothing to grab? It would keep an eye on them: not too close, not too far.

That's an action targeting the player, scored by distance with Chapter 4's "best in the middle" curve, an upside-down U:

```gml
// __goblin_profile_build, with the other actions
var _wary_distance = gmsa_curve_make(gmsa_curve.POWER, { m : 4, c : 0.5, invert : true });  // best at half the range

var _watch = gmsa_profile_add_action(_p, "watch", {
    weight  : 0.15,
    targets : function(_agent) {
        return instance_exists(o_player) ? [instance_find(o_player, 0)] : [];
    },
});
gmsa_action_add_consideration(_watch, "distance", _wary_distance);
```

The curve is 1 when the player is at half of the distance input's range, 150 pixels, and falls to 0 at the goblin's feet and at 300 pixels. With a weight of 0.15, watching beats wandering whenever the player is anywhere near that sweet spot, and loses to anything real: a coin, a potion when hurt, fleeing when hurt and close.

```gml
// o_goblin > Step, in the switch
case "watch":
    if (!instance_exists(goal)) {
        finish();
        break;
    }
    var _d = point_distance(x, y, goal.x, goal.y);
    if (_d > 170) move_to(goal.x, goal.y, 1);                     // drift closer
    else if (_d < 130) {                                          // back off
        var _away = point_direction(goal.x, goal.y, x, y);
        x += lengthdir_x(1, _away);
        y += lengthdir_y(1, _away);
    }
    break;
```

Watching never finishes on its own; it continues until something better replaces it, like fleeing did in Chapter 6. The goblin hovers at a wary distance, steps back when the player comes closer, follows a little when they leave, and drops it all the moment a coin comes into range. A player reads that as a goblin that knows they're there and doesn't trust them, which is exactly right.

Notice that `"distance"` is the same per-target input looting and drinking use. It measures the distance to whatever the target is, and now the target is the player.

---

## Patrolling

A guard doesn't wander, it patrols: a fixed route, point after point, round and round. That's the wandering pattern with a list instead of a random point:

```gml
// o_guard > Create
route = [
    { x : 100, y : 100 },
    { x : 400, y : 100 },
    { x : 400, y : 300 },
    { x : 100, y : 300 },
];
route_at = 0;
```

```gml
// the guard's profile
gmsa_profile_add_action(_p, "patrol", {
    weight  : 0.05,
    targets : function(_agent) {
        var _o = _agent.owner;
        return [_o.route[_o.route_at]];
    },
});
```

```gml
// o_guard > Step, in the switch
case "patrol":
    if (move_to(goal.x, goal.y, 1.5)) {
        route_at = (route_at + 1) mod array_length(route);
        finish();
    }
    break;
```

The route's points are structs created once, so the same point comes back every think until it's reached, and commitment keeps the guard on course. When something interrupts the patrol, an intruder, a noise, the guard deals with it, and when that's over and nothing better is on offer, patrolling wins again and the guard heads for the point it was going to. No "resume patrol" logic needed: the next point was waiting all along.

---

## Idle with variety

A goblin that does the same idle shuffle forever looks mechanical after ten seconds. Variety is cheap: several small idle actions instead of one, each with its own cooldown so it can't repeat straight away:

```gml
gmsa_profile_add_action(_p, "scratch", { weight : 0.03, cooldown : 4000000 });   // 4 seconds
gmsa_profile_add_action(_p, "look_around", { weight : 0.028, cooldown : 3000000 });
gmsa_profile_add_action(_p, "yawn", { weight : 0.026, cooldown : 6000000 });
gmsa_profile_add_action(_p, "idle", { weight : 0.02 });
```

These sit below wander in the ladder, so they're for a character that doesn't wander, or for when wandering is switched off. When nothing else is going on, the goblin scratches. Scratching goes on cooldown, so next time it looks around instead, then yawns, and while all three cool down it simply idles until the first one is ready again. The weights only decide the order they're tried in; the cooldowns make them take turns.

Remember Chapter 6's catch: an action on cooldown can't be chosen to continue it either. So make each idle action short, play its animation, and call `finish()` when the animation ends, and skip thinking while it plays, the way the stunned goblin did. Then each little idle plays out in full, and the next think picks the next one.

---

## A ladder of fallbacks

Put together, the goblin now has a ladder of things to do, each a step below the last:

| Action | Weight | When it wins |
| --- | --- | --- |
| Loot, drink, flee | 1 | Whenever there's something real to do |
| Watch | 0.15 | The player is around, and nothing real is on offer |
| Wander | 0.05 | Nothing at all is going on |
| Idle | 0.02 | Wandering isn't possible either |

With wander always available, idle never actually wins, so why keep it? Because wandering can be switched off: if `pick_wander_point` can't find a free spot, or your game turns wandering off at night, wander's targets function can return `undefined`, and idle is still there underneath. The bottom rung should always be an action that can't be vetoed and can't run out of targets. Then `no selectable options` never happens.

Each rung is a fallback for the one above it, and each weight is a threshold for everything above it: anything that scores below 0.15 loses to watching the player, anything below 0.05 loses to wandering. Tune them like any other weights, by watching the goblin and asking whether it bothers with the right things.

---

## Seeing what was vetoed

When an agent does nothing, or does its fallback when you expected something else, the first question is which options were vetoed, and by what. The debug list can't tell you, because vetoed options aren't in the decision at all.

`gmsa_agent_evaluate` can. It scores every option, vetoed ones included, without changing the agent's decision, and returns a decision of its own that the debug view can draw:

```gml
// o_goblin > Draw GUI (add): press V to see vetoed options too
if (keyboard_check(ord("V"))) {
    gmsa_debug_draw(gmsa_agent_evaluate(agent), 10, 260, 12, function(_target) {
        if (is_struct(_target)) return "point";
        if (!instance_exists(_target)) return "gone";
        if (_target.object_index == o_coin) return "coin (" + string(_target.value) + ")";
        return object_get_name(_target.object_index);
    });
}
```

Vetoed options show with a score of 0, and their considerations show which one was 0. That answers most "why won't it do X?" questions at a glance: drinking at full health shows the thirst consideration near 0, a coin out of range doesn't show at all because it was never a target, and an action on cooldown is missing entirely.

`gmsa_agent_evaluate` scores everything every time you call it, so keep it for debugging, behind a key, rather than in the game's normal loop.

---

## When standing still is right

Not every agent needs a fallback. A turret with no enemies in range should do nothing, and a trap should wait silently. For them, `no selectable options` is the correct state, and your acting code's "nothing chosen" branch, which stops and clears the current option, is the right behavior.

The question to ask is the one from the start of the chapter: what does this character do when nothing is going on? If the honest answer is "nothing, and that's fine", leave it. If the answer is anything else, it's an action.

---

## Try this

- **Find the bar.** With wander at 0.05, put a 1-coin at the very edge of the goblin's range, next to the player. Its score is tiny; the goblin wanders instead. Raise and lower wander's weight and find where the goblin starts going for it.
- **Break wandering on purpose.** Make wander's targets function return a new random point every think, and watch the jitter. Then put it back.
- **A lazy goblin and a busy one.** Build two profiles, as in Chapter 2, one with wander at 0.2 and one at 0.01. Scatter coins of mixed value and distance, and watch which ones each goblin bothers with.
- **A home to return to.** Add a `"home_distance"` situational input, the goblin's distance from `home_x` and `home_y`, and a `go_home` action with a rising curve on it and a weight of 0.1, so a goblin that's strayed far drifts back when there's nothing better to do.

---

## What you've learned

- An agent stops when it has no options: everything vetoed, no targets, actions skipped or cooling down. The engine never picks a vetoed option, because vetoed means impossible.
- Standing still is the honest answer and usually the wrong look. Idle time is when players see your characters most, so treat it as behavior to design.
- A **fallback** is an action that can't be vetoed, with a small weight. Its weight is also a **threshold**: anything scoring below it is never worth doing, which also cleans up the near-zero scores soft curves leave behind.
- **Wandering** targets a point struct. Create the point once and return the same one every think until it's reached, or commitment can't work and the agent jitters.
- Fallbacks can be smart: **watching** the player from a wary distance uses a "best in the middle" curve and the same distance input as everything else.
- A **ladder** of fallbacks, each below the last, ends in an action that can never be vetoed or run out of targets.
- `gmsa_agent_evaluate` shows vetoed options too, for debugging.

## What's next

[Chapter 8](Chapter8.md) fills the room. One goblin thinking every few steps is cheap; a hundred is not. The scheduler gives all of them one shared time budget, so adding goblins never drops the frame rate, and the chapter covers how it works, how to size the budget, and how to decide who gets to think first.