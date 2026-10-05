# GMSmartAgent API Reference

Complete reference for every public function, enum and data structure in GMSmartAgent.

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
- [Learn](#learn)
- [Net](#net)
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
| `gmsa_chooser.EVALUATED` | A ranking made with `gmsa_agent_evaluate`, nothing chosen |

### gmsa_learn_tier
The kind of a learning model, see [Learn](#learn).

| Element | Meaning |
| --- | --- |
| `gmsa_learn_tier.CUSTOM` | Your own model, made with `gmsa_learn_custom` |
| `gmsa_learn_tier.COUNT` | Habit counting, made with `gmsa_learn_count_create` |
| `gmsa_learn_tier.LINEAR` | Weighted preferences, made with `gmsa_learn_linear_create` |
| `gmsa_learn_tier.RANKNET` | Neural ranking, made with `gmsa_learn_ranknet_create` |
| `gmsa_learn_tier.LAMBDAMART` | Boosted ranking trees, made with `gmsa_learn_lambdamart_create` |

### gmsa_net_activation
Activation of a network layer, see [Net](#net).

| Element | Meaning |
| --- | --- |
| `gmsa_net_activation.LINEAR` | No change |
| `gmsa_net_activation.TANH` | -1..1, smooth |
| `gmsa_net_activation.RELU` | 0 below zero, unchanged above |
| `gmsa_net_activation.LEAKY_RELU` | Like RELU, but 0.01 times the value below zero |
| `gmsa_net_activation.SIGMOID` | 0..1, smooth |

### gmsa_net_optimizer
How a network applies its gradients.

| Element | Meaning |
| --- | --- |
| `gmsa_net_optimizer.SGD` | Plain gradient descent, with optional momentum |
| `gmsa_net_optimizer.ADAM` | Adam, adapts the step size per weight |

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

### gmsa_profile_set_features

```gml
gmsa_profile_set_features(profile, names) -> profile
```

Declares which inputs describe an option to a learning model. Every option of this profile then carries their normalized values in `option.inputs`, read in the order of `profile.features`.

```gml
gmsa_profile_set_features(_p, ["hp", "danger", "dist"]);
```

- **Needed on any profile whose decisions are learned from or predicted**, see [Learn](#learn).
- Profiles without features skip the work entirely, so they cost nothing extra.
- Pick inputs that explain the choice. An input every option shares (the agent's health) describes the situation, a per-target input (distance to the target) tells options apart.
- Attaching a model to a profile with no features declared makes every input a feature.

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
- the features are empty, name an unknown input, or name one twice
- the model's influence is outside 0..1
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
- When the agent or its profile has a model attached, the surviving options are re-ranked before selection, see [How re-ranking works](#how-re-ranking-works).

### gmsa_agent_evaluate

```gml
gmsa_agent_evaluate(agent, [now]) -> decision
```

Ranks the agent's current options without choosing one and without side effects. Use it to ask "what's on offer right now", usually for an observed agent like the player, then pass the result to `gmsa_learn_predict`.

- Every option is scored in full, including vetoed ones, so nothing is hidden from you.
- Cooldowns are respected, so an action on cooldown isn't on offer.
- No model re-ranks it: scores are the designer's.
- Nothing is chosen (`chosen` is -1), the decision isn't fresh, and the agent's own decision, cooldowns and think time are untouched.
- The result lives in its own reused struct, separate from the agent's decision, so evaluating never disturbs thinking. The next evaluate overwrites it.

### gmsa_decision_get_chosen

```gml
gmsa_decision_get_chosen(decision) -> option or undefined
```

**Returns** the chosen option, or `undefined` when nothing was selectable (every option was vetoed, on cooldown, or had no targets) or the decision came from `gmsa_agent_evaluate`.

### Decisions are reused

Each agent owns **one** decision struct, overwritten by every think, and its option structs are reused from a pool. This keeps thinking free of allocations. A reference you keep to a decision or an option will change on the next think, so copy the fields you need (the action name, the target) instead of keeping the struct.

---

## Observe

### gmsa_observe

```gml
gmsa_observe(agent, options, chosen, [now]) -> decision
```

Records a decision someone else made, usually the player, in the same shape as an agent's own decision. Pass it to `gmsa_learn_observe` to learn from it.

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
- **No model re-ranks it.** Scores are the designer's, and when the profile declares features each option carries them in `inputs`, ready for `gmsa_learn_observe`.

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

When a learning model changed an option's score, the line ends with the designer's score, so you can see how far learning moved it:

```
> 0.512  p1.00  loot @ chest  [value 0.80, dist 0.64]
  0.301  p0.00  fight @ goblin  [threat 0.70]  (designer 0.540)
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

## Learn

Learning from observed choices. A model watches what a decision-maker (usually the player) picks out of the options on offer, and learns their habits and preferences. A trained model is used in two ways:

- **Re-ranker:** attached to a profile or an agent, it nudges that agent's options toward what it learned, under an influence cap.
- **Predictor:** read through `gmsa_learn_input`, it turns "what is the player likely to do right now" into an input any profile can use.

The Learn module depends on Core and [Net](#net). Core never depends on it: an attached model is called through the model itself, so removing the Learn folder breaks nothing else.

### The workflow

1. Declare features on the profile whose choices you record, with `gmsa_profile_set_features`.
2. Record each choice with `gmsa_observe` and train on it with `gmsa_learn_observe`.
3. Use the model: attach it with `gmsa_profile_set_model` or `gmsa_agent_set_model`, or read it with `gmsa_learn_input` or `gmsa_learn_predict`.
4. LambdaMART only: train it with `gmsa_learn_train`. It stores choices as they come and learns from them in batches.

```gml
// the player's agent records choices, its profile declares the features
gmsa_learn_observe(global.taste, gmsa_observe(player_agent, _offered, _picked));

// a companion drifts toward the player's taste
gmsa_profile_set_model(companion_profile, global.taste, 1);   // before gmsa_profile_build

// any profile can read what the player is likely to do
gmsa_profile_add_input(_p, gmsa_input_pull("will_drink", gmsa_learn_input(global.habits, player_agent, "drink")));
```

### Choosing a model

| Model | Learns | Needs | Good at | Limits |
| --- | --- | --- | --- | --- |
| Count | How often each action is chosen in each situation | A handful of choices | Habits, explains itself in plain words | Actions only, not targets; situational inputs only |
| Linear | Weights per action and input | Dozens of choices | Preferences, including which target | Can't learn combinations of inputs (low health matters only when danger is high) |
| RankNet | A small neural network scoring each option | Dozens to hundreds of choices | Combinations of inputs, learns choice by choice | Slower to predict, more settings to tune |
| LambdaMART | Boosted decision trees ranking the options | Hundreds of choices, trained in batches | The most detailed rankings, sharp thresholds | Slowest to predict, needs `gmsa_learn_train`, can miss situations seen fewer than about 20 times |
| Custom | Whatever you write | | Game-specific patterns | |

### What models cost

Measured on the VM target, per call, at 3 and 10 options on offer. YYC is faster.

| Model | Observe | Predict | Added to a re-ranked think |
| --- | --- | --- | --- |
| Count | 28 / 46 us | 32 / 63 us | 42 / 103 us |
| Linear | 39 / 102 us | 31 / 77 us | 39 / 105 us |
| RankNet | 417 / 1253 us | 131 / 418 us | 105 / 348 us |
| LambdaMART | 23 / 52 us, stores only | 486 / 1557 us | 513 / 1650 us |

LambdaMART training with 100 trees takes about 1.4 s for 500 rows (100 choices of 5 options) and 6.6 s for 2,500 rows, or the same work spread over frames with a budget, see [gmsa_learn_train](#gmsa_learn_train).

- **Count and Linear are the crowd models.** Attach them to as many agents as you like.
- **RankNet and LambdaMART suit a few agents**, a boss or a companion, or a predictor input: `gmsa_learn_input` caches its prediction per frame, so every agent reading it shares one evaluation.
- **Observe cost only matters once per recorded choice**, not per frame.
- **The scheduler budget protects your frame rate whatever is attached.** A heavy model means fewer thinks per step, never a slower game.

### Names, not indices

Models bind to profiles by **action and input names**, cached per profile. A model trained on one profile (the player's) can be used by another (a companion's) as long as they share names. New names extend the model's vocabulary, so adding an action to a profile doesn't break a trained or saved model.

### gmsa_learn_count_create

```gml
gmsa_learn_count_create([params]) -> model
```

| Param | Type | Default | Description |
| --- | --- | --- | --- |
| `bins` | integer | 4 | Bins per input: 4 splits each input into quarters |
| `inputs` | array | all situational | Names of the inputs that define a situation |
| `smoothing` | real | 1 | Added to every count, so one observation never reads as certainty |
| `half_life` | real | 50 | Observations after which an old choice counts half |
| `confidence_k` | real | 5 | Data in a situation needed for 50% confidence |

How it works:
- Each situational input (one that doesn't depend on the target) is cut into bins, and the combination of bins is the **situation**. Per-target inputs are ignored.
- Per situation, it counts how often each action was chosen, with older choices fading by `half_life`.
- A prediction is each action's smoothed share of its situation. Options with the same action split that action's share.
- **Confidence is per situation:** `n / (n + confidence_k)`, where `n` is the amount of data for this situation. A model with plenty of data overall but none for the current situation says it doesn't know.
- The inputs it buckets on are fixed the first time it's used.

Explain reads like:

```
hp 0-25%, danger 75-100%: drink 7.0 of 9.0 (0.73)
```

**Throws** when `bins` isn't a whole number of 1 or more, `smoothing` isn't above 0, `inputs` is empty, or the situations would exceed 4096 (`bins` to the power of the number of inputs). That last check runs at creation when you pass `inputs`, otherwise the first time the model is used.

### gmsa_learn_linear_create

```gml
gmsa_learn_linear_create([params]) -> model
```

| Param | Type | Default | Description |
| --- | --- | --- | --- |
| `learn_rate` | real | 0.3 | How far one observation moves the weights |
| `half_life` | real | 50 | Observations after which old evidence counts half |
| `confidence_k` | real | 20 | Observations needed for 50% confidence |

How it works:
- Each action has a weight per input and a bias. An option's preference is its action's bias plus each input times its weight, so per-target inputs let it prefer one target over another.
- The offered options compete through a softmax, so their probabilities sum to 1.
- Each observation moves the chosen option's weights toward its inputs and the others' away, in proportion to how surprised the model was. An expected choice changes little, a surprising one changes a lot.
- Every observation shrinks all weights slightly, so old preferences fade unless they keep being reinforced.
- **Confidence is model-wide:** `samples / (samples + confidence_k)`.

Explain reads like:

```
loot: value +0.42, dist -0.18, bias +0.10 (p 0.62)
```

**Throws** when `learn_rate` isn't above 0.

### gmsa_learn_ranknet_create

```gml
gmsa_learn_ranknet_create([params]) -> model
```

| Param | Type | Default | Description |
| --- | --- | --- | --- |
| `hidden` | array | `[8]` | Hidden layer sizes, `[]` for none |
| `activation` | `gmsa_net_activation` | `TANH` | Hidden layer activation |
| `optimizer` | `gmsa_net_optimizer` | `ADAM` | How the network applies what it learns |
| `learn_rate` | real | 0.02 | Step size of each update |
| `momentum` | real | 0 | SGD momentum, ignored by Adam |
| `seed` | integer | 1 | Starting weights, same seed and same choices give the same model |
| `half_life` | real | 200 | Observations after which old evidence counts half |
| `confidence_k` | real | 40 | Observations needed for 50% confidence |

How it works:
- A small neural network ([Net](#net)) scores each option from its features and which action it is. Combinations of inputs are learnable, which Linear can't do.
- Each observation trains on pairs, the chosen option against each one not chosen, with RankNet's pairwise loss.
- The offered options compete through a softmax of their scores, so the re-ranker and the predictor input work exactly as with Linear.
- An untrained model scores every option the same, so it predicts an even split.
- Old evidence fades through weight decay: weights shrink by the half-life's decay every observation.
- New actions and inputs grow the network. Saves made before keep working.
- **Confidence is model-wide:** `samples / (samples + confidence_k)`.

**Tuning:** with Adam, weights settle around `learn_rate / (1 - decay)`. A low `learn_rate` with a short `half_life` leaves the network too weak to learn anything: `learn_rate 0.01` with `half_life 50` learned nothing in testing. When you lower one, raise the other.

Explain reads like this, where each input's share is how much the score drops when that input is 0:

```
drink: hp +0.84, danger +0.31, gold -0.02, score +1.20 (p 0.71)
```

**Throws** when `hidden` isn't an array, `learn_rate` isn't above 0, or the network settings are invalid (a layer size, activation or optimizer).

### gmsa_learn_lambdamart_create

```gml
gmsa_learn_lambdamart_create([params]) -> model
```

| Param | Type | Default | Description |
| --- | --- | --- | --- |
| `trees` | integer | 100 | Trees built per training |
| `depth` | integer | 3 | Levels per tree, 1 to 8 |
| `learn_rate` | real | 0.1 | How much each tree adds |
| `reg` | real | 0.1 | Keeps leaves with little evidence near 0 |
| `bins` | integer | 16 | Most bins an input is cut into when looking for splits, 2 to 256 |
| `min_leaf` | integer | 5 | Fewest options a leaf may hold |
| `buffer` | integer | 500 | Most recent choices kept to train on |
| `half_life` | real | 200 | Observations after which a stored choice counts half |
| `confidence_k` | real | 40 | Observations needed for 50% confidence |

How it works:
- `gmsa_learn_observe` stores the choice in a buffer of the most recent `buffer` choices. Nothing is learned yet.
- `gmsa_learn_train` builds `trees` decision trees from the buffer, each one correcting the ones before it, guided by LambdaRank: the chosen option should rank first. Older choices weigh less by the half-life.
- A tree splits on an input's value or on which action an option is, so it can learn sharp rules like "drink below 30% health when danger is high".
- Until the first training finishes, it predicts an even split with no confidence. During later trainings the previous trees keep predicting.
- Saves include the buffer as well as the trees, since every training starts again from the buffer.
- **Confidence is model-wide,** and 0 until the first training finishes.

**Limits:** both come from how decision trees grow, one split at a time.
- A perfectly balanced pattern of two inputs (exactly as often "both high or both low" as "one high, one low") gives no first split anything to gain, so it's never learned. Any imbalance fixes it, and real players are never balanced. RankNet doesn't have this limit.
- A situation seen fewer than about 20 times can be missed when its examples are noisy.

**Throws** when a parameter is out of the ranges above.

### gmsa_learn_custom

```gml
gmsa_learn_custom(methods, [params]) -> model
```

Wraps your own model so it works everywhere a built-in one does.

| Method | Required | Description |
| --- | --- | --- |
| `observe(sample)` | Yes | Learn from one choice, `sample.chosen` is the chosen option |
| `predict(sample, out)` | Yes | Fill `out.p[i]` for every option and `out.confidence` |
| `explain(sample, i)` | No | Return an array of lines about option `i` |
| `save_data()` | No | Return a JSON-ready struct of what was learned |
| `load_data(data)` | No | Restore what `save_data` returned |
| `reset_data()` | No | Forget everything, also called once at creation to initialize `data` |
| `train(budget)` | No | One step of batch training for `gmsa_learn_train`. Return true when finished, a missing return counts as finished |

Methods run with the model as `self`, so they can read `actions`, `inputs`, `situational`, `decay`, `samples` and their own `data`.

| Param | Type | Default | Description |
| --- | --- | --- | --- |
| `name` | string | `"custom"` | Stored in saves, a save only loads into a model with the same name |
| `half_life` | real | 50 | Sets `decay` for your own use |
| `confidence_k` | real | 20 | Used by `gmsa_learn_confidence` |

The **sample** a method receives, in the model's own id space:

```gml
sample = {
    situation : [0.35, 0, 0.80],     // situational inputs, 0 for per-target ones
    options   : [                    // one per offered option
        { action : 0, inputs : [0.35, 0.62, 0.80] },
        { action : 1, inputs : [0.35, 0.10, 0.80] },
    ],
    chosen    : 0,                   // -1 when predicting
    weight    : 1,
};
```

`action` indexes `actions`, and each `inputs` entry indexes `inputs`. An input the decision's profile doesn't have reads 0.

Predictions are cleaned before anyone uses them: negative or NaN values become 0, the values are scaled to sum to 1 (or made even if they're all 0), and confidence is clamped to 0..1. A broken custom model can't break scoring.

**Throws** when `observe` or `predict` is missing, or a method isn't callable. GML can't tell a plain number from a script index, so a number that happens to be one of your scripts' indices passes.

### gmsa_learn_observe

```gml
gmsa_learn_observe(model, decision) -> bool
```

Trains the model on a decision with a chosen option, usually from `gmsa_observe`. Nothing trains automatically: one observation can train several models, and choices you don't want learned (tutorials, cutscenes) are simply not passed in.

**Returns** false when the model is frozen.

**Throws** when the decision's profile declares no features, or nothing was chosen.

### gmsa_learn_train

```gml
gmsa_learn_train(model, [budget]) -> bool
```

Trains a batch model: LambdaMART, or a custom model with a `train` method. `budget` is the most microseconds one call may use. Without it, training finishes before the call returns.

**Returns** true when training finished. Count, Linear, RankNet and frozen models return true at once, so calling it on any model is safe.

```gml
// at a checkpoint (level end, death screen), all at once
gmsa_learn_train(global.style);

// or in the background, 2 ms per step
// Step event
if (training) training = !gmsa_learn_train(global.style, 2000);
```

- Each call does at least one small unit of work, then stops when its time is up. Measured overshoot at a 2 ms budget: under 130 us.
- Training works on a snapshot of the buffer. Choices observed meanwhile wait for the next training.
- The previous result keeps predicting until training finishes. Predictor inputs update as soon as it does.

**Throws** when `model` isn't a model or `budget` is negative.

### gmsa_learn_predict

```gml
gmsa_learn_predict(model, decision) -> { p, confidence }
```

How likely the observed decision-maker is to pick each option of a decision, usually from `gmsa_agent_evaluate`. `p[i]` matches `decision.options[i]` and the values sum to 1. `confidence` is 0..1.

The result struct is reused by the model, so copy what you keep.

### gmsa_learn_explain

```gml
gmsa_learn_explain(model, decision, index) -> array of strings
```

Lines explaining how the model rates option `index`.

### gmsa_learn_confidence

```gml
gmsa_learn_confidence(model, [n]) -> real
```

`n / (n + confidence_k)`, using the model's decayed amount of data when `n` is left out.

### gmsa_profile_set_model

```gml
gmsa_profile_set_model(profile, model, influence)
```

Attaches a model to a profile as a re-ranker, before build. `influence` (0..1) is how much say the model gets. If the profile declares no features, every input becomes one.

**Throws** when the profile is built, the model isn't a model, or `influence` is outside 0..1.

### gmsa_agent_set_model

```gml
gmsa_agent_set_model(agent, model, [influence])
```

Gives one agent its own model, overriding the profile's. Pass `undefined` to remove it.

**Throws** when the agent's profile declares no features, the model isn't a model, or `influence` is outside 0..1.

### gmsa_learn_set_influence

```gml
gmsa_learn_set_influence(target, influence)
```

Changes influence at runtime on a profile or an agent, for example with a difficulty setting. On an agent it applies to the agent's own model only. Influence is the one profile setting that can change after build.

### How re-ranking works

When a model is attached, every think adjusts the surviving options before ranking:

`score = designer * max(0.0001, lerp(1, p / best p, influence * confidence))`

- **The option the model likes most keeps its full score,** the others are pushed down by how much less it likes them.
- **Vetoed options stay vetoed:** they're gone before the model sees the list.
- **No score ever rises above the designer's score,** and no option is pushed all the way to 0.
- **No confidence, no change:** a fresh model has no effect until it has learned something.
- Each option keeps its designer score in `option.designer`, and the debug view shows it wherever learning changed a score.
- Only thinks re-rank. `gmsa_agent_evaluate` and `gmsa_observe` always show designer scores.

### gmsa_learn_input

```gml
gmsa_learn_input(model, observed, action, [params]) -> callback
```

A pull input callback reading the model's prediction about an observed agent: how likely it is to pick `action` right now.

```gml
gmsa_profile_add_input(_p, gmsa_input_pull("will_drink", gmsa_learn_input(global.habits, player_agent, "drink")));
```

| Param | Type | Default | Description |
| --- | --- | --- | --- |
| `fallback` | real | 0 | What it reads when the model has no confidence |
| `refresh` | real | one frame | Microseconds a prediction is reused |
| `clock` | function | `get_timer` | Time source, the same one as the observed agent's cooldowns |

- It reads `p(action) x confidence + fallback x (1 - confidence)`, so an untrained model reads the fallback, not a misleading even split.
- It reads 0 when the action isn't on offer right now (on cooldown, no targets).
- Predictions are cached per model and observed agent within `refresh`, so many agents reading it in one frame cost one evaluation. Learning, reset and load make the cache stale at once.
- The cache holds a reference to the observed agent.

**Throws** when the observed agent's profile declares no features or has no such action, or a parameter is out of range. Reading it from the observed agent itself throws too, since that would evaluate the agent in the middle of its own think.

### gmsa_learn_freeze

```gml
gmsa_learn_freeze(model, [frozen])
```

Stops learning (`true`, the default) or resumes it. A frozen model still predicts and re-ranks.

### gmsa_learn_reset

```gml
gmsa_learn_reset(model)
```

Forgets everything learned. Names seen so far are kept.

### gmsa_learn_save

```gml
gmsa_learn_save(model) -> string
```

The model's learned state as a JSON string, to store with your save game.

### gmsa_learn_load

```gml
gmsa_learn_load(model, json) -> bool
```

Loads a save into a model you created. The model keeps its own settings (`half_life`, `confidence_k`, tier parameters), so tuning still applies to loaded models.

**Throws** when the save is malformed, from a newer version, or from a different kind of model. A Count save also throws when the model uses a different number of bins.

### Model fields

| Field | Description |
| --- | --- |
| `tier` | `gmsa_learn_tier` |
| `tier_name` | `"count"`, `"linear"`, `"ranknet"`, `"lambdamart"` or the custom name |
| `actions` | Action names, the position is the action id |
| `inputs` | Input names, the position is the input id |
| `situational` | Per input id, true when it doesn't depend on the target |
| `samples` | Decayed amount of observed data |
| `half_life`, `decay`, `confidence_k` | Settings |
| `frozen` | True while frozen |
| `data` | What the model learned, its own shape per tier |

---

## Net

A small feed-forward neural network: dense layers, backpropagation, SGD or Adam. RankNet is built on it, and it's public, so custom models and your own game code can use it too.

The Net module depends on Core only. Learn depends on it.

```gml
// learn XOR
var _net = gmsa_net_create(2, [8, 1], { optimizer : gmsa_net_optimizer.ADAM, learn_rate : 0.05 });
var _x = [[0, 0], [0, 1], [1, 0], [1, 1]];
var _y = [0, 1, 1, 0];
repeat (1500) {
    for (var _i = 0; _i < 4; _i++) gmsa_net_train(_net, _x[_i], _y[_i]);
}
var _out = gmsa_net_forward(_net, [1, 0]);  // _out[0] is close to 1
```

### gmsa_net_create

```gml
gmsa_net_create(inputs, layers, [params]) -> net
```

| Parameter | Type | Description |
| --- | --- | --- |
| `inputs` | integer | Number of input values |
| `layers` | array | Layer sizes, the last one is the output layer. An entry can be `{ size, activation }` to set that layer's activation |

| Param | Type | Default | Description |
| --- | --- | --- | --- |
| `activation` | `gmsa_net_activation` | `TANH` | Hidden layers' activation |
| `output` | `gmsa_net_activation` | `LINEAR` | Output layer's activation |
| `optimizer` | `gmsa_net_optimizer` | `SGD` | How gradients are applied |
| `learn_rate` | real | 0.01 for SGD, 0.001 for Adam | Step size |
| `momentum` | real | 0 | SGD momentum, 0 up to below 1 |
| `weight_decay` | real | 0 | Each step, weights (not biases) are multiplied by `1 - learn_rate * weight_decay` |
| `beta1`, `beta2`, `epsilon` | real | 0.9, 0.999, 0.00000001 | Adam settings |
| `seed` | integer | 1 | Starting weights, the same seed gives the same net |
| `sparse` | bool | false | The first layer skips zero inputs. Faster for mostly-zero inputs such as one-hot codes, slower for dense ones |

- Starting weights use Xavier scaling, or He scaling for RELU and LEAKY_RELU layers, drawn from the net's own generator. GameMaker's `random` is never touched.
- Every buffer is allocated here, so forward and backward passes allocate nothing.

**Throws** when `inputs` or a layer size isn't a whole number of 1 or more, an activation or the optimizer is unknown, or a setting is out of range.

### gmsa_net_forward

```gml
gmsa_net_forward(net, input) -> array
```

Runs the net. **Returns** the output array, which the net reuses, so copy what you keep. A shorter input is padded with 0.

**Throws** when `input` has more values than the net has inputs. Grow it with `gmsa_net_grow_inputs` first.

### gmsa_net_backward

```gml
gmsa_net_backward(net, gradient)
```

Backpropagates the gradient of your loss for the most recent forward. `gradient` has one value per output, or is a number when the net has one output. Gradients add up across calls until `gmsa_net_step`, so several forward and backward pairs can make one update.

```gml
// your own loss: here, squared error toward a target
var _out = gmsa_net_forward(_net, _x);
gmsa_net_backward(_net, _out[0] - _target);
gmsa_net_step(_net);
```

**Throws** when the gradient doesn't have one value per output.

### gmsa_net_step

```gml
gmsa_net_step(net)
```

Applies the gradients gathered since the last step with the net's optimizer, then clears them. Does nothing when no backward happened since.

### gmsa_net_zero_grad

```gml
gmsa_net_zero_grad(net)
```

Discards gathered gradients without applying them.

### gmsa_net_train

```gml
gmsa_net_train(net, input, target) -> real
```

One step toward `target` with squared error: forward, backward and step. `target` is an array with one value per output, or a number for one output.

**Returns** half the squared error before the step.

### gmsa_net_reset

```gml
gmsa_net_reset(net, [seed])
```

New starting weights and cleared optimizer state, from `seed` if given, otherwise the net's own.

### gmsa_net_grow_inputs

```gml
gmsa_net_grow_inputs(net, count)
```

Adds `count` inputs at the end. Their weights start at 0, so outputs don't change until they're trained.

### gmsa_net_save

```gml
gmsa_net_save(net) -> struct
```

The net's shape, weights and biases as a JSON-ready struct, a copy that later training doesn't change. Optimizer state isn't saved.

### gmsa_net_load

```gml
gmsa_net_load(net, data) -> bool
```

Loads a save, as a struct or a JSON string, into a net with the same layer sizes and activations. A save with fewer inputs fills the rest with 0, one with more grows the net. Optimizer state starts fresh.

**Throws** when the save is malformed, from a newer version, or has a different shape.

### Net fields

| Field | Description |
| --- | --- |
| `inputs`, `outputs` | Sizes |
| `layers` | Per layer: `inputs`, `size`, `activation`, `w` (weights, one row of `inputs` per neuron), `b` (biases) |
| `optimizer`, `learn_rate`, `momentum`, `weight_decay`, `beta1`, `beta2`, `epsilon`, `seed`, `sparse` | Settings |
| `steps` | Updates applied since creation, reset or load |

Cost on the VM: 6 inputs with `[8, 1]` take 30 us per forward and 155 us per training step with Adam. 12 inputs with `[16, 8, 1]` take 125 us and 739 us.

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
- `chosen` is a valid index, or -1 when there are no options, and always -1 for evaluated decisions
- scores are positive (0 or more for observed and evaluated decisions)
- agent and evaluated decisions are ranked high to low
- every option has one feature per consideration, each in 0..1
- when the profile declares features, every option has one value per feature in `inputs`, each in 0..1
- probabilities are in 0..1 and sum to 1 when something was chosen
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
| `features` | Input indices declared with `gmsa_profile_set_features`, undefined when none |
| `model`, `influence` | The attached model and its influence, see [Learn](#learn) |

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
| `model`, `influence` | The agent's own model and influence, undefined when it uses the profile's |

### Decision

| Field | Description |
| --- | --- |
| `agent` | The agent that owns it |
| `chooser` | `gmsa_chooser` |
| `time` | Time of the think or observation |
| `options` | Array of options. Ranked high to low for agent and evaluated decisions, in your order for observed ones |
| `chosen` | Index into `options`, -1 when nothing was selectable |
| `fresh` | True until consumed with `gmsa_agent_consume` |

### Option

| Field | Description |
| --- | --- |
| `action` | The action struct |
| `target` | The target, undefined for targetless actions |
| `score` | Final score |
| `designer` | Score before any learning model adjusted it |
| `features` | Each consideration's curved value, in consideration order |
| `probability` | Chance this option was picked under the selection policy |
| `order` | Creation order within the think |
| `inputs` | Normalized value of each feature, in the order of `profile.features`. Only filled when the profile declares features |

### Model

See [Model fields](#model-fields) in Learn.

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
| Custom model `observe` | `function(sample)` | Nothing |
| Custom model `predict` | `function(sample, out)` | Nothing, fills `out.p` and `out.confidence` |
| Custom model `explain` | `function(sample, index)` | Array of strings |
| Custom model `save_data` | `function()` | JSON-ready struct |
| Custom model `load_data` | `function(data)` | Nothing |
| Custom model `reset_data` | `function()` | Nothing |
| Custom model `train` | `function(budget)` | True when finished |

Custom model methods run with the model as `self`, see [gmsa_learn_custom](#gmsa_learn_custom).

Callbacks can be anonymous functions, methods or script functions. They're checked when you configure, but GML can't tell a plain number from a script index: a number passed by mistake is only caught when it isn't one of your scripts. Bind data to them with `method(struct, function)` when they need more than the agent.

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
8. **Re-rank**, only when a model is attached and there are at least two options: each score is multiplied by `lerp(1, p / best p, influence * confidence)`, never below 0.0001 of itself, and the options are ranked again. The score before this step stays in `option.designer`.
9. **Select**: `BEST` takes the top option. `TOP_N_WEIGHTED` picks among the top `top_n` with probability proportional to score.
10. **Cooldown** of the chosen action starts.
11. **Write** the decision and mark it fresh.

Worked example, the heal option from the README at 20 hp with a heart 10 px away:

| Step | Value |
| --- | --- |
| distance: 10 normalized over 0..300, then descending linear | 0.967 |
| missing_hp: 0.8 through quadratic power | 0.640 |
| Multiplied | 0.619 |
| Compensated, n = 2 | 0.737 |
| Weight 1.2 | 0.884 |