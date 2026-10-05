# Getting Started with GMSmartAgent

This guide builds one small enemy, a goblin that loots coins and drinks potions when it's hurt, and grows it step by step into a room full of goblins sharing one AI budget, one of which learns to play like you. Each step adds one idea. By the end you'll know every part of GMSmartAgent you need for a real game.

For every function's full details, see the [API Reference](ApiReference.md).

---

## Contents

1. [Installation](#1-installation)
2. [The Idea in Two Minutes](#2-the-idea-in-two-minutes)
3. [Your First Decision](#3-your-first-decision)
4. [Pull Inputs](#4-pull-inputs)
5. [Targets](#5-targets)
6. [Acting on a Decision](#6-acting-on-a-decision)
7. [When Nothing Is Worth Doing](#7-when-nothing-is-worth-doing)
8. [Tuning](#8-tuning)
9. [Locking In Your Tuning with Tests](#9-locking-in-your-tuning-with-tests)
10. [Many Agents: the Scheduler](#10-many-agents-the-scheduler)
11. [Learning From the Player](#11-learning-from-the-player)
12. [Choosing a Model](#12-choosing-a-model)
13. [Learning What Works](#13-learning-what-works)
14. [Troubleshooting](#14-troubleshooting)

---

## 1. Installation

1. Download `GMSmartAgent.yymps` from the latest GitHub release.
2. In GameMaker, open **Tools > Import Local Package** and select the file.
3. Import the folders you need:

| Folder | Needed | What it is |
| --- | --- | --- |
| Core | Always | The engine |
| Test | Recommended | Testing your profiles. Required by Debug |
| Debug | Recommended | Seeing why an agent chose what it chose |
| Learn | Optional | Learning from the player's choices. Requires Net |
| Net | With Learn | The small neural network Learn's RankNet model is built on, usable on its own |

GMSmartAgent is pure GML, so there are no extensions or DLLs, and it runs on every platform GameMaker exports to. It needs a GameMaker version with structs and methods (2.3 or newer).

---

## 2. The Idea in Two Minutes

Instead of writing `if (hp < 30) flee(); else if (...)`, you list everything an agent *could* do, and describe what makes each option good. Every time the agent thinks, each option gets a score between 0 and 1, and the best one wins.

The vocabulary:

| Term | Meaning | Goblin example |
| --- | --- | --- |
| **Input** | A number the agent knows | Its health, the distance to a coin |
| **Curve** | Turns an input into "how good is this", from 0 to 1 | "Low health is very urgent, medium health barely matters" |
| **Consideration** | One input through one curve | Health through an urgency curve |
| **Action** | Something the agent can do, with its considerations | Drink a potion |
| **Target** | What an action is done to | *Which* potion |
| **Option** | One action plus one target, scored | Drink the potion by the door: 0.65 |
| **Profile** | All the inputs and actions, shared by every goblin | The goblin brain |
| **Agent** | One goblin's personal state | This goblin's cooldowns and current choice |
| **Decision** | The result of one think: every option, ranked | "Drink 0.65, loot 0.24, wander 0.05" |

Considerations on the same action are **multiplied**. That means a single zero kills the option. "No potion in sight" or "can't afford it" can veto an option outright, without any special-case code.

And one rule above all: **GMSmartAgent never touches your game.** It doesn't move instances, search the room, or check collisions. Your game hands it numbers, and it hands back a ranked list. What the goblin does with its choice is your code.

---

## 3. Your First Decision

We start with no movement at all: one goblin choosing between looting and drinking, based only on its health.

Create a script `Goblin_Profile`:

```gml
/// The goblin brain, built once and shared by every goblin.
function goblin_profile() {
    static _profile = __goblin_profile_build();
    return _profile;
}

function __goblin_profile_build() {
    var _p = gmsa_profile_create("goblin");

    // a push input: we feed the value ourselves, raw 0..100 becomes 0..1
    gmsa_profile_add_input(_p, gmsa_input_push("hp", 0, 100, 100));

    // drink: very urgent below 40% health, barely matters above it
    var _a = gmsa_profile_add_action(_p, "drink");
    gmsa_action_add_consideration(_a, "hp", gmsa_curve_make(gmsa_curve.LOGISTIC, { k : -10, c : 0.4 }));

    // loot: no considerations, so it always scores its weight
    gmsa_profile_add_action(_p, "loot", { weight : 0.5 });

    return gmsa_profile_build(_p);
}
```

The `static` pattern builds the profile the first time `goblin_profile()` is called and returns the same one afterwards. Every goblin shares it.

Create an object `o_goblin`:

```gml
// o_goblin > Create
hp = 100;
agent = gmsa_agent_create(goblin_profile(), id);
```

```gml
// o_goblin > Step
if (keyboard_check_pressed(vk_down)) hp = max(0, hp - 10);
if (keyboard_check_pressed(vk_up))   hp = min(100, hp + 10);

gmsa_agent_set_input(agent, "hp", hp);
gmsa_agent_think(agent);
```

```gml
// o_goblin > Draw GUI
draw_text(10, 10, "hp " + string(hp) + "   up/down to change");
gmsa_debug_draw(agent.decision, 10, 40);
```

Run it and press down a few times. The debug list shows both options, ranked, with the chosen one marked `>`:

| HP | drink | loot | Choice |
| --- | --- | --- | --- |
| 100 | 0.002 | 0.5 | loot |
| 50 | 0.27 | 0.5 | loot |
| 30 | 0.73 | 0.5 | drink |
| 10 | 0.95 | 0.5 | drink |

The switch happens at 40% health, exactly where the curve crosses 0.5. That's the whole idea: you shape *how much each thing matters*, and the ranking does the rest.

> One goblin thinking every step is fine. With many agents you'll use a scheduler, see [section 10](#10-many-agents-the-scheduler).

---

## 4. Pull Inputs

Feeding `hp` by hand every step works, but most values are better **pulled**: GMSmartAgent calls a function of yours, and only when the agent actually thinks.

In `__goblin_profile_build`, replace the push input:

```gml
gmsa_profile_add_input(_p, gmsa_input_pull("hp", function(_agent, _target) {
    return _agent.owner.hp;
}, 0, 100));
```

and remove the `gmsa_agent_set_input` line from the Step event.

`_agent.owner` is the instance you passed to `gmsa_agent_create`, so callbacks can read anything on your object.

**Which to use:**

| | Pull | Push |
| --- | --- | --- |
| Who provides the value | Your callback, called by GMSmartAgent | You, with `gmsa_agent_set_input` |
| When it's computed | Only when the agent thinks, once per think | Whenever you set it |
| Best for | Anything that costs something: distances, line of sight, path cost | Values your game already has for free |

Pull is the default for a reason. With many agents, most of them aren't thinking on a given frame, and pulled values are never computed for agents that don't think.

---

## 5. Targets

So far "loot" and "drink" are abstract. Now there are real coins and potions in the room, and the goblin must choose *which* one.

Create two objects, `o_coin` and `o_potion`. They need nothing but a sprite.

Give the goblin a way to find things. **This is your code, not GMSmartAgent's**: use whatever search your game already has.

```gml
// o_goblin > Create
hp = 100;

// the goblin's own search, GMSmartAgent never searches the room itself
find = function(_object) {
    var _found = [];
    var _x = x, _y = y;
    with (_object) {
        if (point_distance(x, y, _x, _y) <= 300) array_push(_found, id);
    }
    return _found;
};

agent = gmsa_agent_create(goblin_profile(), id);
```

Now rebuild the profile with targets:

```gml
function __goblin_profile_build() {
    var _p = gmsa_profile_create("goblin");

    gmsa_profile_add_input(_p, gmsa_input_pull("hp", function(_agent, _target) {
        return _agent.owner.hp;
    }, 0, 100));

    // per target: computed once for each coin or potion, true at the end
    gmsa_profile_add_input(_p, gmsa_input_pull("distance", function(_agent, _target) {
        var _o = _agent.owner;
        return point_distance(_o.x, _o.y, _target.x, _target.y);
    }, 0, 300, true));

    var _near = gmsa_curve_make(gmsa_curve.LINEAR, { m : -1, b : 1 });  // 1 up close, 0 at 300 px

    var _a = gmsa_profile_add_action(_p, "drink", {
        targets : function(_agent) { return _agent.owner.find(o_potion); },
    });
    gmsa_action_add_consideration(_a, "distance", _near);
    gmsa_action_add_consideration(_a, "hp", gmsa_curve_make(gmsa_curve.LOGISTIC, { k : -10, c : 0.4 }));

    _a = gmsa_profile_add_action(_p, "loot", {
        weight  : 0.5,
        targets : function(_agent) { return _agent.owner.find(o_coin); },
    });
    gmsa_action_add_consideration(_a, "distance", _near);

    return gmsa_profile_build(_p);
}
```

What changed:

- Each action has a `targets` callback returning an array. Every element becomes its own option: three coins in range means three "loot" options, each scored separately.
- The `distance` input is **per target** (the `true` at the end), so its callback receives each target in turn. Inputs that aren't per target get `undefined` as the target.
- An action with no targets in range produces no options at all.

The debug list now shows lines like `loot @ ref instance 100012`. To make them readable, pass a namer:

```gml
// o_goblin > Draw GUI
draw_text(10, 10, "hp " + string(hp));
gmsa_debug_draw(agent.decision, 10, 40, 8, function(_target) {
    return object_get_name(_target.object_index);
});
```

---

## 6. Acting on a Decision

Time to move. The pattern is always the same: think, take the fresh decision, act on the chosen option.

```gml
// o_goblin > Create (add)
goal = noone;
think_timer = 0;
```

```gml
// o_goblin > Step
if (keyboard_check_pressed(vk_down)) hp = max(0, hp - 10);

// think every 10 steps
think_timer--;
if (think_timer <= 0) {
    think_timer = 10;
    gmsa_agent_think(agent);
}

// act on a fresh decision
var _decision = gmsa_agent_consume(agent);
if (_decision != undefined) {
    var _option = gmsa_decision_get_chosen(_decision);
    if (_option == undefined) {
        goal = noone;
        gmsa_agent_clear_current(agent);
    } else {
        goal = _option.target;
        gmsa_agent_set_current_option(agent, _option);
    }
}

// move, and pick up on arrival
if (instance_exists(goal)) {
    if (point_distance(x, y, goal.x, goal.y) <= 2) {
        if (goal.object_index == o_potion) hp = min(100, hp + 40);
        instance_destroy(goal);
        speed = 0;
        goal = noone;
        gmsa_agent_clear_current(agent);
        think_timer = 0;  // decide again right away
    } else {
        move_towards_point(goal.x, goal.y, 2);
    }
} else {
    speed = 0;
}
```

Three functions to know:

- **`gmsa_agent_consume`** returns the decision once, then `undefined` until the next think. You never act on the same decision twice by accident.
- **`gmsa_decision_get_chosen`** returns the winning option, or `undefined` when nothing could be chosen.
- **`gmsa_agent_set_current_option`** tells GMSmartAgent what the goblin is doing now. Combined with a profile's `commitment`, this stops the goblin from flip-flopping between two coins at nearly the same distance:

```gml
var _p = gmsa_profile_create("goblin", { commitment : 0.15 });  // +15% for what it's already doing
```

> **Decisions are reused.** Each agent owns one decision struct, overwritten by every think. Don't keep a reference to a decision or an option for later: copy what you need, like `goal = _option.target` does here.

---

## 7. When Nothing Is Worth Doing

Clear the room of coins and potions, and the goblin stops dead. That's not a bug: with no targets in range, there are no options, so `gmsa_decision_get_chosen` returns `undefined`. The engine never invents behavior you didn't define.

The fix belongs in the profile: give the goblin something to do when nothing else is worth it. A low-weight **wander** action whose target is a point, not an instance:

```gml
// at the end of __goblin_profile_build, before gmsa_profile_build
gmsa_profile_add_action(_p, "wander", {
    weight  : 0.05,
    targets : function(_agent) { return [_agent.owner.wander_point]; },
});
```

```gml
// o_goblin > Create (add, before gmsa_agent_create)
wander_pick = function() {
    wander_point = { x : random(room_width), y : random(room_height) };
};
wander_pick();
```

Two details make wandering look natural:

- **The same point every think.** If the callback rolled a new random point each time, the goblin would change direction every 10 steps. Returning the same struct lets commitment keep it on course. Reroll only on arrival.
- **A very low weight**, so any coin or potion in range beats it.

Targets can now be either instances or point structs. The debug namer from [section 5](#5-targets) has to handle points too:

```gml
// o_goblin > Draw GUI, replace the namer
gmsa_debug_draw(agent.decision, 10, 40, 8, function(_target) {
    return is_struct(_target) ? "point" : object_get_name(_target.object_index);
});
```

And the Step event checks for both:

```gml
// o_goblin > Step, replace the movement block
if (is_struct(goal) || instance_exists(goal)) {
    if (point_distance(x, y, goal.x, goal.y) <= 2) {
        if (is_struct(goal)) {
            wander_pick();
        } else {
            if (goal.object_index == o_potion) hp = min(100, hp + 40);
            instance_destroy(goal);
        }
        speed = 0;
        goal = noone;
        gmsa_agent_clear_current(agent);
        think_timer = 0;
    } else {
        move_towards_point(goal.x, goal.y, 2);
    }
} else {
    speed = 0;
}
```

---

## 8. Tuning

Hurt the goblin to 20 hp, with a coin close by and a potion far away. It goes for the coin. The debug list shows why:

| Option | distance | hp | Score |
| --- | --- | --- | --- |
| loot (coin at 90 px) | 0.70 | | 0.35 |
| drink (potion at 240 px) | 0.20 | 0.88 | 0.25 |

The goblin is badly hurt (0.88), but the potion's distance (0.20) drags it down, because potions use the same distance curve as coins. A dying goblin should be willing to walk for a potion.

This is what tuning utility AI looks like: read the numbers, find which consideration lost, change one thing. Two changes fix it.

**1. A softer distance curve for potions.** Distance only halves a potion's value at the edge of sight, instead of zeroing it:

```gml
var _near_potion = gmsa_curve_make(gmsa_curve.LINEAR, { m : -0.5, b : 1 });
// use _near_potion instead of _near in the drink action
```

**2. Greed fades when hurt.** Instead of making drinking win the fight alone, let looting react to health too:

```gml
// in the loot action
gmsa_action_add_consideration(_a, "hp", gmsa_curve_make(gmsa_curve.LINEAR, { m : 0.6, b : 0.4 }));  // 1 at full hp, 0.4 near death
```

Now at 20 hp: drink scores 0.65 and loot 0.24, and the goblin walks for the potion. At full health, drinking is near zero and looting is untouched.

**Rules of thumb:**

- **One consideration per real concern.** "How hurt", "how far", "how valuable" are separate considerations, not one hand-mixed formula.
- **Let every option react to the same pressure.** When danger rises, the risky options should drop, not just the safe one rise. Shifts become gradual instead of sudden.
- **Read before you change.** The debug list shows every consideration's value. Find the one that lost before touching weights.
- **Change one number at a time.** Utility values interact, and two changes at once hide which one helped.
- **Curves over weights.** A weight scales an action everywhere. A curve changes *when* it matters, which is usually what you actually want.

**Curve cheat sheet**, every curve maps 0..1 to 0..1:

| You want | Curve |
| --- | --- |
| More is better, steadily | `LINEAR` |
| Less is better, steadily | `LINEAR` with `{ m : -1, b : 1 }` |
| Only matters when it gets high | `POWER` (default k 2) |
| Matters early, then levels off | `POWER` with `{ k : 0.5 }` |
| Switches on around a threshold, smoothly | `LOGISTIC` with `c` at the threshold |
| Switches off around a threshold | `LOGISTIC` with negative `k` |
| Hard yes or no | `STEP` with `c` at the threshold |
| Best in the middle | `POWER` with `{ m : 4, c : 0.5, invert : true }` |

---

## 9. Locking In Your Tuning with Tests

Once the goblin behaves the way you want, lock it in. Otherwise a weight you change next month can quietly break the potion behavior, and nobody notices until a player does.

`gmsa_test_scenario` builds an agent on your profile, thinks once, and checks which action won. Pull callbacks read `agent.owner`, so a plain struct stands in for the goblin:

```gml
function goblin_tests() {
    gmsa_test_suite("Goblin", function() {

        // a fake goblin: a coin at 90 px, a potion at 240 px
        var _fake = function(_hp) {
            return {
                hp : _hp, x : 0, y : 0,
                wander_point : { x : 0, y : 0 },
                find : function(_object) {
                    return (_object == o_coin) ? [{ x : 90, y : 0 }] : [{ x : 240, y : 0 }];
                },
            };
        };
        var _ctx = { fake : _fake };

        gmsa_test_case("healthy goblin loots", method(_ctx, function() {
            gmsa_test_scenario(goblin_profile(), fake(100), {}, "loot");
        }));
        gmsa_test_case("hurt goblin walks to a far potion", method(_ctx, function() {
            gmsa_test_scenario(goblin_profile(), fake(20), {}, "drink");
        }));
    });
}
```

Run it from any object, for example in a test room:

```gml
gmsa_test_clear();
goblin_tests();
gmsa_test_run(true);
```

```
[GMSA Test] Goblin
  PASS  healthy goblin loots
  PASS  hurt goblin walks to a far potion
[GMSA Test] 2 passed, 0 failed, 0 errors
```

Every scenario also checks the decision's invariants (scores in range, probabilities adding up, and so on), so a broken custom curve shows up here too.

---

## 10. Many Agents: the Scheduler

One goblin can think whenever it likes. A hundred goblins thinking every few steps will eventually cost more than your frame can afford. The **scheduler** gives all of them one shared time budget.

**The controller:**

```gml
// o_controller > Create
global.ai = gmsa_scheduler_create(2000);  // 2 ms of AI per step, in microseconds
```

```gml
// o_controller > Step
gmsa_scheduler_step(global.ai);
```

**The goblin**, three changes:

```gml
// o_goblin > Create, replace the agent line
agent = gmsa_agent_create(goblin_profile(), id, { interval : 100000 });  // at most 10 thinks a second
gmsa_scheduler_add(global.ai, agent);
```

```gml
// o_goblin > Step: remove the think_timer block, the scheduler thinks for you.
// Keep the consume and movement code. On arrival, replace "think_timer = 0;" with:
gmsa_agent_think(agent);  // decide again right away, outside the budget
```

```gml
// o_goblin > Clean Up
gmsa_scheduler_remove(global.ai, agent);
```

> **Always remove agents in Clean Up.** A scheduler keeps every agent it was given. Without this, it keeps thinking for goblins that no longer exist.

**What the budget does.** Each step, the scheduler lets due agents think until 2 ms are used, then stops. The ones it didn't reach go first next step. Your AI never costs more than its budget, no matter how many agents you add. What changes instead is how often each agent decides:

- **Few agents**: everyone thinks as often as their `interval` allows.
- **Many agents**: the budget fills up, and each agent waits longer between decisions.

The frame rate is protected, and the cost of more agents shows up as slower reactions. Time is always in **microseconds**: 1000000 is one second, so an interval of 100000 means at most 10 decisions a second.

**Tiers: who thinks first.** When the budget can't serve everyone, `priority` decides the order. Higher tiers think first, and lower tiers get what's left. Promote what the player can see:

```gml
// o_goblin > Create (add)
tier_timer = irandom(30);  // staggered, so goblins don't all re-tier on the same step
```

```gml
// o_goblin > Step, every half second is plenty
tier_timer--;
if (tier_timer <= 0) {
    tier_timer = 30;
    var _near = point_distance(x, y, o_player.x, o_player.y) < 400;
    gmsa_scheduler_set_priority(global.ai, agent, _near ? 1 : 0);
}
```

In the bat demo, with 1500 simple agents on a 2 ms budget, tiers make this difference:

| | Agents near the player | Agents far away |
| --- | --- | --- |
| Tiers on | Decide every ~6 frames | Decide every ~60 frames |
| Tiers off | Everyone decides every ~21 frames | |

The total work is identical. Tiers just put the fresh decisions where the player is looking. Keep the high tier small: if it alone needs more than the whole budget, lower tiers stop deciding entirely.

**Receiving decisions: polling or callbacks.** So far the goblin polls with `gmsa_agent_consume` in its Step event. The alternative is a callback the scheduler calls right after the agent decides:

```gml
agent = gmsa_agent_create(goblin_profile(), id, {
    interval  : 100000,
    on_decide : function(_agent) {
        var _option = gmsa_decision_get_chosen(_agent.decision);
        // act on it, _agent.owner is the goblin
    },
});
```

Callbacks run after the scheduler's timed loop, so your code never eats into the AI budget. Use whichever fits your code: polling keeps everything in the agent's own Step event, callbacks react the moment the decision is made.

**Agents outside a scheduler.** A single boss, or a turn-based game, can still call `gmsa_agent_think` directly. You can mix both: an agent in a scheduler can also be made to think immediately with `gmsa_agent_think`, for example right after it reaches its goal. That think simply doesn't count toward the budget.

---

## 11. Learning From the Player

Everything so far is your design: you wrote the curves, the goblins follow them. The Learn module adds a second voice. A **model** watches the choices the player makes, learns their habits, and nudges a goblin toward them. In this chapter one goblin becomes a copycat that plays the way you do.

Learning needs three things: something to describe each option, choices to learn from, and a goblin that listens.

**1. Describe the options.** A model learns from inputs, so tell the profile which ones describe a choice. Add one line before the build:

```gml
// __goblin_profile_build(), before gmsa_profile_build
gmsa_profile_set_features(_p, ["hp", "distance"]);
```

`hp` describes the situation, `distance` tells one coin from another. Together they let a model learn things like "loots even when hurt" or "doesn't mind walking for a coin".

**2. Record the player's choices.** The player picks coins and potions too, by clicking them. Give the player the same `hp`, `find` and `wander_point` the goblin has, and an agent on the goblin profile. This agent never thinks, it only records:

```gml
// o_player > Create
hp = 100;
find = function(_object) {
    var _found = [];
    var _x = x, _y = y;
    with (_object) {
        if (point_distance(x, y, _x, _y) <= 300) array_push(_found, id);
    }
    return _found;
};
wander_point = { x : x, y : y };  // the goblin profile asks for one, the player never wanders
agent = gmsa_agent_create(goblin_profile(), id);  // records the player's choices, never thinks
```

The model lives in the controller, so it outlives any one instance:

```gml
// o_controller > Create
global.taste = gmsa_learn_linear_create({ confidence_k : 10 });
```

When the player clicks an item, record it together with everything else they could have picked at that moment. A choice only means something next to the options that lost:

```gml
// o_player > Global Left Pressed
var _item = instance_position(mouse_x, mouse_y, o_coin);
if (_item == noone) _item = instance_position(mouse_x, mouse_y, o_potion);
if (_item == noone) exit;

var _offered = [];
var _chosen = -1;
var _coins = find(o_coin);
for (var _i = 0; _i < array_length(_coins); _i++) {
    if (_coins[_i] == _item) _chosen = array_length(_offered);
    array_push(_offered, { action : "loot", target : _coins[_i] });
}
var _potions = find(o_potion);
for (var _i = 0; _i < array_length(_potions); _i++) {
    if (_potions[_i] == _item) _chosen = array_length(_offered);
    array_push(_offered, { action : "drink", target : _potions[_i] });
}

// an item out of range wasn't a fair comparison, so it isn't recorded
if (_chosen >= 0) gmsa_learn_observe(global.taste, gmsa_observe(agent, _offered, _chosen));

goal = _item;  // walking there is your code
```

`gmsa_observe` scores the options exactly like a goblin would and records which one won. `gmsa_learn_observe` trains the model on it. They're separate on purpose: choices you don't want learned, like a tutorial telling the player what to click, are simply never passed in.

**3. A goblin that listens.** Pick one goblin in the room and give it the model, in its Instance Creation Code:

```gml
// one goblin > Creation Code
gmsa_agent_set_model(agent, global.taste, 1);
```

Every other goblin keeps playing by your design. The `1` is the **influence**: how much say the model gets, from 0 (none) to 1.

Play for a while. Grab coins while you're hurt and ignore the potions. At first the copycat behaves like any goblin, since a model that has seen nothing has no confidence and changes nothing. As your choices pile up, it starts looting when it should be drinking, because that's what you do.

**Seeing it.** The debug list shows where learning changed a score:

```
> 0.274  p1.00  loot @ ref instance 100007  [distance 0.82, hp 0.52]
  0.180  p0.00  drink @ ref instance 100009  [distance 0.71, hp 0.86]  (designer 0.730)
```

Your curves rated the potion at 0.730. The model, having watched you skip potions, pushed it down to 0.180, and the coin won.

**The model can only push down.** This is the rule that keeps you in charge:

- The option the model likes most keeps your score. Every other option is pushed down by how much less the model likes it.
- No option ever scores above what your curves gave it.
- An option your curves vetoed stays vetoed, and one you scored near zero stays near zero. The model never makes a goblin do something you ruled out.

So leave room where you want learning to have a say. A full-health goblin scores a potion at almost nothing (the `hp` curve from [Tuning](#8-tuning)), so no amount of potion-loving players will make the copycat drink at full health. That's often exactly right. If you want it to be able to pick that up from the player, soften the curve so it doesn't drop all the way. Hard rules get hard curves, matters of taste get soft ones.

**Turning it up and down.** Influence can change at runtime, which makes it a natural difficulty or personality setting:

```gml
gmsa_learn_set_influence(agent, 0.5);  // half as much say
```

**Keeping what it learned.** A model can be saved with your game and loaded back:

```gml
// saving
var _file = file_text_open_write("taste.json");
file_text_write_string(_file, gmsa_learn_save(global.taste));
file_text_close(_file);
```

```gml
// o_controller > Create, after creating the model
if (file_exists("taste.json")) {
    var _file = file_text_open_read("taste.json");
    gmsa_learn_load(global.taste, file_text_read_string(_file));
    file_text_close(_file);
}
```

**Reading the player.** A model can also answer "what is the player likely to do right now?" as an ordinary input, for a profile other than the one the player's agent uses. A shopkeeper could stock up when the player is likely to drink:

```gml
gmsa_profile_add_input(_shop, gmsa_input_pull("player_drinks", gmsa_learn_input(global.taste, o_player.agent, "drink")));
```

The [API Reference](ApiReference.md#learn) covers this, the second built-in model (Count, faster to learn, for habits), and writing your own.

---

## 12. Choosing a Model

The copycat uses Linear, the model to start with: fast, cheap and quick to learn. But Linear weighs each input on its own, so some habits are invisible to it.

Play like this: **when you're healthy, walk anywhere for a coin. When you're hurt, only grab coins close by.** Whether distance matters depends on your health. That's a combination of two inputs, and Linear can only learn "distance matters" or "distance doesn't", never "it depends". The copycat will settle somewhere in between and copy neither half of your habit.

**RankNet** learns combinations. It's a small neural network, and switching to it is one line:

```gml
// o_controller > Create
global.taste = gmsa_learn_ranknet_create();
```

Nothing else changes: the same observe calls, the same `gmsa_agent_set_model`, the same debug view. Expect it to need more picks than Linear before it settles, dozens rather than a handful.

**LambdaMART** learns the most detailed rankings. It builds decision trees, so it's good at sharp rules like "only below 30% health". It also works differently: it stores your picks and learns from them in batches, so it needs to be told when to train.

```gml
// o_controller > Create
global.taste = gmsa_learn_lambdamart_create();
global.retrain = false;
```

```gml
// o_player > Create (add)
picks = 0;
```

```gml
// o_player > Global Left Pressed, after gmsa_learn_observe
picks++;
if (picks mod 10 == 0) global.retrain = true;
```

```gml
// o_controller > Step
if (global.retrain) global.retrain = !gmsa_learn_train(global.taste, 2000);  // 2 ms per step until done
```

Training runs in the background, a little each step, and the copycat keeps its old opinion until the new one is ready. Until the first training finishes, it has no opinion at all and plays by your design. You can also train once at a checkpoint, at the end of a level or on a death screen, with no budget: `gmsa_learn_train(global.taste)`.

**Which one?**

| Model | Use it for |
| --- | --- |
| Linear | The default. Clear preferences, learned in a handful of picks |
| Count | Habits per situation ("drinks when health is low"), explains itself in plain words |
| RankNet | Habits that depend on combinations of inputs |
| LambdaMART | The most detailed habits, sharp thresholds, trained in batches |

They also differ a lot in cost. Count and Linear are cheap enough for every goblin in the room. RankNet and LambdaMART cost several times more per think, so give them to a few agents, a boss or a companion like the copycat, or read them through `gmsa_learn_input`, which shares one prediction per frame between every agent reading it. Whatever you attach, the scheduler's budget still protects your frame rate: a heavier model means fewer thinks per step, never a slower game. The [API Reference](ApiReference.md#what-models-cost) has the measured numbers.

---

## 13. Learning What Works

The copycat learns from **your choices**: you pick, it copies your taste. A model can also learn from **what happens**: a goblin acts, your game says how it went, and the model learns which actions pay off. One copies someone, the other discovers what works.

You decide what counts as good. You never tell it which action is right.

**When it's worth it:** only when you can't know the answer while writing the profile. If coins near the swamp are always cursed, write that as a consideration. That's instant and exact. But if *which* coins are cursed changes every game, no curve you write can know it. That's what outcome learning is for.

So let's curse some coins. There are three kinds of coin, and each game one kind, chosen at random, bites whoever picks it up.

```gml
// o_coin > Create
source = irandom(2);  // three kinds of coin
var _tint = [c_yellow, c_orange, c_silver];
image_blend = _tint[source];  // you can tell them apart, so can the goblins
```

```gml
// o_controller > Create (add)
global.cursed = irandom(2);  // a secret: no profile ever reads it
global.loot_sense = gmsa_learn_linear_create({ learns : gmsa_learn_target.OUTCOMES });
```

**Give the goblins the cause.** A model can only learn what its inputs can tell apart. Here that's the kind of coin, so it becomes three inputs, one per kind:

```gml
// __goblin_profile_build, with the other inputs
for (var _k = 0; _k < 3; _k++) {
    gmsa_profile_add_input(_p, gmsa_input_pull("kind_" + string(_k), method({ k : _k }, function(_agent, _target) {
        if (is_struct(_target)) return 0;  // wander points aren't coins
        return (_target.object_index == o_coin && _target.source == k) ? 1 : 0;
    }), 0, 1, true));
}
```

and add them to the features:

```gml
gmsa_profile_set_features(_p, ["hp", "distance", "kind_0", "kind_1", "kind_2"]);
```

**Keep a history, and report what happened.** Each goblin keeps a history of its decisions, and uses the shared model:

```gml
// o_goblin > Create (add, after the agent is created)
gmsa_learn_track(agent);
gmsa_agent_set_model(agent, global.loot_sense, 1);
ticket = undefined;
```

When it acts on a decision, it takes a **ticket** for it:

```gml
// o_goblin > Step, where it acts on a fresh decision
gmsa_agent_set_current_option(agent, _option);
ticket = gmsa_learn_remember(agent);
```

When it picks something up, the ticket gets the result:

```gml
// o_goblin > Step, on arrival, before instance_destroy(goal)
var _reward = 0.5;  // a potion is always fine
if (goal.object_index == o_coin) {
    var _bitten = (goal.source == global.cursed);
    if (_bitten) hp = max(0, hp - 20);
    _reward = _bitten ? -1 : 1;
}
if (ticket != undefined) gmsa_learn_outcome(global.loot_sense, ticket, _reward);
```

The arrival code already calls `gmsa_agent_clear_current` after a pickup. That matters here: it ends the decision, so the next coin, even of the same kind, is a new decision with its own ticket.

Run it. At first the goblins grab whatever is nearest and some get bitten. Every goblin shares one model, so every bite teaches all of them. After a few dozen pickups, the cursed kind sits untouched while the others are collected. The debug list shows `(designer ...)` next to the cursed coins, your scoring pushed down by what was learned. Restart the room and a different kind is cursed. They learn again from scratch, because nothing in the profile ever knew.

The copycat keeps its own model from [chapter 11](#11-learning-from-the-player). An agent uses one model at a time, and its Creation Code runs after Create, so its choice model wins.

Three things to remember:

- **Rewards are events.** Report them when something happens, roughly between -1 and 1. For damage over time, add it up and report it every half second or so. When you can't point to one decision, use `gmsa_learn_reward(model, agent, reward)`, and the goblin's recent decisions share the credit.
- **Agents learn about what they try.** These goblins use `BEST` selection, so they only learn about coins they'd pick anyway. That's enough here because the nearest coin keeps changing. To make agents experiment more, use `TOP_N_WEIGHTED` in the profile.
- **Give it the cause.** Without the `kind_` inputs, the goblins could only learn "coins are sometimes bad", never which ones.

The [API Reference](ApiReference.md#learning-from-outcomes) has ambient rewards, every model's outcome behavior and the costs.

---

## 14. Troubleshooting

**The agent stands still.**
Nothing could be chosen: every option was vetoed by a zero, on cooldown, or had no targets. Look at the debug list. If it shows `no selectable options`, add a fallback action like `wander` or an `idle` with a small weight.

**The agent ignores something it obviously should do.**
Find that option in the debug list and look at its considerations. One of them is near zero and dragging the score down. Fix that curve, see [Tuning](#8-tuning).

**The option doesn't appear in the debug list at all.**
It scored exactly zero (a vetoing consideration), its action is on cooldown, or its targets callback returned nothing. A `STEP` curve or a `LOGISTIC` shifted with `b` below zero can produce exact zeros on purpose.

**The agent flickers between two options.**
Set `commitment` on the profile, and call `gmsa_agent_set_current_option` when the agent starts acting on a choice. Without the second part, commitment has nothing to stick to.

**A decision I stored changed by itself.**
Decisions and options are reused by every think. Copy the fields you need instead of keeping the struct.

**A pull callback receives `undefined` as its target.**
The input isn't marked per target. Pass `true` as the last argument of `gmsa_input_pull`.

**`gmsa_profile_build` throws.**
That's intentional: configuration mistakes are caught at build time, not in the middle of gameplay. The message names the profile, the action and the problem, for example an unknown input name or a per-target input on an action without targets.

**The agent keeps deciding after its instance is gone.**
It's still in a scheduler. Call `gmsa_scheduler_remove` in the instance's Clean Up event.

**The copycat behaves like every other goblin.**
Either the model isn't confident yet (it needs a few dozen choices), the influence is 0, or there was only one option on offer, which learning can't reorder. Check that your choices are actually recorded: `global.taste.samples` should grow with every click.

**`gmsa_learn_observe` throws about features.**
The profile of the agent you observed through doesn't declare features. Add `gmsa_profile_set_features` before its build.

**An outcome model learns nothing.**
Check three things: the agent is tracked with `gmsa_learn_track`, it acts through `gmsa_agent_set_current_option` (that's what records a decision), and you report with `gmsa_learn_outcome` or `gmsa_learn_reward`, not `gmsa_learn_observe`.

**Every result lands on the same old decision.**
Clear the current option after a one-shot action (a pickup, a shot). Otherwise choosing the same action again continues the previous decision instead of starting a new one.

**A LambdaMART model has no effect.**
It hasn't trained yet. It only stores picks until `gmsa_learn_train` finishes, see [Choosing a Model](#12-choosing-a-model).

**A RankNet model learns nothing.**
Its `learn_rate` is too low for its `half_life`: old evidence fades faster than new evidence builds up. Raise one of them. The defaults are balanced, so this only happens after tuning.

**The model never makes the agent do something.**
That's the rule: it can only push options down. If your curves score that option at or near zero, see [Learning From the Player](#11-learning-from-the-player) on leaving room.

**My game's random results changed after adding GMSmartAgent.**
They shouldn't. GMSmartAgent uses its own random generator and never touches GameMaker's `random`. If your sequence changed, look elsewhere first.

**The game got slower with many agents.**
Check `scheduler.stats.time`. If it stays at or under the budget, GMSmartAgent isn't the cause: the cost is in your instances' own Step and Draw events, or in your input callbacks. Expensive callbacks (line of sight, path queries) count toward the budget, so the scheduler protects you from those too.

---

## Next Steps

- The [API Reference](ApiReference.md) covers every function, parameter and data structure.
- The scoring pipeline section there shows exactly how each score is calculated, step by step.