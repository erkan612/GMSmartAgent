# Chapter 10: Making It Stay Right

Utility AI rarely breaks in its code. It breaks in its numbers. You lower a weight to stop goblins staring at the player, and three days later notice that hurt goblins no longer flee, because fleeing only won by a narrow margin that the old weight happened to provide. Nothing crashed. Nothing warned you. The goblin just quietly became worse, and the only way to find out was to play until you happened to see it.

Tests fix that. A test sets up a situation, lets the agent decide once, and checks that it made the choice you wanted. A set of them takes a fraction of a second to run, and after any change you run them all: if a choice you cared about has changed, a test fails and tells you which one. This last Basic chapter covers GMSmartAgent's Test module: writing tests for the goblin, faking the world it lives in, the habits that make tests worth having, and testing things that depend on time without waiting for it.

---

## What a test checks

The idea is simple, and worth stating plainly because it decides what makes a good test:

**Given this situation, the agent should choose this.**

A badly hurt goblin with a potion in reach should drink. A healthy goblin with a coin nearby should loot. A goblin with nothing around should wander. Each of those is one test: a situation, and the choice it should lead to.

That's deliberately narrow. A test doesn't check that the goblin walks well, animates nicely or feels right; those are for playing. It checks **decisions**, which is exactly the part that tuning can break without anyone noticing. And because GMSmartAgent makes decisions from inputs alone, a decision can be tested without a room, without instances, and without running the game: give the agent a made-up situation and ask what it would do.

---

## Before testing: settle the numbers

Chapter 9 built the goblin's profile from a `global.tune` struct so it could be adjusted while the game ran. Tests need the profile to be the same every time they run, so once tuning is done, copy the values back into the profile as plain numbers:

```gml
var _too_close = gmsa_curve_make(gmsa_curve.LOGISTIC, { k : -12, c : 0.45 });
var _watch = gmsa_profile_add_action(_p, "watch", { weight : 0.08, targets : ... });
```

The tests in this chapter assume the tuning from Chapter 9's three problems: drinking uses the gentler distance curve, fear's middle is at 0.45, and watching weighs 0.08. Tuning more later is fine; when a test fails after tuning, it's telling you something changed, and the next section is about what to do with that.

---

## Making the goblin testable

There's one more change to make before writing a test, and it's a principle more than a fix.

Look at how the goblin's inputs find the player:

```gml
if (!instance_exists(o_player)) return 400;
var _o = _agent.owner;
return point_distance(_o.x, _o.y, o_player.x, o_player.y);
```

That reaches straight into the room for `o_player`. In a test there's no room, no player instance, and no way to put the player 150 pixels away. Inputs that read the world directly can only ever be tested by running the world.

Inputs that read **through the owner** don't have that problem. Give the goblin a variable for the thing it's afraid of, and have every input read that:

```gml
// o_goblin > Step, at the top
threat = instance_exists(o_player) ? instance_find(o_player, 0) : noone;
```

```gml
// o_goblin > Create (add)
threat = noone;
```

```gml
// __goblin_profile_build: the inputs that read the player
gmsa_profile_add_input(_p, gmsa_input_pull("player_distance", function(_agent, _target) {
    var _o = _agent.owner;
    var _t = _o.threat;
    if (!is_struct(_t) && !instance_exists(_t)) return 400;
    return point_distance(_o.x, _o.y, _t.x, _t.y);
}, 0, 400));

gmsa_profile_add_input(_p, gmsa_input_pull("player_to_target", function(_agent, _target) {
    var _t = _agent.owner.threat;
    if (!is_struct(_t) && !instance_exists(_t)) return 200;
    return point_distance(_t.x, _t.y, _target.x, _target.y);
}, 0, 200, true));
```

and the same for watching's targets:

```gml
targets : function(_agent) {
    var _t = _agent.owner.threat;
    return (is_struct(_t) || instance_exists(_t)) ? [_t] : [];
},
```

In the game, `threat` is the player instance and nothing changes. In a test, `threat` can be a struct, `{ x : 150, y : 0 }`, and the goblin is afraid of a point in space. The `is_struct` checks are what let both work.

The goblin's targets already go through the owner, with `find_nearest`, and its own state, `hp`, `x` and `y`, is read from the owner too. So the whole profile now asks the owner for everything it knows. That's the habit that makes agents testable: **an input reads the owner, and the owner reads the world.** It also turns out to be good design for its own sake: the goblin's knowledge of the player is now one variable, which is exactly where Chapter 3's fair senses, sight and memory, would plug in.

---

## A fake goblin

With every input reading the owner, a plain struct can stand in for a goblin. Here's a helper that builds one from a situation:

```gml
/// A struct that looks like a goblin to the profile, in a made-up situation.
function fake_goblin(_hp, _potions = [], _coins = [], _threat = noone) {
    return {
        hp : _hp,
        x : 0,
        y : 0,
        threat : _threat,
        potions : _potions,
        coins : _coins,
        wander_point : { x : 80, y : 0 },
        find_nearest : function(_object, _radius, _count) {
            return (_object == o_potion) ? potions : coins;
        },
    };
}
```

The fake goblin stands at 0, 0. Its `find_nearest` ignores the radius and simply returns the potions and coins you gave it, so each test decides exactly what's in range. Targets are structs too: a potion is `{ x : 100, y : 0 }`, a coin is `{ x : 60, y : 0, value : 1 }`. The profile can't tell the difference; it reads `x`, `y` and `value`, and doesn't care what they belong to.

---

## The first tests

Tests live in suites. A **suite** is a named group, a **case** is one test inside it. Create a script `Goblin_Tests`:

```gml
function goblin_tests() {
    gmsa_test_suite("Goblin", function() {

        gmsa_test_case("a healthy goblin loots", function() {
            var _g = fake_goblin(100, [{ x : 100, y : 0 }], [{ x : 60, y : 0, value : 1 }]);
            gmsa_test_scenario(goblin_profile(), _g, {}, "loot");
        });

        gmsa_test_case("a badly hurt goblin drinks, even past a closer coin", function() {
            var _g = fake_goblin(25, [{ x : 250, y : 0 }], [{ x : 60, y : 0, value : 1 }]);
            gmsa_test_scenario(goblin_profile(), _g, {}, "drink");
        });

        gmsa_test_case("a hurt goblin flees a close player", function() {
            var _g = fake_goblin(20, [], [{ x : 60, y : 0, value : 1 }], { x : 150, y : 0 });
            gmsa_test_scenario(goblin_profile(), _g, {}, "flee");
        });

        gmsa_test_case("with nothing around, it wanders", function() {
            gmsa_test_scenario(goblin_profile(), fake_goblin(100), {}, "wander");
        });
    });
}
```

`gmsa_test_scenario` is the core of profile testing. It creates an agent on the profile with your owner, sets any push inputs from the struct you give it (the goblin has none, so `{}`), thinks once, checks the decision is well-formed, and asserts that the chosen action has the name you expected. Pass `undefined` as the expected name to assert that nothing at all is selectable.

Each of these four cases is one sentence from the goblin's design, and the second and third are exactly the problems Chapter 9 fixed. If a future change brings either problem back, the test that describes it fails.

---

## Running them

Tests can run whenever you like. A simple arrangement is to run them when the game starts, but only while you're developing:

```gml
// o_controller > Create (add)
if (debug_mode) {
    goblin_tests();
    gmsa_test_run(true);
}
```

`debug_mode` is true when you run the game with GameMaker's debugger, so the tests run while you work and never in a release build. `gmsa_test_run(true)` runs every registered suite and prints a report to the output window:

```
[GMSA Test] Goblin
  PASS  a healthy goblin loots
  PASS  a badly hurt goblin drinks, even past a closer coin
  PASS  a hurt goblin flees a close player
  PASS  with nothing around, it wanders
[GMSA Test] 4 passed, 0 failed, 0 errors
```

With `false`, or no argument, only failures and the summary are printed, which is what you want once there are dozens of tests. `gmsa_test_run` also returns the counts, `{ passed, failed, errors, total }`, so a test room could show them on screen or stop the game when something fails.

Now break something on purpose. Put fear's middle back at 0.3 and run again:

```
[GMSA Test] Goblin
  FAIL  a hurt goblin flees a close player
       expected flee, got loot
[GMSA Test] 3 passed, 1 failed, 0 errors
```

The report names the case and what it expected. Because each case is one sentence of design, that line reads as plain English: a hurt goblin no longer flees a close player. Put the value back.

---

## Checking more than the action

`gmsa_test_scenario` checks the action's name, and returns the whole decision for anything else. The Chapter 5 promise, that a goblin won't reach for a coin under the player's feet, is about the **target**, not the action:

```gml
gmsa_test_case("it won't reach for a coin under the player's feet", function() {
    var _rich = { x : 60, y : 0, value : 5 };    // big and close, but the player is on it
    var _safe = { x : 150, y : 0, value : 1 };   // small and farther, but nobody near
    var _g = fake_goblin(100, [], [_rich, _safe], { x : 60, y : 10 });
    var _d = gmsa_test_scenario(goblin_profile(), _g, {}, "loot");
    gmsa_test_assert_true(gmsa_decision_get_chosen(_d).target == _safe, "took the safe coin");
});
```

The assertions available for anything you want to check:

| Assertion | Passes when |
| --- | --- |
| `gmsa_test_assert_true(cond, [msg])` | `cond` is true |
| `gmsa_test_assert_false(cond, [msg])` | `cond` is false |
| `gmsa_test_assert_equal(actual, expected, [msg])` | They're equal; arrays are compared by content |
| `gmsa_test_assert_near(actual, expected, [tolerance], [msg])` | Within `tolerance`, 0.0001 by default |
| `gmsa_test_assert_range(value, min, max, [msg])` | `min <= value <= max` |
| `gmsa_test_assert_throws(func, [msg])` | Calling `func` throws an error |
| `gmsa_test_assert_decision(decision, [msg])` | The decision is well-formed |

A failed assertion records its message and the case carries on, so one case can report several problems at once. Each assertion also returns whether it passed, so a case can stop early when there's no point going on:

```gml
var _chosen = gmsa_decision_get_chosen(_d);
if (!gmsa_test_assert_true(_chosen != undefined, "something was chosen")) return;
gmsa_test_assert_true(_chosen.target == _safe);
```

An error inside a case, like reading a field of `undefined`, doesn't stop the run either: the case is marked as an error with the message, and the other cases still run.

---

## Testing where the switch happens

Some of the most useful tests don't check one situation but a boundary: where the goblin changes its mind. With a potion and a coin both 100 pixels away, the goblin should loot at 40 health and drink at 35:

```gml
gmsa_test_case("it switches from loot to drink between 40 and 35 health", function() {
    var _expect = [[60, "loot"], [40, "loot"], [35, "drink"], [20, "drink"]];
    for (var _i = 0; _i < array_length(_expect); _i++) {
        var _hp = _expect[_i][0];
        var _g = fake_goblin(_hp, [{ x : 100, y : 0 }], [{ x : 100, y : 0, value : 1 }]);
        gmsa_test_scenario(goblin_profile(), _g, {}, _expect[_i][1], "at " + string(_hp) + " hp");
    }
});
```

The last argument of `gmsa_test_scenario` is a message prefix, so a failure says which health it failed at: `at 35 hp: expected drink, got loot`. A test like this pins down the shape of a behavior, not just one point of it. If someone later makes thirst kick in at 50, or not until 20, this fails and shows exactly where the boundary moved.

Boundary tests are also where you'll most often change the test rather than the profile. If you *meant* to make the goblin drink earlier, the failure is the test doing its job: it noticed the change, and you update the numbers in the test to the new design. A failing test means "this changed", and only you know whether that's a bug or the point.

---

## Testing the cycle: commitment

`gmsa_test_scenario` thinks once, from scratch. Some behavior only shows up across thinks, like commitment. For that, drive an agent yourself:

```gml
gmsa_test_case("it sticks with its coin when a slightly better one appears", function() {
    var _first = { x : 100, y : 0, value : 1 };
    var _g = fake_goblin(100, [], [_first]);
    var _agent = gmsa_agent_create(goblin_profile(), _g);

    var _d = gmsa_agent_think(_agent, 0, gmsa_rng_create(1));
    gmsa_agent_set_current_option(_agent, gmsa_decision_get_chosen(_d));

    var _second = { x : 95, y : 0, value : 1 };   // a few pixels closer
    _g.coins = [_first, _second];
    _d = gmsa_agent_think(_agent, 0, gmsa_rng_create(1));
    gmsa_test_assert_true(gmsa_decision_get_chosen(_d).target == _first, "kept its coin");
});
```

The first think picks the only coin, and the goblin commits to it, exactly as its Step event would. Then a slightly closer coin appears, and the second think must still choose the first. Remove commitment from the profile and this test fails: that's Chapter 6's dithering, caught without playing.

`gmsa_agent_think` takes two optional arguments here, the time and a random generator. Passing a fixed time and a freshly seeded generator makes the think exactly repeatable, which is what `gmsa_test_scenario` does internally too. Chapter 8 explained why GMSmartAgent never uses GameMaker's own `random`: this is where that pays off. The same situation always gives the same decision, so a test that passes once passes every time.

---

## Testing time without waiting

Some things depend on time: the scheduler's budget, cooldowns, intervals. Testing them against the real clock would be slow and unreliable. The Test module has a **fake clock** instead: a function that returns whatever time you say, and can move forward by itself every time it's read:

```gml
gmsa_test_case("the scheduler stays inside its budget", function() {
    var _clock = gmsa_test_clock(0, 300);   // starts at 0, each reading adds 300 microseconds
    var _ai = gmsa_scheduler_create(2000, { clock : _clock.fn });
    repeat (50) gmsa_scheduler_add(_ai, gmsa_agent_create(goblin_profile(), fake_goblin(100)));

    gmsa_scheduler_step(_ai);
    gmsa_test_assert_true(_ai.stats.thinks < 50, "stopped before thinking for everyone");
    gmsa_test_assert_true(_ai.stats.stopped, "knew the budget ran out");
});
```

With every reading of the clock adding 300 microseconds, the scheduler sees its 2 milliseconds run out after a handful of thinks, however fast the computer actually is. The test checks that it stopped, and that it said so. Change `clock.now` yourself to jump forward in time, for testing intervals and cooldowns, and `clock.calls` tells you how often the clock was read.

---

## Counting calls

One more helper. `gmsa_test_stub` is a stand-in for a callback that counts how often it's called. It's useful for checking claims about cost, like Chapter 3's promise that a pull input is read once per think, however many actions consider it:

```gml
gmsa_test_case("an input is read once per think", function() {
    var _hp = gmsa_test_stub(50);   // always returns 50
    var _p = gmsa_profile_create("stub test");
    gmsa_profile_add_input(_p, gmsa_input_pull("hp", _hp.fn, 0, 100));
    var _a = gmsa_profile_add_action(_p, "a");
    gmsa_action_add_consideration(_a, "hp", gmsa_curve_make(gmsa_curve.LINEAR));
    var _b = gmsa_profile_add_action(_p, "b");
    gmsa_action_add_consideration(_b, "hp", gmsa_curve_make(gmsa_curve.LINEAR));
    _p = gmsa_profile_build(_p);

    gmsa_agent_think(gmsa_agent_create(_p, {}));
    gmsa_test_assert_equal(_hp.calls, 1);
});
```

The same technique checks your own profiles: that an expensive input isn't read more than you think, or that a targets function isn't called at all when its action is switched off.

---

## Habits that make tests worth having

- **One sentence per case.** Name each case after the design it protects: "a hurt goblin flees a close player". When it fails, the name is the bug report.
- **Test what you care about, not everything.** A test for every number in the profile breaks on every change and teaches you to ignore failures. A test for every behavior a player would notice is exactly right.
- **Write a test when you fix something.** Every problem found in Chapter 9's way, by watching and reading the list, becomes a test the moment it's fixed. It can't come back unnoticed.
- **Keep the fake world small.** One or two targets, at round distances, is easier to reason about than a busy scene, and if the test fails you can work the scores out by hand, the way Chapter 9 did.
- **Run them after every change.** They cost a fraction of a second. The habit is the whole point.
- **A failure is information, not a verdict.** It says a decision changed. Whether that's a bug or the change you meant is your call: fix the profile, or update the test.

---

## What tests don't catch

Tests check decisions in situations you thought of. They don't check situations you didn't think of, and they don't check feel: whether the goblin's walk looks natural, whether its reaction time reads well, whether a choice that's technically right looks odd on screen. Those still need playing and watching, with Chapter 9's tools. Tests and watching cover each other: watching finds problems, tests keep them fixed.

---

## Try this

- **Pin down fear.** Write a boundary test for fleeing, like the loot-to-drink one: a hurt goblin, the player at 100, 150, 200 and 250 pixels. Find where it stops fleeing and fix the numbers into the test.
- **Protect the fallbacks.** Write a test that a goblin with nothing around never chooses `idle`, and one that, with wander switched off, it does.
- **A dithering test.** Extend the commitment test: the second coin appears 20% closer instead of a few pixels. The goblin should switch. Find the distance where it starts switching.
- **Break, then fix.** Change one number in the profile, run the tests, read the failures, and work out from them alone what you changed.

---

## What you've learned

- A test says: given this situation, the agent should choose this. Tests check decisions, the part tuning breaks silently.
- Settle tuning values into the profile before testing.
- Inputs that read **through the owner** can be tested with a plain struct; inputs that reach into the room can't. The owner reads the world, the profile reads the owner.
- `gmsa_test_suite` groups cases, `gmsa_test_case` declares one, and `gmsa_test_run` runs them and prints a report. Run them in debug builds, after every change.
- `gmsa_test_scenario` creates an agent, thinks once with a fixed seed, checks the decision and asserts the chosen action, and returns the decision for further checks.
- Boundary tests pin down where behavior changes. Driving an agent yourself tests behavior across thinks, like commitment. Fake clocks test time without waiting, and stubs count calls.
- Name cases after the design they protect, write one for every fix, and treat a failure as "this changed", not "this is wrong".

---

## The end of the Basic part

That's the foundation. Over ten chapters the goblin has gone from a single comparison between two numbers to an agent that weighs its health, its thirst, its fear and the value and danger of every coin; acts on its choices and commits to them; never stands frozen; shares a time budget with a room full of others; shows its reasoning on screen; and has its behavior locked in by tests.

Everything in GMSmartAgent builds on what these chapters covered: options and scores, considerations and curves, inputs and targets, the think and act cycle, the scheduler, the debug view and tests. The **Advanced** chapters each take one question from here, from "how do I give agents personality?" to "how do I make a boss that learns my habits?" to "how do I plan a raid on a locked chest?", and answer it on its own, with its own context. Pick whichever one you need; the [index](README.md) lists them all.