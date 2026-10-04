# GMSmartAgent API Reference

Complete reference for every public function, enum and data structure in GMSmartAgent v1.0.

---

## Contents

- [Conventions](#conventions)
- [Enums](#enums)
- [Curves](#curves)
- [Inputs](#inputs)
- [Profiles and Actions](#profiles-and-actions)
- [Agents](#agents)
- [Thinking and Decisions](#thinking-and-decisions)
- [Observe](#observe)
- [Scheduler](#scheduler)
- [Random Generator](#random-generator)
- [Debug](#debug)
- [Test](#test)
- [Data Structures](#data-structures)
- [Callback Signatures](#callback-signatures)
- [Scoring Pipeline](#scoring-pipeline)

---

## Conventions

- **Time is always in microseconds**, the same unit as `get_timer()`. This covers budgets, intervals, cooldowns and decision times. One second is `1000000`.
- **Names or indices.** Functions that take an input or an action accept either its name (a string) or its index (a number). Names are convenient, indices skip a lookup. Use `gmsa_profile_input_index` and `gmsa_profile_action_index` to cache an index once.
- **Normalized values.** Every input is mapped to 0..1 before it reaches a curve, and every curve returns 0..1.
- **Errors.** Configuration mistakes throw a string starting with `GMSA:`. They are thrown when you build or configure, so they surface early instead of during gameplay.
- **Internal names.** Functions and fields starting with `__` are internal. Don't call or change them, they can change between versions.
- **Read-only fields.** Struct fields documented under [Data Structures](#data-structures) can be read freely. Change them only through the functions in this reference.

---

## Enums

### gmsa_curve
Response curve types, see [Curves](#curves).

| Element | Meaning |
| --- | --- |
| `gmsa_curve.LINEAR` | Straight line |
| `gmsa_curve.POWER` | Power curve: quadratic, root, U shape |
| `gmsa_curve.LOGISTIC` | S-shaped curve |
| `gmsa_curve.STEP` | Hard threshold |
| `gmsa_curve.CUSTOM` | Your own function or animation curve |

### gmsa_source
Where an input's value comes from.

| Element | Meaning |
| --- | --- |
| `gmsa_source.PULL` | GMSmartAgent calls your callback when the agent thinks |
| `gmsa_source.PUSH` | You feed the value with `gmsa_agent_set_input` |

### gmsa_select
How a profile picks among its ranked options.

| Element | Meaning |
| --- | --- |
| `gmsa_select.BEST` | Always the highest score |
| `gmsa_select.TOP_N_WEIGHTED` | Weighted random among the top N options |

### gmsa_chooser
Who made a decision.

| Element | Meaning |
| --- | --- |
| `gmsa_chooser.AGENT` | The agent's own think |
| `gmsa_chooser.OBSERVED` | A choice recorded with `gmsa_observe` |

### gmsa_test_status
Result of a test case, see [Test](#test).

| Element | Meaning |
| --- | --- |
| `gmsa_test_status.PASS` | Every assertion passed |
| `gmsa_test_status.FAIL` | At least one assertion failed |
| `gmsa_test_status.ERROR` | The case threw an error |

---

## Curves

A curve maps a normalized input (0..1) to a normalized output (0..1). Every curve type shares the same four parameters, so switching types never means relearning a parameter set.

### gmsa_curve_make

```gml
gmsa_curve_make(type, [params]) -> curve
```

Creates a curve. Missing parameters use the type's defaults.

| Parameter | Type | Description |
| --- | --- | --- |
| `type` | `gmsa_curve` | Curve type |
| `params` | struct | Optional, see below |

| Param | Meaning | LINEAR | POWER | LOGISTIC | STEP |
| --- | --- | --- | --- | --- | --- |
| `m` | Scale | 1 | 1 | 1 | 1 |
| `k` | Shape (exponent or steepness) | 1 | 2 | 10 | 1 |
| `b` | Vertical shift | 0 | 0 | 0 | 0 |
| `c` | Horizontal shift (threshold for STEP, midpoint for LOGISTIC) | 0 | 0 | 0.5 | 0.5 |
| `invert` | Flip the output (`1 - y`) | false | false | false | false |

`CUSTOM` curves take one of these instead:

| Param | Meaning |
| --- | --- |
| `func` | `function(x)` returning y |
| `animcurve` | An animation curve asset |
| `channel` | Channel index or name of `animcurve`, default 0 |

**Formulas**, with `x` the clamped input:

| Type | Formula |
| --- | --- |
| `LINEAR` | `y = m * (x - c) + b` |
| `POWER` | `y = m * (x - c)^k + b` (a negative base with a fractional `k` keeps its sign instead of becoming NaN) |
| `LOGISTIC` | `y = m / (1 + e^(-k * (x - c))) + b` |
| `STEP` | `y = (x >= c ? m : 0) + b` |
| `CUSTOM` | `y = func(x)`, or the animation curve channel evaluated at `x` |

**Throws** when the type is unknown, when a `CUSTOM` curve has neither a callable `func` nor an `animcurve`, or when `animcurve` doesn't exist.

**Common shapes**

```gml
gmsa_curve_make(gmsa_curve.LINEAR, { m : -1, b : 1 });       // descending: 1 at x=0, 0 at x=1
gmsa_curve_make(gmsa_curve.POWER);                            // quadratic, slow start
gmsa_curve_make(gmsa_curve.POWER, { k : 0.5 });               // root, fast start
gmsa_curve_make(gmsa_curve.POWER, { m : 4, c : 0.5 });        // U shape, 0 in the middle
gmsa_curve_make(gmsa_curve.LOGISTIC, { k : 20, c : 0.3 });    // sharp rise around 0.3
gmsa_curve_make(gmsa_curve.STEP, { c : 0.5 });                // 0 below 0.5, 1 from 0.5
gmsa_curve_make(gmsa_curve.STEP, { invert : true });          // 1 below 0.5, 0 from 0.5
```

### gmsa_curve_eval

```gml
gmsa_curve_eval(curve, x) -> real
```

Evaluates a curve.

| Parameter | Type | Description |
| --- | --- | --- |
| `curve` | curve | From `gmsa_curve_make` |
| `x` | real | Input, clamped to 0..1 |

**Returns** a value in 0..1. The output is clamped, then inverted if `invert` is set. A non-numeric or NaN result becomes 0, also when inverted.

---

## Inputs

An input is a named value source. The profile's input order is fixed at build time.

### gmsa_input_pull

```gml
gmsa_input_pull(name, callback, [min], [max], [per_target]) -> input
```

Creates a pull input. GMSmartAgent calls `callback` only when the agent actually thinks, and caches the result for the rest of that think.

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `name` | string | | Unique within the profile |
| `callback` | function | | `function(agent, target)` returning a raw value |
| `min` | real | 0 | Raw value that maps to 0 |
| `max` | real | 1 | Raw value that maps to 1 |
| `per_target` | bool | false | True if the value depends on the target |

- A per-target input is evaluated once per target per think, others once per think. For non-per-target inputs, `target` is `undefined`.
- `min` can be greater than `max`, which reverses the mapping.
- A per-target input can only be used by actions that have a `targets` callback.

**Throws** when `name` is empty, `callback` isn't callable, or `min` equals `max`.

### gmsa_input_push

```gml
gmsa_input_push(name, [min], [max], [default]) -> input
```

Creates a push input. You set its raw value with `gmsa_agent_set_input`. Use push for values your game already has at no cost.

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `name` | string | | Unique within the profile |
| `min` | real | 0 | Raw value that maps to 0 |
| `max` | real | 1 | Raw value that maps to 1 |
| `default` | real | `min` | Raw value until you set one |

**Throws** when `name` is empty or `min` equals `max`.

### gmsa_input_normalize

```gml
gmsa_input_normalize(input, raw) -> real
```

Maps a raw value to 0..1 using the input's range: `(raw - min) / (max - min)`, clamped. A non-numeric or NaN value becomes 0. GMSmartAgent calls this internally, it's public for debugging and custom tools.

---

## Profiles and Actions

A profile holds the inputs and actions shared by many agents. Build it once, then it's locked.

### gmsa_profile_create

```gml
gmsa_profile_create(name, [params]) -> profile
```

| Param | Type | Default | Description |
| --- | --- | --- | --- |
| `select` | `gmsa_select` | `BEST` | Selection policy |
| `top_n` | integer | 3 | How many top options `TOP_N_WEIGHTED` draws from |
| `commitment` | real | 0 | Bonus for the option the agent is currently doing, `0.15` means +15% |

### gmsa_profile_add_input

```gml
gmsa_profile_add_input(profile, input) -> input
```

Adds an input made with `gmsa_input_pull` or `gmsa_input_push`. Its position is its index.

**Throws** if the profile is already built.

### gmsa_profile_add_action

```gml
gmsa_profile_add_action(profile, name, [params]) -> action
```

Adds an action and returns it, so you can add considerations to it.

| Param | Type | Default | Description |
| --- | --- | --- | --- |
| `weight` | real | 1 | Multiplier on the final score, 0 or more |
| `cooldown` | real | 0 | Microseconds before the action can be picked again, counted from when it's chosen |
| `targets` | function | undefined | `function(agent)` returning an array of targets, see below |

- **Without `targets`**, the action produces one option with no target.
- **With `targets`**, it produces one option per target. Returning `undefined` skips the action for this think. Returning an empty array produces no options.
- **An action with no considerations** scores its weight. Use this for a baseline like `idle`.

**Throws** if the profile is already built or `name` is empty.

### gmsa_action_add_consideration

```gml
gmsa_action_add_consideration(action, input_name, curve) -> action
```

Adds a consideration: the named input passed through a curve. The name is checked at build time, so inputs can be added in any order.

**Throws** if the action belongs to a built profile.

### gmsa_profile_build

```gml
gmsa_profile_build(profile) -> profile
```

Validates the profile, resolves names to indices and locks it. Nothing is changed unless the whole profile is valid.

**Throws** when:
- the profile has no actions
- two inputs or two actions share a name
- a consideration uses an unknown input, or has no curve
- a per-target input is used by an action without a `targets` callback
- an action's weight or cooldown is negative, or `targets` isn't callable
- `select` is unknown, `top_n` is below 1, or `commitment` is negative
- the profile is already built

### gmsa_profile_input_index

```gml
gmsa_profile_input_index(profile, name) -> integer
```

**Returns** the input's index, or -1 if there's no input with that name.

### gmsa_profile_action_index

```gml
gmsa_profile_action_index(profile, name) -> integer
```

**Returns** the action's index, or -1 if there's no action with that name.

---

## Agents

An agent holds per-instance state only. Many agents can share one profile.

### gmsa_agent_create

```gml
gmsa_agent_create(profile, [owner], [params]) -> agent
```

| Parameter | Type | Description |
| --- | --- | --- |
| `profile` | profile | A built profile |
| `owner` | any | Your instance or struct, reachable from callbacks as `agent.owner` |

| Param | Type | Default | Description |
| --- | --- | --- | --- |
| `priority` | real | 0 | Scheduler tier, higher thinks first |
| `interval` | real | 0 | Minimum microseconds between thinks |
| `on_decide` | function | undefined | `function(agent)`, called by the scheduler after each think |

The agent's cache and option pool are allocated here, so its first think doesn't allocate.

**Throws** when the profile isn't built or `on_decide` isn't callable.

### gmsa_agent_set_input

```gml
gmsa_agent_set_input(agent, input, value)
```

Sets a push input's raw value. `input` is a name or an index.

**Throws** when the input is unknown or is a pull input.

### gmsa_agent_set_current

```gml
gmsa_agent_set_current(agent, action, [target])
```

Tells GMSmartAgent what the agent is currently doing, so the matching option gets the profile's commitment bonus. `action` is a name or an index. Call it when the agent starts acting on a decision.

**Throws** when the action is unknown.

### gmsa_agent_set_current_option

```gml
gmsa_agent_set_current_option(agent, option)
```

Same as `gmsa_agent_set_current`, but takes an option straight from a decision. This is the usual way to call it:

```gml
gmsa_agent_set_current_option(agent, gmsa_decision_get_chosen(decision));
```

The action and target are copied, so later thinks reusing the option struct don't affect it. Passing `undefined` clears the current option.

**Throws** when the option comes from a different profile.

### gmsa_agent_clear_current

```gml
gmsa_agent_clear_current(agent)
```

Clears the current option, for example when the agent finished or abandoned what it was doing.

### gmsa_agent_consume

```gml
gmsa_agent_consume(agent) -> decision or undefined
```

**Returns** the agent's decision if it's fresh and marks it consumed, otherwise `undefined`. This is the standard way to react to decisions made by a scheduler:

```gml
var _decision = gmsa_agent_consume(agent);
if (_decision != undefined) {
    var _option = gmsa_decision_get_chosen(_decision);
    if (_option != undefined) {
        gmsa_agent_set_current_option(agent, _option);
        // act on it
    }
}
```

### Destroying an agent

Agents are plain structs and are garbage collected. If the agent is in a scheduler, remove it first with `gmsa_scheduler_remove`, usually in the owner's Clean Up event. Otherwise the scheduler keeps it thinking for an owner that no longer exists.

---

## Thinking and Decisions

### gmsa_agent_think

```gml
gmsa_agent_think(agent, [now], [rng]) -> decision
```

Runs one think immediately and returns the agent's decision. Schedulers call this for you. Call it yourself for agents outside a scheduler, such as a single boss or a turn-based game.

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `now` | real | `get_timer()` | Current time in microseconds, used for cooldowns and the decision time |
| `rng` | rng | agent's generator | Generator for weighted selection |

- Without `rng`, the agent's scheduler generator is used, or an internal default generator for agents outside a scheduler. GameMaker's own `random` is never touched.
- `on_decide` is **not** called here, only by schedulers.
- The decision is marked fresh.

### gmsa_decision_get_chosen

```gml
gmsa_decision_get_chosen(decision) -> option or undefined
```

**Returns** the chosen option, or `undefined` when nothing was selectable (every option was vetoed, on cooldown, or had no targets).

### Decisions are reused

Each agent owns **one** decision struct, overwritten by every think, and its option structs are reused from a pool. This keeps thinking free of allocations. A reference you keep to a decision or an option will change on the next think, so copy the fields you need (the action name, the target) instead of keeping the struct.

---

## Observe

### gmsa_observe

```gml
gmsa_observe(agent, options, chosen, [now]) -> decision
```

Records a decision someone else made, usually the player, in the same shape as an agent's own decision. This is the foundation for learning from player choices.

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `agent` | agent | | The agent representing the observed decision-maker |
| `options` | array | | The options that were on offer |
| `chosen` | integer | | Index into `options` of the one that was picked |
| `now` | real | `get_timer()` | Time of the choice |

Each entry in `options` is an action (name or index) for targetless actions, or a struct `{ action, target }`.

Differences from a think:
- **Nothing is dropped.** Options scoring 0 stay, and every consideration is evaluated even after a veto.
- **The order you passed is kept**, so `chosen` means exactly what you passed.
- **Cooldowns, commitment and the agent's think time are untouched.**
- The chosen option's probability is 1, the others 0.

It writes into the agent's decision, so give each observed decision-maker its own agent rather than reusing one that also thinks.

```gml
// the player bought the second item in the shop
gmsa_observe(player_agent, [
    { action : "buy", target : shop_item[0] },
    { action : "buy", target : shop_item[1] },
    { action : "buy", target : shop_item[2] },
], 1);
```

**Throws** when `options` is empty, `chosen` is out of range, an action is unknown, or a targeted action has no target.

---

## Scheduler

A scheduler runs agent thinks within a time budget per step. You create schedulers yourself, there's no global one.

### gmsa_scheduler_create

```gml
gmsa_scheduler_create([budget], [params]) -> scheduler
```

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `budget` | real | 2000 | Microseconds of thinking per step |

| Param | Type | Default | Description |
| --- | --- | --- | --- |
| `seed` | real | 1 | Seed of the scheduler's random generator |
| `clock` | function | `get_timer` | Time source returning microseconds |

**Throws** when `budget` is negative or `clock` isn't callable.

### gmsa_scheduler_add

```gml
gmsa_scheduler_add(scheduler, agent) -> agent
```

Adds an agent. Its `priority` picks the tier, and it starts using the scheduler's random generator. The agent thinks on the next step.

- An agent can be in one scheduler at a time.
- Priority is read when the agent is added. To change it later, use `gmsa_scheduler_set_priority`.

**Throws** when the agent is already in a scheduler.

### gmsa_scheduler_remove

```gml
gmsa_scheduler_remove(scheduler, agent) -> bool
```

Removes an agent. It returns to the default random generator. Safe to call from `on_decide`.

**Returns** false if the agent wasn't in this scheduler.

### gmsa_scheduler_set_priority

```gml
gmsa_scheduler_set_priority(scheduler, agent, priority) -> bool
```

Changes an agent's priority and moves it to the matching tier, at the end of that tier's turn order. Its interval timing is kept. Use it to promote agents near the player and demote distant ones.

**Returns** false if the agent isn't in this scheduler.

### gmsa_scheduler_step

```gml
gmsa_scheduler_step(scheduler) -> integer
```

Runs due agents until the budget is spent, then fires queued `on_decide` callbacks. Call it once per step.

- Tiers run highest priority first. Within a tier, agents take turns, and the next step continues where this one stopped.
- An agent is due when it has never thought, or when `interval` has passed since its last think.
- The clock is checked before every think except the first, so **every step thinks at least once** when an agent is due, even with a budget of 0. A step can overshoot the budget by at most one think.
- Every think in a step uses the same time, read once at the start.
- `on_decide` callbacks run after the timed loop, so your code never eats into the budget, and a callback can safely remove agents.

**Returns** the number of thinks this step.

Statistics of the last step are in `scheduler.stats`:

| Field | Meaning |
| --- | --- |
| `thinks` | Thinks run |
| `time` | Microseconds spent, callbacks excluded |
| `stopped` | True if the budget ran out before every due agent thought |

### gmsa_scheduler_count

```gml
gmsa_scheduler_count(scheduler) -> integer
```

**Returns** the number of agents in the scheduler.

### gmsa_scheduler_set_budget

```gml
gmsa_scheduler_set_budget(scheduler, budget)
```

Changes the budget in microseconds. **Throws** when negative.

### gmsa_scheduler_set_seed

```gml
gmsa_scheduler_set_seed(scheduler, seed)
```

Reseeds the scheduler's random generator. Same seed and same inputs give the same decisions.

### gmsa_scheduler_set_clock

```gml
gmsa_scheduler_set_clock(scheduler, clock)
```

Replaces the time source, a function returning microseconds. Tests use this with `gmsa_test_clock`. **Throws** when not callable.

---

## Random Generator

A small seedable generator (xorshift32). GMSmartAgent uses it for all of its randomness and never touches GameMaker's global random state, so your game's seeded sequences and replays stay intact.

### gmsa_rng_create

```gml
gmsa_rng_create([seed]) -> rng
```

Creates a generator, default seed 1. A seed of 0 is replaced internally, since xorshift can't run from 0.

### gmsa_rng_seed

```gml
gmsa_rng_seed(rng, seed)
```

Reseeds a generator.

### gmsa_rng_next

```gml
gmsa_rng_next(rng) -> real
```

**Returns** the next value in [0, 1).

---

## Debug

### gmsa_debug_lines

```gml
gmsa_debug_lines(decision, [max], [namer]) -> array of strings
```

One line per option, up to `max` (default 8), plus a line counting the rest. Each line shows a `>` marker on the chosen option, the score, the probability, the action, the target, and every consideration's curved value:

```
> 0.884  p1.00  heal @ ref instance 100004  [distance 0.97, missing_hp 0.64]
  0.580  p0.00  pick_up @ ref instance 100002  [distance 0.97]
```

`namer` is an optional `function(target)` returning text for a target. Without it, struct targets show as `struct` and anything else through `string()`.

### gmsa_debug_explain

```gml
gmsa_debug_explain(decision, [max], [namer]) -> string
```

The same lines joined with newlines.

### gmsa_debug_draw

```gml
gmsa_debug_draw(decision, x, y, [max], [namer]) -> real
```

Draws the lines at `x, y`, the chosen option in green, followed by any invariant violations in red. Restores the draw colour afterwards. Call it in a Draw or Draw GUI event.

**Returns** the height drawn, so several agents can be stacked.

---

## Test

The Test module ships with GMSmartAgent so you can test your own profiles. It depends on Core, Core never depends on it.

### Runner

#### gmsa_test_suite

```gml
gmsa_test_suite(name, func)
```

Registers a suite. `func` runs during `gmsa_test_run` and declares its cases with `gmsa_test_case`.

#### gmsa_test_case

```gml
gmsa_test_case(name, func)
```

Declares and runs one case. Call it inside a suite function. An error thrown inside `func` marks the case as `ERROR` instead of stopping the run.

#### gmsa_test_run

```gml
gmsa_test_run([verbose]) -> summary
```

Runs every registered suite and prints a report to the output. With `verbose` false (the default), only failures, errors and the summary are printed.

**Returns** `{ passed, failed, errors, total }`.

#### gmsa_test_report

```gml
gmsa_test_report([verbose]) -> summary
```

Prints the results of the last run again.

#### gmsa_test_clear

```gml
gmsa_test_clear()
```

Removes all registered suites and results.

### Assertions

Each assertion returns true on pass and false on fail, so a case can stop early with `if (!gmsa_test_assert_...) return;`. A failure records a message and the case continues. `msg` is optional and prefixes the failure message.

| Function | Passes when |
| --- | --- |
| `gmsa_test_assert_true(cond, [msg])` | `cond` is true |
| `gmsa_test_assert_false(cond, [msg])` | `cond` is false |
| `gmsa_test_assert_equal(actual, expected, [msg])` | Equal; arrays compared by content |
| `gmsa_test_assert_near(actual, expected, [tolerance], [msg])` | Within `tolerance`, default 0.0001 |
| `gmsa_test_assert_range(value, min, max, [msg])` | `min <= value <= max` |
| `gmsa_test_assert_throws(func, [msg])` | Calling `func` throws |
| `gmsa_test_assert_decision(decision, [msg])` | No invariant violations, see below |

### Helpers

#### gmsa_test_stub

```gml
gmsa_test_stub(value) -> stub
```

A callback stand-in that counts its calls. Pass `stub.fn` as a pull input or targets callback and read `stub.calls`. If `value` is a method (an anonymous function), it's called with `(agent, target)`, otherwise it's returned as is.

```gml
var _dist = gmsa_test_stub(0.5);
gmsa_profile_add_input(_p, gmsa_input_pull("dist", _dist.fn));
// ... think ...
gmsa_test_assert_equal(_dist.calls, 1);
```

#### gmsa_test_clock

```gml
gmsa_test_clock([start], [per_call]) -> clock
```

A fake clock for schedulers. Pass `clock.fn` to `gmsa_scheduler_create` or `gmsa_scheduler_set_clock`. Each read returns `clock.now` and then advances it by `per_call`. Move time yourself by changing `clock.now`. `clock.calls` counts reads.

#### gmsa_test_decision_problems

```gml
gmsa_test_decision_problems(decision) -> array of strings
```

Checks a decision's invariants and returns every violation, an empty array when valid:
- `chosen` is a valid index, or -1 when there are no options
- scores are positive (0 or more for observed decisions)
- agent decisions are ranked high to low
- every option has one feature per consideration, each in 0..1
- probabilities are in 0..1 and sum to 1
- the chosen option has a probability above 0

The Debug module uses this to show violations in red.

#### gmsa_test_scenario

```gml
gmsa_test_scenario(profile, owner, push, expected, [msg]) -> decision
```

The profile test. Creates an agent on `profile` with `owner` as its owner, sets push inputs from `push` (a struct of input name to raw value), thinks once with a fixed seed, checks the invariants, and asserts that the chosen action is named `expected`. Pass `undefined` as `expected` to assert that nothing is selectable.

Pull callbacks read `agent.owner`, so a plain struct can stand in for your game object:

```gml
gmsa_test_case("hurt enemy heals", function() {
    var _owner = {
        hp : 20, hp_max : 100, x : 0, y : 0,
        find : function(_object) { return [{ x : 10, y : 0 }]; },  // a fake target 10 px away
    };
    gmsa_test_scenario(enemy_profile(), _owner, {}, "heal");
});
```

**Returns** the decision for further checks.

---

## Data Structures

Fields you can read. Fields starting with `__` are internal.

### Profile

| Field | Description |
| --- | --- |
| `name` | Profile name |
| `inputs` | Array of inputs, in index order |
| `actions` | Array of actions, in index order |
| `select`, `top_n`, `commitment` | Selection settings |
| `built` | True once built |
| `model`, `influence`, `model_inputs` | Reserved for the Learn module |

### Input

| Field | Description |
| --- | --- |
| `name` | Input name |
| `source` | `gmsa_source` |
| `callback` | Pull callback, undefined for push |
| `min`, `max` | Normalization range |
| `per_target` | True if evaluated per target |
| `default_value` | Starting raw value of a push input |

### Action

| Field | Description |
| --- | --- |
| `name` | Action name |
| `index` | Position in the profile, set at build |
| `weight`, `cooldown`, `targets` | As given to `gmsa_profile_add_action` |
| `considerations` | Array of `{ input, curve, input_index }` |

### Agent

| Field | Description |
| --- | --- |
| `profile` | The agent's profile |
| `owner` | Your instance or struct |
| `priority`, `interval`, `on_decide` | As given to `gmsa_agent_create` |
| `push` | Raw push values, indexed like the profile's inputs |
| `cooldowns` | Time each action is ready again, indexed like the profile's actions |
| `current` | `{ action, target }` set by `gmsa_agent_set_current`, or undefined |
| `last_think` | Time of the last think, undefined before the first |
| `rng` | The generator in use, undefined outside a scheduler |
| `decision` | The agent's decision |
| `model` | Reserved for the Learn module |

### Decision

| Field | Description |
| --- | --- |
| `agent` | The agent that owns it |
| `chooser` | `gmsa_chooser.AGENT` or `gmsa_chooser.OBSERVED` |
| `time` | Time of the think or observation |
| `options` | Array of options. Ranked high to low for agent decisions, in your order for observed ones |
| `chosen` | Index into `options`, -1 when nothing was selectable |
| `fresh` | True until consumed with `gmsa_agent_consume` |

### Option

| Field | Description |
| --- | --- |
| `action` | The action struct |
| `target` | The target, undefined for targetless actions |
| `score` | Final score |
| `features` | Each consideration's curved value, in consideration order |
| `probability` | Chance this option was picked under the selection policy |
| `order` | Creation order within the think |
| `inputs` | Reserved for the Learn module |

---

## Callback Signatures

| Callback | Signature | Returns |
| --- | --- | --- |
| Pull input | `function(agent, target)` | Raw value. `target` is undefined unless `per_target` |
| Targets | `function(agent)` | Array of targets, or undefined to skip the action |
| on_decide | `function(agent)` | Nothing |
| Custom curve | `function(x)` | y, clamped to 0..1 |
| Clock | `function()` | Microseconds |
| Target namer | `function(target)` | Text |

Callbacks can be anonymous functions, methods or script functions. Bind data to them with `method(struct, function)` when they need more than the agent.

**Sharing per-target values.** When two actions return the **same array** from their targets callbacks in one think, their per-target inputs are evaluated once per target and shared. Different arrays holding the same target still work correctly, the value is just evaluated once per array.

---

## Scoring Pipeline

What happens in one think, in order:

1. **Skip** actions still on cooldown.
2. **Gather targets** from each action's `targets` callback, or one targetless option.
3. **Score each option.** For each consideration, the input is read (pulled once per think, per target when per-target), normalized to 0..1 and passed through its curve. The results are multiplied. A result of 0 vetoes the option immediately.
4. **Compensate** for the number of considerations `n`, so actions with more considerations aren't punished for it:
   `score = score + (1 - score) * (1 - 1/n) * score`
5. **Weight**: multiply by the action's weight.
6. **Commit**: if the option matches the agent's current action and target, multiply by `1 + commitment`.
7. **Rank** high to low. Equal scores keep their creation order.
8. **Select**: `BEST` takes the top option. `TOP_N_WEIGHTED` picks among the top `top_n` with probability proportional to score.
9. **Cooldown** of the chosen action starts.
10. **Write** the decision and mark it fresh.

Worked example, the heal option from the README at 20 hp with a heart 10 px away:

| Step | Value |
| --- | --- |
| distance: 10 normalized over 0..300, then descending linear | 0.967 |
| missing_hp: 0.8 through quadratic power | 0.640 |
| Multiplied | 0.619 |
| Compensated, n = 2 | 0.737 |
| Weight 1.2 | 0.884 |