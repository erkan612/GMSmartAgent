# Chapter 5: Which One

"Loot" isn't really a decision. "Loot *that* coin" is. The moment there's more than one thing to act on, an agent has to choose not just what to do but what to do it to, and a good choice weighs everything at once: the big coin across the room against the small one at its feet, the near coin against the one right next to the player.

Chapter 3 gave drinking its first targets, the potions in the room, just enough to measure the distance to each. This chapter is about targets properly: what they are, how one decision covers "what" and "which" together, how to gather them, how to describe each one so the agent can tell them apart, how to name them in the debug list, and how to keep a room full of coins from costing a room full of time.

---

## What a target is

A **target** is anything an action can be done *to*: a coin to pick up, a potion to drink, an enemy to attack, a door to open, a spot to stand on. An action with targets produces **one option per target**. Each option is scored on its own, with its own values for the inputs that differ per target.

Targets can be anything you can put in an array:

- **Instances**, the usual case: coins, potions, enemies.
- **Structs**, for things that aren't instances: a point to walk to, `{ x : 320, y : 180 }`, a cover position, a patrol waypoint.
- **Anything else** your inputs know how to read: an index into a list of rooms, a name, a number.

GMSmartAgent never looks inside a target itself. It hands each target to your per-target input functions, and they read whatever they need. A target is just "the thing this option is about".

---

## "What" and "which" in one decision

When the goblin thinks, every action produces its options, potion by potion and coin by coin, and **all of them are ranked together**. The winner isn't "the best action, then the best target for it". It's the single best option overall.

That has consequences worth understanding:

- **A good action with a poor target can lose to a modest action with a great target.** A slightly hurt goblin with a potion right at its feet may drink before looting a coin across the room, even though looting is its usual preference. That's usually exactly right: it's the whole situation that decides, not a fixed order.
- **Many targets don't make an action more likely.** Ten coins in the room produce ten looting options, but only the best of them can win. Looting doesn't get ten times the chances. The number of targets changes which coin, never how much the goblin wants to loot.
- **No targets means no options.** An action whose targets function returns an empty array simply isn't in the ranking this think. A goblin with no potions in the room doesn't weigh drinking and reject it; drinking doesn't exist for it right now.

There's one more case: a `targets` function can return `undefined` instead of an array. That **skips** the action for this think, the same as no options, and it's a handy way to switch an action off entirely when a condition fails, before any target is gathered:

```gml
targets : function(_agent) {
    if (!_agent.owner.can_carry_more) return undefined;  // pouch full: don't even look
    return _agent.owner.find(o_coin, 300);
},
```

---

## Gathering targets

The `targets` function is called once per action every time the agent thinks. It receives the agent, and returns an array. **This is your code, not GMSmartAgent's**: it never searches the room itself, so gathering uses whatever your game already does to find things.

A good habit is to give the owner one search function and have every action use it. In the goblin's Create event:

```gml
// o_goblin > Create (add, before the agent is created)
find = function(_object, _radius) {
    var _found = [];
    var _x = x, _y = y;
    with (_object) {
        if (point_distance(x, y, _x, _y) <= _radius) array_push(_found, id);
    }
    return _found;
};
```

and the actions ask for what they need:

```gml
var _drink = gmsa_profile_add_action(_p, "drink", {
    targets : function(_agent) { return _agent.owner.find(o_potion, 300); },
});

var _loot = gmsa_profile_add_action(_p, "loot", {
    targets : function(_agent) { return _agent.owner.find(o_coin, 300); },
});
```

Two things changed from Chapter 3's version, and both matter:

- **The search lives on the owner.** Every action uses the same function, and if your game later finds things with a spatial grid, a collision list or a line-of-sight check, there's one place to change.
- **It has a radius.** Only potions within 300 pixels are targets at all. A potion on the far side of the level isn't a weak option; it isn't an option. That's both cheaper and fairer, the same idea as Chapter 3's honest senses applied to targets.

Notice that the radius matches the top of the distance input's range. That's deliberate: anything inside the radius gets a distance between 0 and 1, and nothing beyond it is ever scored. If the radius were bigger than the range, every target past 300 pixels would clamp to the same "far" value, and the agent couldn't tell them apart.

---

## One distance for everything

Chapter 3 had a `"potion_distance"` input. Now coins need a distance too, and it would be the same function with a different name. Since a per-target input simply measures whatever target it's given, one input can serve every action:

```gml
gmsa_profile_add_input(_p, gmsa_input_pull("distance", function(_agent, _target) {
    var _o = _agent.owner;
    return point_distance(_o.x, _o.y, _target.x, _target.y);
}, 0, 300, true));
```

Drinking asks for the distance to a potion, looting for the distance to a coin, and both get it from the same input. Fewer inputs means fewer things to keep consistent, and a later chapter's learning models will thank you for it: one `"distance"` means the same thing everywhere.

---

## Describing each target

Distance alone makes the nearest coin win every time. Real choices are richer than that. Give coins a value:

```gml
// o_coin > Create
value = choose(1, 1, 1, 5);  // most coins are small, some are worth five
```

and let the goblin know about it with another per-target input:

```gml
gmsa_profile_add_input(_p, gmsa_input_pull("coin_value", function(_agent, _coin) {
    return _coin.value;
}, 1, 5, true));
```

Now there's a trade-off: a big coin far away against a small one close by. What should win depends on how much more a big coin matters than a small one, which is a curve. A small coin should still be worth picking up, so the curve shouldn't veto it. That makes it a preference, a soft curve from Chapter 4:

```gml
var _richer = gmsa_curve_make(gmsa_curve.LINEAR, { m : 0.5, b : 0.5 });  // a 1 is worth half a 5, never nothing
```

And Chapter 1's awkward case, the coin lying right next to the player. A third per-target input measures how far *the player* is from each coin:

```gml
gmsa_profile_add_input(_p, gmsa_input_pull("player_to_target", function(_agent, _target) {
    if (!instance_exists(o_player)) return 200;
    return point_distance(o_player.x, o_player.y, _target.x, _target.y);
}, 0, 200, true));
```

with an S-curve that says a coin is fine once the player is a fair distance from it, and nearly worthless when the player is standing on it:

```gml
var _safe = gmsa_curve_make(gmsa_curve.LOGISTIC, { k : 12, c : 0.4 });
```

Looting now has three considerations, all per target:

```gml
gmsa_action_add_consideration(_loot, "distance", _near);
gmsa_action_add_consideration(_loot, "coin_value", _richer);
gmsa_action_add_consideration(_loot, "player_to_target", _safe);
```

Here's how four coins score against each other, the goblin at full health and looting at a weight of 1:

| Coin | Distance | Value | Player to coin | Considerations | Score |
| --- | --- | --- | --- | --- | --- |
| A | 50 px | 1 | far | 0.694, 0.5, 0.999 | 0.498 |
| B | 200 px | 5 | far | 0.111, 1, 0.999 | 0.177 |
| B, closer | 100 px | 5 | far | 0.444, 1, 0.999 | 0.609 |
| C | 60 px | 5 | 30 px | 0.64, 1, 0.047 | 0.050 |

Read it like the goblin would:

- **A against B:** the big coin at 200 pixels isn't worth the walk past a small coin at 50. The near curve says 200 pixels is a long way.
- **B, closer:** at 100 pixels, the big coin wins clearly. That's the tipping point you'd tune: how much farther will the goblin walk for five times the gold?
- **C:** a big, close coin, but the player is standing next to it. It drops to the bottom. The goblin isn't afraid of the player in general, it's at full health and fleeing scores nothing, but it won't reach for a coin under the player's feet.

None of that is a rule. It's three facts about each coin, each with a shape that says how much it matters, multiplied.

---

## Situational inputs on targeted actions

An action with targets can still use **situational** inputs, the ones with one value per think. Drinking considers `"hp"`, the goblin's health, and `"distance"`, per potion. Every potion option gets the same health value and its own distance. That's how "how much do I want to drink?" and "which potion?" combine in one score.

It also explains a pattern you'll see constantly: the situational considerations decide *whether* an action is attractive at all, and the per-target ones decide *which* target. A healthy goblin's thirst curve is near 0, so every potion scores near 0, however close. A badly hurt goblin's thirst is near 1, and the potions compete on distance.

---

## Naming targets in the debug list

Chapter 3's debug list showed targets as numbers, `drink @ 100004`. That's the instance id, which is all GMSmartAgent can know about a target. To show something readable, give `gmsa_debug_draw` a **namer**: a function that takes a target and returns a string.

```gml
// o_goblin > Draw GUI
gmsa_debug_draw(agent.decision, 10, 40, 8, function(_target) {
    if (is_struct(_target)) return "point";
    if (!instance_exists(_target)) return "gone";
    if (_target.object_index == o_coin) return "coin (" + string(_target.value) + ")";
    return object_get_name(_target.object_index);
});
```

The fourth argument, 8, is how many options to show at most. The list now reads:

```
> 0.609  p1.00  loot @ coin (5)  [distance 0.44, coin_value 1.00, player_to_target 1.00]
  0.498  p0.00  loot @ coin (1)  [distance 0.69, coin_value 0.50, player_to_target 1.00]
  0.050  p0.00  loot @ coin (5)  [distance 0.64, coin_value 1.00, player_to_target 0.05]
  0.000  p0.00  drink @ o_potion  [hp 0.00, distance 0.81]
  ...
```

Drinking and fleeing are still listed, down at the bottom near 0. Their S-curves never reach exactly 0, so at full health they're very weak options rather than vetoed ones, exactly as Chapter 4 described.

Two of the namer's lines are there for safety, and both are worth understanding:

- **`is_struct`:** targets don't have to be instances. A struct has no `object_index`, so a namer that assumes every target is an instance crashes the first time a point is a target.
- **`instance_exists`:** a decision keeps the targets it saw *when the agent last thought*. If the goblin thinks every ten steps, the debug list can be showing a coin that another goblin picked up five steps ago. Reading `object_index` from a destroyed instance is an error. Checking first, and showing "gone", is the only safe way to name targets from a decision that might be a few frames old.

That second point applies far beyond the debug list. Any time your code reads a target from a decision, it should be ready for that target to have disappeared since. Chapter 6 deals with it when the goblin starts acting on its choices.

---

## Using the chosen target

The chosen option carries its target:

```gml
// o_goblin > Step, after thinking
var _chosen = gmsa_decision_get_chosen(_decision);
goal = (_chosen == undefined) ? noone : _chosen.target;
doing = (_chosen == undefined) ? "nothing" : _chosen.action.name;
```

```gml
// o_goblin > Create (add)
goal = noone;
```

```gml
// o_goblin > Draw (add)
if (instance_exists(goal)) draw_line(x, y, goal.x, goal.y);
```

Now a line shows which coin or potion the goblin has its eye on. Copying the target into `goal` follows Chapter 2's rule: decisions are reused, so keep your own copy of anything you need later. Walking to the goal, picking it up and deciding again are Chapter 6.

---

## When the action and the target are separate questions

Ranking everything together is usually what you want, but not always. Sometimes the decision you care about is *whether* to do something, and which target is a detail that shouldn't sway it.

Take healing. A badly hurt goblin should decide to heal because it's badly hurt, and then go to whichever potion is best. With drinking scored per potion, a hurt goblin whose only potion is at the far edge of its range may score drinking low enough that looting a nearby coin wins. Sometimes that's charming, a greedy goblin pushing its luck. Sometimes it's wrong: you want the decision to be "I'm going to heal", and the distance only to decide where.

Two ways to separate the questions:

- **Keep distance out of the decision.** Give drinking a softer distance curve, with a floor, so that a far potion weakens the option a little but never sinks it. The decision is then mostly about health, and distance still picks the nearest potion among them, because nearer ones still score a little higher.
- **Decide first, choose second.** Make `heal` an action without targets, scored only on health. When the goblin chooses it, your code picks the potion, with the owner's own search or a nearest-first sort. The decision and the choice of target are now completely separate steps.

The first keeps everything in one place and is usually enough. The second is clearer when the "which" has nothing to do with the "whether", like choosing a seat once you've decided to sit down.

---

## Keeping the list small

Every target is an option, and every option is scored: each of its considerations reads an input and passes it through a curve. Scoring one option costs roughly **8 microseconds on the VM** and about 2 on YYC, the compiled target most release builds use. That's nothing for ten coins. It's 0.8 milliseconds for a hundred, every time the goblin thinks, and fifty goblins each looking at a hundred coins is real work.

The cost comes from the number of options, so the cure is fewer options. In rough order of how much they help:

- **A radius.** The single biggest saving, and you already have it. Things far away aren't options at all.
- **The nearest few.** Most of the time the best coin is among the closest five. Sort by distance and keep the first few:

```gml
// o_goblin > Create (add)
find_nearest = function(_object, _radius, _count) {
    var _found = find(_object, _radius);
    array_sort(_found, method({ ox : x, oy : y }, function(_a, _b) {
        return point_distance(ox, oy, _a.x, _a.y) - point_distance(ox, oy, _b.x, _b.y);
    }));
    if (array_length(_found) > _count) array_resize(_found, _count);
    return _found;
};
```

  The comparison function can't see `find_nearest`'s local variables, so `method` hands it the goblin's position in a small struct: inside it, `ox` and `oy` are that struct's fields. If a big coin sits just outside the nearest five, it isn't considered: that's the trade you make, and with a sensible count it rarely matters.
- **Filter before scoring.** If the goblin can't carry more, return `undefined` and skip looting entirely, as shown earlier. A cheap check in `targets` saves scoring every coin.
- **Let your game's spatial tools do the searching.** `collision_circle_list`, a grid of buckets, or a pathfinding system's queries can all find nearby things far faster than looping over every instance in the room. The `find` function is the one place to plug them in.
- **Keep per-target inputs cheap.** A per-target input runs once per target per think. A distance is free. A line-of-sight check per coin adds up; consider whether the goblin needs it for every coin or only for the winner.

There's one more saving GMSmartAgent makes for you. If two actions return **the same array** from their targets functions in one think, their per-target inputs are evaluated once per target and shared. Say a goblin can both loot and kick coins: gather the coins once in the goblin's Step, right before it thinks, store the array in a variable, and return that variable from both actions. Different arrays holding the same coins still work correctly; the values are just computed once per array.

---

## The whole profile

Here's the goblin with everything so far:

```gml
function __goblin_profile_build() {
    var _p = gmsa_profile_create("goblin");

    // what the goblin knows about itself and the world
    gmsa_profile_add_input(_p, gmsa_input_pull("hp", function(_agent, _target) {
        return _agent.owner.hp;
    }, 0, 100));
    gmsa_profile_add_input(_p, gmsa_input_pull("player_distance", function(_agent, _target) {
        if (!instance_exists(o_player)) return 400;
        var _o = _agent.owner;
        return point_distance(_o.x, _o.y, o_player.x, o_player.y);
    }, 0, 400));

    // what it knows about each target
    gmsa_profile_add_input(_p, gmsa_input_pull("distance", function(_agent, _target) {
        var _o = _agent.owner;
        return point_distance(_o.x, _o.y, _target.x, _target.y);
    }, 0, 300, true));
    gmsa_profile_add_input(_p, gmsa_input_pull("coin_value", function(_agent, _coin) {
        return _coin.value;
    }, 1, 5, true));
    gmsa_profile_add_input(_p, gmsa_input_pull("player_to_target", function(_agent, _target) {
        if (!instance_exists(o_player)) return 200;
        return point_distance(o_player.x, o_player.y, _target.x, _target.y);
    }, 0, 200, true));

    // how much each thing matters
    var _thirst    = gmsa_curve_make(gmsa_curve.LOGISTIC, { k : -15, c : 0.35 });
    var _near      = gmsa_curve_make(gmsa_curve.POWER, { c : 1 });
    var _richer    = gmsa_curve_make(gmsa_curve.LINEAR, { m : 0.5, b : 0.5 });
    var _safe      = gmsa_curve_make(gmsa_curve.LOGISTIC, { k : 12, c : 0.4 });
    var _too_close = gmsa_curve_make(gmsa_curve.LOGISTIC, { k : -12, c : 0.3 });
    var _weak      = gmsa_curve_make(gmsa_curve.LOGISTIC, { k : -10, c : 0.4 });

    var _drink = gmsa_profile_add_action(_p, "drink", {
        targets : function(_agent) { return _agent.owner.find_nearest(o_potion, 300, 5); },
    });
    gmsa_action_add_consideration(_drink, "hp", _thirst);
    gmsa_action_add_consideration(_drink, "distance", _near);

    var _loot = gmsa_profile_add_action(_p, "loot", {
        targets : function(_agent) { return _agent.owner.find_nearest(o_coin, 300, 5); },
    });
    gmsa_action_add_consideration(_loot, "distance", _near);
    gmsa_action_add_consideration(_loot, "coin_value", _richer);
    gmsa_action_add_consideration(_loot, "player_to_target", _safe);

    var _flee = gmsa_profile_add_action(_p, "flee");
    gmsa_action_add_consideration(_flee, "player_distance", _too_close);
    gmsa_action_add_consideration(_flee, "hp", _weak);

    return gmsa_profile_build(_p);
}
```

Looting no longer has a fixed weight of 0.5: it has considerations now, so it scores by its coins, at the default weight of 1. Place a dozen coins of mixed value around the room, a few potions, and play: walk the player near the goblin's chosen coin and watch its line jump to another; hurt the goblin and watch the line swing to a potion; clear every coin within 300 pixels and watch looting vanish from the list.

---

## Try this

- **Find the tipping point.** Put a 1-coin at 50 pixels and move a 5-coin outward from 60 pixels until the goblin prefers the small one. Then change `_richer` to `{ m : 0.8, b : 0.2 }` and find it again: a greedier goblin walks farther.
- **Shrink the count.** Change `find_nearest`'s count to 1. The goblin now only ever considers the nearest coin, and the value of coins stops mattering. That's the cost of cutting too hard.
- **Kick coins.** Add a `kick` action, weight 0.3, that targets the same coins and considers `"distance"` only. Gather the coins into `nearby_coins` in the Step event right before thinking, and return `_agent.owner.nearby_coins` from both actions, then watch the debug list: both actions list the same coins with the same distances.
- **Separate the questions.** Turn drinking into a targetless `heal` action scored on `"hp"` only, and pick the nearest potion yourself when it's chosen. Compare how often a hurt goblin heals against the version where far potions sink the decision.

---

## What you've learned

- A **target** is whatever an action is done to: an instance, a struct, anything your inputs can read. An action with targets produces one option per target.
- All options from all actions are ranked together, so "what" and "which" are one decision. Only an action's best target can win, so more targets never make an action more likely. No targets means no options, and returning `undefined` skips an action entirely.
- Gathering targets is your code. Put the search on the owner, give it a radius that matches the distance range, and share it between actions.
- Per-target inputs describe each target: distance, value, danger. One per-target input can serve many actions.
- Situational considerations decide whether an action is attractive; per-target ones decide which target.
- A **namer** makes the debug list readable, and must handle structs and targets that have disappeared since the last think.
- When the decision and the target are separate questions, soften the target's influence, or decide first and choose the target yourself.
- Options cost about 8 microseconds each on the VM. Keep the list small: a radius, the nearest few, filters, your game's spatial tools, cheap per-target inputs, and shared arrays.

## What's next

[Chapter 6](Chapter6.md) puts the goblin in motion: thinking at the right moments, acting on a fresh decision exactly once, walking to its target, knowing when it's done, and the small bonus called commitment that stops it from dithering between two coins at the same distance.