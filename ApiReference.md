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
- [Learning From Outcomes](#learning-from-outcomes)
- [Learning Sequences](#learning-sequences)
- [Net](#net)
- [Plan](#plan)
- [PlanLearn](#planlearn)
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
| `gmsa_learn_tier.NGRAM` | What follows what, in which situation, made with `gmsa_learn_ngram_create` |
| `gmsa_learn_tier.TDNN` | A network over the last few choices, made with `gmsa_learn_tdnn_create` |

### gmsa_learn_target
What a learning model learns from, see [Learning From Outcomes](#learning-from-outcomes).

| Element | Meaning |
| --- | --- |
| `gmsa_learn_target.CHOICES` | Choices someone made, recorded with `gmsa_observe` and `gmsa_learn_observe`. The default |
| `gmsa_learn_target.OUTCOMES` | How an agent's own decisions turned out, reported with `gmsa_learn_outcome` and `gmsa_learn_reward` |

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

### gmsa_plan_status
Where a planner's plan is, see [Plan](#plan).

| Element | Meaning |
| --- | --- |
| `gmsa_plan_status.IDLE` | No plan, before the first `gmsa_plan_make` or after `gmsa_plan_stop` |
| `gmsa_plan_status.PLANNING` | A plan is being made or repaired across frames, see [Planning across frames](#planning-across-frames) |
| `gmsa_plan_status.RUNNING` | A plan is running, `gmsa_plan_current` is the step to do |
| `gmsa_plan_status.DONE` | Every step of the plan is done |
| `gmsa_plan_status.FAILED` | No plan was found, or the plan broke and couldn't be repaired |

### gmsa_plan_result
How the last planning call went, see [Plan](#plan).

| Element | Meaning |
| --- | --- |
| `gmsa_plan_result.NONE` | Nothing planned yet |
| `gmsa_plan_result.FOUND` | A plan was found |
| `gmsa_plan_result.NO_PLAN` | No method combination works with the facts as they are |
| `gmsa_plan_result.OUT_OF_BUDGET` | The search used its node budget before finding a plan |

### gmsa_plan_report
What a plan report is about, see [Reports](#reports).

| Element | Meaning |
| --- | --- |
| `gmsa_plan_report.METHOD_SUCCESS` | A task finished with this method |
| `gmsa_plan_report.METHOD_FAILURE` | This method broke and was replaced, or the plan failed with it |
| `gmsa_plan_report.METHOD_REWARD` | A reward from `gmsa_plan_reward` reached this method |
| `gmsa_plan_report.STEP_SUCCESS` | A step was reported done |
| `gmsa_plan_report.STEP_FAILURE` | A step was reported failed, or had no target |
| `gmsa_plan_report.GOAL_SUCCESS` | A goal's chain finished |
| `gmsa_plan_report.GOAL_FAILURE` | A goal's chain broke and was searched again, or the plan failed with it |

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

On a tracked agent, switching to a different option also records the decision for outcome learning, see [gmsa_learn_track](#gmsa_learn_track).

**Throws** when the option comes from a different profile.

### gmsa_agent_clear_current

```gml
gmsa_agent_clear_current(agent)
```

Clears the current option, for example when the agent finished or abandoned what it was doing. On a tracked agent, this ends the current decision in its history.

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

A scheduler runs agent thinks within a time budget per step. Other work can share that budget, such as planners making plans, see [gmsa_scheduler_add_work](#gmsa_scheduler_add_work). You create schedulers yourself, there's no global one.

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

### gmsa_scheduler_add_work

```gml
gmsa_scheduler_add_work(scheduler, work, [priority]) -> work
```

Adds work that shares the scheduler's budget with the agents. `work` is any struct with a `work(budget)` method: it's called with the microseconds it may use, and returns true when it did something, false when it had nothing to do. `gmsa_plan_schedule` uses this for planners and `gmsa_learn_schedule` for training models, and your own long jobs can use it too.

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `priority` | real | 0 | Tier, shared with agents of the same priority |

- Within a tier, agents and work take turns: each think is followed by one work turn while there's work to do, then whatever budget the agents leave goes to work, a turn at a time.
- Work items take turns among themselves, the next step continues where this one stopped.
- When a pass finds no work item with anything to do, the tier skips work for the rest of the step. Idle work costs one call per item per step.
- A tier without work runs exactly as before, so schedulers without work pay nothing for this.
- Respect the budget you're given, the scheduler can't stop a call that runs long.

**Throws** when `work` has no callable `work` method, is already in a scheduler, or `priority` isn't a number.

### gmsa_scheduler_remove_work

```gml
gmsa_scheduler_remove_work(scheduler, work) -> bool
```

Removes work. **Returns** false if it wasn't in this scheduler.

### gmsa_scheduler_step

```gml
gmsa_scheduler_step(scheduler) -> integer
```

Runs due agents, and work turns, until the budget is spent, then fires queued `on_decide` callbacks. Call it once per step.

- Tiers run highest priority first. Within a tier, agents take turns, and the next step continues where this one stopped.
- An agent is due when it has never thought, or when `interval` has passed since its last think.
- The clock is checked before every think and work turn except the first, so **every step does at least one** when an agent is due or work is waiting, even with a budget of 0. A step can overshoot the budget by at most one think or one work turn's overrun.
- Every think in a step uses the same time, read once at the start.
- `on_decide` callbacks run after the timed loop, so your code never eats into the budget, and a callback can safely remove agents.

**Returns** the number of thinks this step.

Statistics of the last step are in `scheduler.stats`:

| Field | Meaning |
| --- | --- |
| `thinks` | Thinks run |
| `works` | Work turns that did something |
| `time` | Microseconds spent, callbacks excluded |
| `stopped` | True if the budget ran out before every due agent thought |

### gmsa_scheduler_count

```gml
gmsa_scheduler_count(scheduler) -> integer
```

**Returns** the number of agents in the scheduler. Work items aren't counted.

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

### gmsa_debug_draw_tree

```gml
gmsa_debug_draw_tree(lines, x, y, [max]) -> real
```

Draws a tree of lines at `x, y`, such as the plan tree from [gmsa_plan_lines](#gmsa_plan_lines):

```gml
// Draw GUI
gmsa_debug_draw_tree(gmsa_plan_lines(planner), 10, 300);
```

`lines` is an array of structs with `kind`, `depth` and `text`, optionally `repaired` and `progress`. Debug takes plain lines, not a planner, so it never needs the Plan module and anything that produces lines in this shape can be drawn.

| Kind | Drawn |
| --- | --- |
| `"current"` | Green, with `>` before it |
| `"done"` | Gray, ending in ", done" |
| `"skipped"`, `"reason"` | Orange |
| anything else | White |

- `depth` indents by two spaces per level, and every tree line keeps a two character slot before its text, so the `>` never shifts the indentation.
- `repaired` lines get a faint yellow band behind them.
- `progress`, 0 to 1, draws a thin bar under the line.
- Up to `max` lines (default 40), then a line counting the rest. Restores the draw colour and alpha afterwards.

**Returns** the height drawn.

---

## Learn

Learning from observed choices. A model watches what a decision-maker (usually the player) picks out of the options on offer, and learns their habits and preferences. A model can also learn from how an agent's own decisions turn out instead, see [Learning From Outcomes](#learning-from-outcomes). A trained model is used in two ways:

- **Re-ranker:** attached to a profile or an agent, it nudges that agent's options toward what it learned, under an influence cap.
- **Predictor:** read through `gmsa_learn_input`, it turns "what is the player likely to do right now" into an input any profile can use.

The Learn module depends on Core and [Net](#net). Core never depends on it: an attached model is called through the model itself, so removing the Learn folder breaks nothing else.

### The workflow

1. Declare features on the profile whose choices you record, with `gmsa_profile_set_features`.
2. Record each choice with `gmsa_observe` and train on it with `gmsa_learn_observe`.
3. Use the model: attach it with `gmsa_profile_set_model` or `gmsa_agent_set_model`, or read it with `gmsa_learn_input` or `gmsa_learn_predict`.
4. LambdaMART and TDNN: give them training time with `gmsa_learn_train` or `gmsa_learn_schedule`. LambdaMART stores choices and learns from them in batches, the TDNN learns each choice at once and replays earlier ones when trained.

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
| N-gram | What follows what, in which situation | Dozens of choices | Habits in order, combos, many habits in one model, explains itself in plain words | Actions only, not targets. See [Learning Sequences](#learning-sequences) |
| TDNN | A network over the last few choices, scoring each option | Hundreds of choices | Which target in order, patterns that skip moves | Slower to learn and to run. See [Learning Sequences](#learning-sequences) |
| Custom | Whatever you write | | Game-specific patterns | |

### What models cost

Measured on the VM target, per call, at 3 and 10 options on offer. YYC is faster.

| Model | Observe | Predict | Added to a re-ranked think |
| --- | --- | --- | --- |
| Count | 28 / 46 us | 32 / 63 us | 42 / 103 us |
| Linear | 39 / 102 us | 31 / 77 us | 39 / 105 us |
| RankNet | 417 / 1253 us | 131 / 418 us | 105 / 348 us |
| LambdaMART | 23 / 52 us, stores only | 486 / 1557 us | 513 / 1650 us |

The sequence learners are measured in [What sequence learners cost](#what-sequence-learners-cost).

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
| `learns`, `temperature` | | `CHOICES`, 0.1 | Learning from outcomes, see [How each model learns outcomes](#how-each-model-learns-outcomes) |

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
| `learn_rate` | real | 0.3, or 0.1 when learning outcomes | How far one observation moves the weights |
| `half_life` | real | 50 | Observations after which old evidence counts half |
| `confidence_k` | real | 20 | Observations needed for 50% confidence |
| `learns`, `temperature` | | `CHOICES`, 0.1 | Learning from outcomes, see [How each model learns outcomes](#how-each-model-learns-outcomes) |

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
| `learns`, `temperature` | | `CHOICES`, 0.1 | Learning from outcomes, see [How each model learns outcomes](#how-each-model-learns-outcomes) |

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
| `learns`, `temperature` | | `CHOICES`, 0.1 | Learning from outcomes, see [How each model learns outcomes](#how-each-model-learns-outcomes) |

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
| `waiting()` | With `train`, to be scheduled | True when `train` has work to do, so [gmsa_learn_schedule](#gmsa_learn_schedule) skips the model while it's idle |

Methods run with the model as `self`, so they can read `actions`, `inputs`, `situational`, `decay`, `samples` and their own `data`.

| Param | Type | Default | Description |
| --- | --- | --- | --- |
| `name` | string | `"custom"` | Stored in saves, a save only loads into a model with the same name |
| `half_life` | real | 50 | Sets `decay` for your own use |
| `confidence_k` | real | 20 | Used by `gmsa_learn_confidence` |
| `learns`, `temperature` | | `CHOICES`, 0.1 | What the model learns from, see [Learning From Outcomes](#learning-from-outcomes) |

The **sample** a method receives, in the model's own id space:

```gml
sample = {
    situation : [0.35, 0, 0.80],     // situational inputs, 0 for per-target ones
    options   : [                    // one per offered option
        { action : 0, inputs : [0.35, 0.62, 0.80] },
        { action : 1, inputs : [0.35, 0.10, 0.80] },
    ],
    chosen    : 0,                   // -1 when predicting
    weight    : 1,                   // outcomes: the credit times the odds correction
    reward    : undefined,           // outcomes: the reported reward
};
```

`action` indexes `actions`, and each `inputs` entry indexes `inputs`. An input the decision's profile doesn't have reads 0.

Predictions are cleaned before anyone uses them: negative or NaN values become 0, the values are scaled to sum to 1 (or made even if they're all 0), and confidence is clamped to 0..1. A broken custom model can't break scoring.

**Throws** when `observe` or `predict` is missing, or a method isn't callable. In GML a function reference can be a plain number, so a number passed by mistake isn't always caught.

### gmsa_learn_observe

```gml
gmsa_learn_observe(model, decision) -> bool
```

Trains the model on a decision with a chosen option, usually from `gmsa_observe`. Nothing trains automatically: one observation can train several models, and choices you don't want learned (tutorials, cutscenes) are simply not passed in.

**Returns** false when the model is frozen.

**Throws** when the model learns from outcomes, the decision's profile declares no features, or nothing was chosen.

### gmsa_learn_train

```gml
gmsa_learn_train(model, [budget]) -> bool
```

Gives a model training time: LambdaMART's batches, the TDNN's replays, or a custom model's `train` method. `budget` is the most microseconds one call may use. Without it, training finishes before the call returns. To train inside a scheduler's budget instead, see [gmsa_learn_schedule](#gmsa_learn_schedule).

**Returns** true when training finished. Count, Linear, RankNet, the n-gram and frozen models return true at once, so calling it on any model is safe.

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
- **The TDNN** learns each choice inside `gmsa_learn_observe` and queues `replay` earlier ones. Each call works through the queue, one replay at a time, about 1.2 ms each with 4 options on the VM. Without training calls it still learns, like `replay : 0`, more slowly.

**Throws** when `model` isn't a model or `budget` is negative.

### gmsa_learn_schedule

```gml
gmsa_learn_schedule(model, scheduler, [priority]) -> model
```

Makes a model's training scheduler work, like [gmsa_plan_schedule](#gmsa_plan_schedule) does for planners: `gmsa_learn_train` runs inside the scheduler's budget, taking turns with the agents, and continues where it stopped.

```gml
global.shop_taste = gmsa_learn_tdnn_create();
gmsa_learn_schedule(global.shop_taste, global.scheduler);  // its replays train in the scheduler's spare time
```

- **Idle models take no turns.** A model says whether it has work with its `waiting` method: the TDNN while replays are queued, LambdaMART while a training is under way or choices came in since the last one began.
- **LambdaMART retrains whenever new choices arrive,** from its whole buffer, using whatever budget the agents leave.
- Models that learn as they observe (Count, Linear, RankNet, the n-gram) can be scheduled too, they just never take a turn.
- Frozen models take no turns.

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `priority` | real | 0 | Scheduler tier, shared with agents and work of the same priority |

**Throws** when the model is already scheduled, or a custom model has `train` but no `waiting` method.

### gmsa_learn_unschedule

```gml
gmsa_learn_unschedule(model) -> bool
```

Takes the model's training out of its scheduler. **Returns** false if it wasn't scheduled.

### gmsa_learn_predict

```gml
gmsa_learn_predict(model, decision) -> { p, confidence, best, sure }
```

How likely the observed decision-maker is to pick each option of a decision, usually from `gmsa_agent_evaluate`.

| Field | Description |
| --- | --- |
| `p` | `p[i]` is option `i`'s probability, matching `decision.options[i]`. The values sum to 1 |
| `confidence` | 0..1, how much the model knows about this moment |
| `best` | The index of the favourite option, the first one on a tie, -1 when there are no options |
| `sure` | `confidence * p[best]`: how sure the model is of its favourite |

**Use `sure` for hints and thresholds** ("show the hint at 0.6"). `confidence` alone can mislead: a model can know a moment well and still be split between options. In testing, an n-gram asked to predict which potion (it learns kinds of item, not which one) had confidence 0.8 or more and was right 31% of the time, while its `sure` stayed low. Across every test, predictions at `sure` 0.6 or more were right 89 to 100% of the time.

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

The model's learned state as a JSON string, to store with your save game. It records whether the model learns from choices or outcomes.

### gmsa_learn_load

```gml
gmsa_learn_load(model, json) -> bool
```

Loads a save into a model you created. The model keeps its own settings (`half_life`, `confidence_k`, tier parameters), so tuning still applies to loaded models.

If loading fails partway, the model is left exactly as it was. Saves from before outcome learning load as choice saves.

**Throws** when the save is malformed, from a newer version, from a different kind of model, or from a model learning from the other target. A Count save also throws when the model uses a different number of bins.

### Model fields

| Field | Description |
| --- | --- |
| `tier` | `gmsa_learn_tier` |
| `tier_name` | `"count"`, `"linear"`, `"ranknet"`, `"lambdamart"`, `"ngram"`, `"tdnn"` or the custom name |
| `learns`, `temperature` | What it learns from, and how sharply outcome values become preferences |
| `actions` | Action names, the position is the action id |
| `inputs` | Input names, the position is the input id |
| `situational` | Per input id, true when it doesn't depend on the target |
| `samples` | Decayed amount of observed data |
| `half_life`, `decay`, `confidence_k` | Settings |
| `frozen` | True while frozen |
| `data` | What the model learned, its own shape per tier |

---

## Learning From Outcomes

Everything above learns from **choices**: the player picks, a model learns their taste. A model can instead learn from **outcomes**: an agent acts, your game reports how it went, and the model learns which actions pay off in which situations.

- **Choices copy someone.** The model learns what the player would pick.
- **Outcomes discover what works.** The model learns what turns out well. You define what good means through the reward, never which action is right.

**Use it for consequences you can't know while writing the profile:** a generated or shuffled world, rules the player changes, systems that interact in ways nobody predicted, or a specific player's play. If you know the rule ("wolves are dangerous"), write it as a consideration. That's instant, exact and free.

**Inputs decide what a model can understand.** If the cause of a bad outcome is one of the decision's inputs, such as the distance to a wolf, the model learns the rule and recovers the moment the cause goes away. If the cause isn't an input, it can only learn "this option is bad" and unlearns it slowly. Give your models the causes.

### The workflow

```gml
// a model that learns from outcomes, shared by a whole squad
global.tactics = gmsa_learn_linear_create({ learns : gmsa_learn_target.OUTCOMES });

// each soldier: keep a history of its decisions, and let the shared model re-rank its options
gmsa_learn_track(agent);
gmsa_agent_set_model(agent, global.tactics, 1);

// acting on a decision records it
gmsa_agent_set_current_option(agent, _option);
shot = gmsa_learn_remember(agent);  // a ticket for this decision

// later, when you know how it went
gmsa_learn_outcome(global.tactics, shot, _hit ? 1 : 0);
gmsa_agent_clear_current(agent);    // a shot is over once it lands
```

1. Create the model with `learns : gmsa_learn_target.OUTCOMES`. Every built-in model and custom models support it.
2. Track the agents whose decisions you'll report on, with `gmsa_learn_track`.
3. Attach the model as usual, to the agents or their profile, so what it learns changes their choices.
4. Act through `gmsa_agent_set_current_option`. That's what records a decision.
5. Report results: precisely with a ticket, or as an ambient reward for whatever the agent did recently.

### gmsa_learn_track

```gml
gmsa_learn_track(agent, [params]) -> agent
```

Starts keeping the agent's history: the decisions it acted on, so outcomes can be reported for them. Untracked agents pay nothing.

| Param | Type | Default | Description |
| --- | --- | --- | --- |
| `size` | integer | 8 | Most decisions kept, oldest dropped first |
| `window` | real | 3000000 | Microseconds an ended decision can still receive ambient rewards |
| `clock` | function | `get_timer` | Time source in microseconds |

- **A decision enters the history when the agent switches to it** with `gmsa_agent_set_current_option`. Confirming the option it's already doing only refreshes the entry: "kept flanking for four seconds" is one decision, not forty.
- **When each choice is its own episode,** like a shot or a sale, call `gmsa_agent_clear_current` once its outcome is reported. Otherwise choosing the same action again counts as continuing the previous decision.
- Only options from the agent's own decision are recorded. An option from `gmsa_agent_evaluate` becomes current but has no history entry.

**Throws** when the agent's profile declares no features, or a parameter is out of range.

### gmsa_learn_untrack

```gml
gmsa_learn_untrack(agent)
```

Stops tracking and forgets the history. Tickets you kept stay usable.

### gmsa_learn_remember

```gml
gmsa_learn_remember(agent) -> ticket or undefined
```

The decision the agent is acting on right now, or `undefined`. A ticket holds everything needed to learn from that decision, so it stays valid as long as you keep it, even after it has left the history.

**Throws** when the agent isn't tracked.

### gmsa_learn_outcome

```gml
gmsa_learn_outcome(model, ticket, reward) -> bool
```

Teaches an outcome model how the decision behind a ticket turned out. Use it when you know exactly which decision caused the result: this shot hit, this sale happened.

**Returns** false when the model is frozen.

**Throws** when the model learns from choices, the ticket isn't one, or the reward isn't a number.

### gmsa_learn_reward

```gml
gmsa_learn_reward(model, agent, reward) -> real
```

Something good or bad just happened to a tracked agent, and you don't know which decision caused it: it took damage, it found gold. The credit is spread over its recent decisions:

- The decision it's acting on now gets the full reward.
- An ended decision gets less the longer ago it ended, fading to nothing at the `window`.

**Returns** how many decisions were credited.

**Throws** when the model learns from choices, the agent isn't tracked, or the reward isn't a number.

### Rewards

- **Rewards are numbers you choose,** negative for bad. Keep them roughly between -1 and 1, the scale the defaults (`temperature`, learn rates) are tuned for. They aren't clamped.
- **Report events, not a per-frame trickle.** One `gmsa_learn_reward` over a full history is 8 updates. For damage over time, add it up and report it every half second or so.
- **One history can teach several models.** Report the same ticket to each.

### Fair learning and exploration

- **Rarely chosen options count more when they are chosen:** each update is weighted by 1 over the probability the agent had of picking it, at most `GMSA_LEARN_ODDS_CLIP` (10). Without this, an option the agent seldom tries would be judged from too little data.
- **Agents only learn about what they try.** With `TOP_N_WEIGHTED` selection, the variety among the top options is the exploration, and `top_n` is how adventurous the agent is. A `BEST` agent learns from what it does but never experiments.
- **Options your scoring keeps out of the top N are never tried.** Learning stays under the designer, exploration included.
- **Exploiting is partial by design.** The re-ranker never pushes an option below a share of your score, and weighted selection picks in proportion. So a learning agent keeps trying alternatives often. Raise `influence` or lower `top_n` for more exploitation.

### How sure a model gets

Old evidence fades, so a model's amount of data levels off at about `half_life / ln 2` (about 72 at the default half-life of 50), however long it learns. Confidence, `n / (n + confidence_k)`, levels off with it:

| Model | Defaults | Highest confidence | The worse option keeps about |
| --- | --- | --- | --- |
| Count | `half_life` 50, `confidence_k` 5 | 0.94 | 6% of its score |
| Linear | `half_life` 50, `confidence_k` 20 | 0.78 | 22% of its score |

This is deliberate: the worse option keeps getting tried now and then, which is how a model notices when the world changes. To commit harder, raise `half_life` (slower to notice change) or lower `confidence_k`. With `half_life` 200 and `confidence_k` 5, confidence reaches about 0.98.

### How each model learns outcomes

Every built-in model takes `learns` and `temperature`:

| Param | Type | Default | Description |
| --- | --- | --- | --- |
| `learns` | `gmsa_learn_target` | `CHOICES` | What the model learns from |
| `temperature` | real | 0.1 | Outcome models: how sharply differences in expected reward become preferences. Lower is sharper |

An outcome model estimates the reward of each option, and turns the estimates into probabilities with `softmax(value / temperature)`. So re-ranking, `gmsa_learn_predict`, `gmsa_learn_input`, explain and the debug view all work as with choices. On an outcome model, `gmsa_learn_input` reads how good an action looks right now.

| Model | Estimates the reward with | Learns in |
| --- | --- | --- |
| Count | The average reward per situation and action. Untried actions start at 0 | Dozens of outcomes per situation |
| Linear | A linear estimate per action, nudged toward each reward. Learn rate 0.1 by default for outcomes | Dozens of outcomes |
| RankNet | The network's output, trained toward each reward | Thousands: the shape of the payoffs shows in about 600, the right levels across actions take longer |
| LambdaMART | Boosted regression trees on the stored rewards, trained with `gmsa_learn_train` | Hundreds |
| N-gram | The average reward per action in each context of the agent's own last moves and the situation | Dozens per context |
| TDNN | The network's output for the chosen option, trained toward each reward, with replays | Hundreds |

For outcomes from a few hundred episodes, use Count, Linear or LambdaMART. RankNet suits long-running learning on complex patterns.

### What outcome learning costs

Measured on the VM target:

| | 3 options | 10 options |
| --- | --- | --- |
| Tracking, per decision switch | 10 us | 20 us |
| `gmsa_learn_outcome`: Count, Linear, LambdaMART | 21 to 29 us | 39 to 47 us |
| `gmsa_learn_outcome`: RankNet | 181 us | 275 us |
| `gmsa_learn_reward` over a full history of 8 | about 8 outcomes | |

LambdaMART stores one row per outcome, so training on 500 outcomes takes about 0.5 s, a third of training on choices.

### History entries and tickets

| Field | Description |
| --- | --- |
| `agent` | The agent that decided |
| `options` | Copies of the options on offer, with their feature values |
| `chosen` | Index of the option acted on |
| `probability` | The chance the agent had of picking it |
| `start`, `last` | When the agent switched to it, and when it last acted on it |
| `active` | True while it's the agent's current decision |

### Learn spaces

Models usually learn from an agent's decisions. A **space** lets them learn from choices that aren't an agent's: which recipe a planner used, which route a convoy took. You describe the choice as names, then pass options as plain numbers. Every model works with it unchanged except the sequence learners, which need an agent's history and refuse a space. [PlanLearn](#planlearn) is built on it.

```gml
// once: three routes, described by two inputs
global.routes = gmsa_learn_space("convoy", ["road", "river", "forest"], ["night", "danger"]);
global.route_luck = gmsa_learn_count_create({ learns : gmsa_learn_target.OUTCOMES });

// each trip: the options on offer, inputs as 0..1 values in the order declared
var _inputs = [is_night ? 1 : 0, danger / 100];
var _options = [{ action : 0, inputs : _inputs }, { action : 1, inputs : _inputs }, { action : 2, inputs : _inputs }];
var _p = gmsa_learn_space_predict(global.route_luck, global.routes, _options).p;

// when the trip is over: route 1 was taken with a 50% chance, and it went well
gmsa_learn_space_outcome(global.route_luck, global.routes, _options, 1, 0.5, 1);
```

### gmsa_learn_space

```gml
gmsa_learn_space(name, actions, inputs, [params]) -> space
```

| Parameter | Type | Description |
| --- | --- | --- |
| `name` | string | For error messages |
| `actions` | array | Unique action names, an option's `action` is an index into it |
| `inputs` | array | Unique input names, an option's `inputs` holds one 0..1 value per name, in this order |

| Param | Type | Default | Description |
| --- | --- | --- | --- |
| `situational` | array | all true | One bool per input: true when the input describes the situation, false when it differs per option (like a per-target input). Count buckets on situational inputs only |

Models bind by names, as with profiles, so a model can learn from a space and a profile that share names.

**Throws** when the name is empty, there are no actions, a name repeats, or `situational` doesn't have one bool per input.

### gmsa_learn_space_predict

```gml
gmsa_learn_space_predict(model, space, options) -> { p, confidence }
```

Like [gmsa_learn_predict](#gmsa_learn_predict): `p[i]` matches `options[i]`. The result is reused, copy what you keep.

### gmsa_learn_space_observe

```gml
gmsa_learn_space_observe(model, space, options, chosen) -> bool
```

A choice model learns that `options[chosen]` was picked. **Returns** false when the model is frozen.

### gmsa_learn_space_outcome

```gml
gmsa_learn_space_outcome(model, space, options, chosen, probability, reward, [credit]) -> bool
```

An outcome model learns how `options[chosen]` turned out. `probability` is the chance it had of being chosen (above 0, at most 1), used for the same fair learning as tracked decisions. `credit` (above 0, at most 1, default 1) scales the update. **Returns** false when the model is frozen.

### gmsa_learn_space_explain

```gml
gmsa_learn_space_explain(model, space, options, index) -> array of strings
```

Like [gmsa_learn_explain](#gmsa_learn_explain).

All four **throw** when `options` is empty, an option's `action` isn't a valid index, its `inputs` don't have one value per declared input, or `chosen` isn't an option index.

### Bring your own network

A custom model with `learns : gmsa_learn_target.OUTCOMES` works with tracking, tickets and rewards unchanged. Outcome samples carry `reward`, and `weight` already includes the credit and the odds correction. Here, a [Net](#net) of your own shape learns rewards:

```gml
// a value network of your own shape: 5 inputs and 3 actions, encoded as 8 values
global.value = gmsa_learn_custom({
    reset_data : function() {
        data = {
            net : gmsa_net_create(8, [16, 8, 1], { optimizer : gmsa_net_optimizer.ADAM, learn_rate : 0.01, sparse : true }),
            x   : array_create(8, 0),
        };
    },
    observe : function(_sample) {
        // the chosen option's estimated reward moves toward the reward it got
        var _out = gmsa_net_forward(data.net, my_encode(data.x, _sample.options[_sample.chosen]));
        gmsa_net_backward(data.net, _sample.weight * (_out[0] - _sample.reward));
        gmsa_net_step(data.net);
    },
    predict : function(_sample, _out) {
        // estimated reward per option, turned into preferences through the temperature
        var _n = array_length(_sample.options);
        var _max = -infinity;
        for (var _i = 0; _i < _n; _i++) {
            var _v = gmsa_net_forward(data.net, my_encode(data.x, _sample.options[_i]));
            _out.p[_i] = _v[0];
            _max = max(_max, _v[0]);
        }
        var _sum = 0;
        for (var _i = 0; _i < _n; _i++) {
            _out.p[_i] = exp((_out.p[_i] - _max) / temperature);
            _sum += _out.p[_i];
        }
        for (var _i = 0; _i < _n; _i++) _out.p[_i] /= _sum;
        _out.confidence = gmsa_learn_confidence(self);
    },
}, { name : "value net", learns : gmsa_learn_target.OUTCOMES, temperature : 0.1 });

// your encoding: the option's inputs, then 1 in its action's slot
function my_encode(_x, _option) {
    for (var _j = 0; _j < 5; _j++) _x[@ _j] = _option.inputs[_j];
    for (var _a = 0; _a < 3; _a++) _x[@ 5 + _a] = (_option.action == _a) ? 1 : 0;
    return _x;
}
```

---

## Learning Sequences

The models above see one moment at a time. The two sequence learners also see what came just before: the decision-maker's last few choices. That's how a model learns "after jab, jab, an uppercut" or "after a sword, the cheapest potion".

- **N-gram:** learns which action follows which, in which situation. Learns from dozens of choices, explains itself in plain words, and one model holds many habits at once.
- **TDNN:** a neural network over the last few choices, the situation and each option's own inputs. Learns which target, and patterns where the moves in between don't matter. Needs hundreds of choices.

Both learn from choices and from outcomes, save and load, explain, and work as re-rankers and predictor inputs like every other model.

```gml
// the player's fighting habits, read by the boss
global.habits = gmsa_learn_ngram_create({ length : 4 });

// each move the player makes
gmsa_learn_observe(global.habits, gmsa_observe(player_agent, moves, _picked));

// the boss reads it: how likely is an uppercut next
gmsa_profile_add_input(_boss, gmsa_input_pull("uppercut_next", gmsa_learn_input(global.habits, player_agent, "uppercut")));

// or a hint, only when the model is sure
var _out = gmsa_learn_predict(global.habits, gmsa_agent_evaluate(player_agent));
if (_out.sure >= 0.6) hint = "Watch out for the " + moves[_out.best];
```

### Choosing between them

Accuracy predicting the next choice in testing, with the default settings, over choices 25 to 100 and 200 to 600 (simulated players, 1 choice in 10 random, so the best possible is about 0.92; the opener pattern has no randomness, its best is 1):

| Pattern | N-gram | TDNN |
| --- | --- | --- |
| Shop habits: a sword, then a shield, then a potion when hurt | 0.88 / 0.91 | 0.83 / 0.91 |
| Combos: jab, jab, uppercut up close, kick and dodge from afar | 0.86 / 0.92 | 0.72 / 0.85 |
| The situation only, no order | 0.84 / 0.86 | 0.71 / 0.84 |
| An opener, three random moves, the opener again (length 4) | 0.19 / 0.51 | 0.73 / 1.00 |
| After a sword, the cheapest potion | 0.32 / 0.31 | 0.76 / 0.91 |

- **Start with the n-gram.** It learns plain habits from a few dozen choices, and one model learns many kinds at once: in testing, one n-gram learning seven different habits from one player reached 0.82, where the best its view allows is 0.86.
- **Use the TDNN** when the choice is about which target ("the cheapest potion", "the nearest enemy"), when patterns skip moves, or when the game runs long enough to give it hundreds of choices. On the seven-habit player it reached 0.73 after 1,500 choices.
- **Both at once is fine.** One recorded choice can teach both, as in Demo 16.

### Histories

- **Each agent has its own history,** kept on the agent, so it goes when the agent goes. With choices, it's the order of `gmsa_learn_observe` calls for that agent. With outcomes, it's the agent's own tracked decisions, so the tracker must keep more decisions than the history is long: `gmsa_learn_track(agent, { size : length + 1 })` at least, or the learner throws and names the size to use.
- **The start counts.** A new agent, the first choice after a break, and the first after a reset or load are learned as "at the start", so the first move of a fight is a habit too.
- **Breaks:** call `gmsa_learn_ngram_break` or `gmsa_learn_tdnn_break` where a chain of choices ends in your game: a new round, a death, the shop closing. What comes next starts a new history.
- **Time isn't recorded.** If "how long since the last purchase" matters, add it as an input from your game's own clock and the learner uses it like any other.
- **Repeated moves need `gmsa_agent_clear_current` after each one** when learning outcomes. Otherwise jab, jab is one decision that went on, not two, see [gmsa_learn_track](#gmsa_learn_track).
- **Re-ranking uses the agent's own history.** A boss re-ranked by a model of the player's habits would read the boss's history, not the player's. To use the player's sequences in another agent's decisions, read them with [gmsa_learn_input](#gmsa_learn_input) on the player's agent, as in the example above.
- **Learn spaces are refused,** with an error: a space has no agent, so its choices would chain into nonsense.

### gmsa_learn_ngram_create

```gml
gmsa_learn_ngram_create([params]) -> model
```

| Param | Type | Default | Description |
| --- | --- | --- | --- |
| `length` | integer | 3 | The most past choices a context looks at |
| `bins` | integer | 8 | The finest cut of each situational input |
| `inputs` | array | all situational | Names of the inputs that describe the situation |
| `capacity` | integer | 4096 | The most contexts kept, the least recently used are forgotten first |
| `blend_k` | real | 3 | Evidence a context needs before its own blend outweighs the shared one, 0 or more |
| `half_life` | real | 50 | The times a moment comes up after which its old evidence counts half |
| `learns`, `temperature` | | `CHOICES`, 0.1 | Learning from outcomes, see [How each model learns outcomes](#how-each-model-learns-outcomes) |

No setting has an upper limit: the same learner may serve a thousand goblins or one boss reading long move strings, so the size is yours to choose.

How it works:
- **A context is a moment:** the last few choices (none up to `length`) together with the situation cut at one resolution (not at all, then halves, quarters, eighths, up to `bins`). Every combination is a context, and each counts what was chosen in it, or the rewards that followed with outcomes.
- **Each context starts from a blend of its two parents,** the context with one choice less of history and the one with a coarser situation, and is pulled toward its own counts by how much it has seen. A moment it has seen often speaks for itself, a new one leans on what it resembles.
- **Each context learns its own blend** from which parent foresaw what happened there. "After a heavy attack" learns to trust the history, "when hurt" learns to trust the situation, in the same model. Until a context has evidence, it uses the blend shared by contexts at its place.
- **A context fades when it comes up again,** not with every choice, so a moment that comes up 1 time in 20 keeps its evidence. The cost: after a habit changes, a moment's old evidence fades only as that moment comes up again. In testing a changed habit was learned at 0.65 in the first 100 choices, then 0.87.
- **Actions, not targets:** per-target inputs are ignored, and options with the same action share its probability.
- **Confidence is per moment:** how much of the estimate comes from the contexts' own data, more specific contexts counting more.
- The inputs it uses are fixed the first time it's used.
- Saves keep the contexts, not the histories.

Explain names the context with the most weight in the estimate, and whether the full estimate agrees with it:

```
hp 50-75%, distance 75-100%, after potion then shield then kick: kick 3.0 of 3.0, the rest agree (p 0.99)
after feint then sweep: heavy averages +0.95 from 12.0 outcomes
```

**Choosing the settings:**
- **`length`** is the longest pattern it can learn: 1 learns what follows the last move, 3 learns patterns of four moves, such as jab, jab, uppercut, then a dodge. Longer needs more choices per context and multiplies the contexts, so match it to the longest pattern your game has. In testing, length 8 learned 3-move combos as well as length 3.
- **`bins`** is the finest detail. Coarse cuts speak first and finer ones take over where data piles up, so a high value costs little accuracy early.
- **`capacity`:** contexts grow with `length`, the number of inputs and the number of actions. At length 3 with 1 input and 4 actions, 800 choices made 820 contexts. Length 8, or 4 inputs, filled 4,096. A full model forgets a tenth of its contexts at once, a 6 to 11 ms step on the VM about every 20 choices, so a smaller capacity means smaller steps.
- **`half_life`:** longer remembers many rare habits better (100 instead of 50 raised the seven-habit test from 0.79 to 0.82) and relearns a changed habit more slowly.

**Throws** when `length`, `bins` or `capacity` isn't a whole number of 1 or more, `blend_k` is negative, or `inputs` isn't an array. When learning outcomes, learning or predicting throws if the agent isn't tracked or its tracker keeps `length` decisions or fewer.

### gmsa_learn_ngram_break

```gml
gmsa_learn_ngram_break(model, agent)
```

Ends the agent's chain of choices for this model: the next choice is learned as the first. With outcomes, the agent's tracked decisions from before the break no longer count as history.

**Throws** when `model` isn't an n-gram model, or `agent` belongs to a learn space.

### gmsa_learn_tdnn_create

```gml
gmsa_learn_tdnn_create([params]) -> model
```

A time-delay neural network (Waibel et al. 1989): one network looks at a fixed window of the last choices.

| Param | Type | Default | Description |
| --- | --- | --- | --- |
| `length` | integer | 3 | Past choices the network sees |
| `layers` | array | `[16]` | Hidden layer sizes |
| `learn_rate` | real | 0.01 | Step size of each update |
| `replay` | integer | 4 | Earlier choices learned from again per choice, 0 for none |
| `memory` | integer | 64 | The most recent choices replays are picked from |
| `remember` | array | `[]` | Names of inputs to remember from each past choice, such as `price` |
| `familiar_depth` | integer | 1 | Past choices that describe a kind of moment, for confidence, 0 for the situation alone |
| `familiar_bins` | integer | 2 | The cut of each situational input, for confidence |
| `familiar_k` | real | 3 | Times a kind of moment must come up for 50% familiarity |
| `familiar_capacity` | integer | 1024 | The most kinds of moment remembered |
| `activation` | `gmsa_net_activation` | `LEAKY_RELU` | Hidden layer activation |
| `optimizer` | `gmsa_net_optimizer` | `ADAM` | How the network applies what it learns |
| `seed` | integer | 1 | Starting weights and replay picks, same seed and same choices give the same model |
| `half_life` | real | 200 | Observations after which old evidence counts half, for confidence and familiarity |
| `confidence_k` | real | 50 | Observations needed for 50% of the model-wide confidence |
| `learns`, `temperature` | | `CHOICES`, 0.1 | Learning from outcomes, see [How each model learns outcomes](#how-each-model-learns-outcomes) |

How it works:
- **The network scores each option** from the situation, the option's own inputs, which action it is, and the last `length` choices: each one's action and the inputs named in `remember`. With choices the options compete through a softmax, with outcomes the score is the expected reward.
- **Each choice is learned at once,** inside `gmsa_learn_observe`. It also picks `replay` earlier choices from the last `memory` to learn from again, queued until the model gets training time from [gmsa_learn_train](#gmsa_learn_train) or [gmsa_learn_schedule](#gmsa_learn_schedule). Without training time it still learns, like `replay : 0`. A backlog nobody trains keeps its newest `memory` replays.
- **Old habits fade as they leave the memory,** so a changed habit is relearned in about 100 choices at the default `memory`.
- **Confidence is how much it has learned, scaled down in unfamiliar moments:** `samples / (samples + confidence_k)` times `n / (n + familiar_k)`, where `n` is how often this kind of moment came up (the last `familiar_depth` choices and the situation in `familiar_bins` bins). A network's outputs show what it prefers but not how new a moment is: networks can be confident on inputs unlike anything they learned from ([Guo et al. 2017](https://arxiv.org/abs/1706.04599), [Nguyen et al. 2015](https://arxiv.org/abs/1412.1897)).
- **Its `sure` climbs more slowly than the n-gram's.** Options that differ only by an input, like potions by price, are separated gradually: in Demo 16 it picked the right potion every time after about 90 buys, while giving it only 0.37. Under-confident early is the safe direction for hints.
- Situational inputs are centred inside the network. Nothing to set.
- Saves keep the network and the familiarity counts. The replay memory and the histories start empty after a load.

Explain shows what each part adds to the option's score: each input, and each past choice:

```
potion: 1 back: sword +3.73, 3 back: potion +1.09, 2 back: potion -0.26, score +4.79 (p 0.37)
```

**Choosing the settings:**
- **`replay`** makes it learn several times faster from the same choices: after 25 to 50 choices of boss combos, 0.53 with replays against 0.36 without. 8 or 16 were barely better than 4 and cost more.
- **`memory`:** 64 relearned a changed habit in about 100 choices. 256 was 0.03 better on habits that never change but took over 200 choices to relearn.
- **`layers`:** `[16]` learned as well as `[32, 16]` everywhere but the first 100 choices of the potion test (0.81 against 0.90), at about a fifth of the cost.
- **`activation`:** leaky ReLU learned faster than tanh in every test, and tanh sometimes stopped telling options apart on clean, rule-like habits.
- **`remember`** when what comes next depends on what past choices were like, not just which they were: "after something expensive, the cheapest". With `remember : ["price"]` this was learned in 98 to 100% of test runs after 450 choices, and in none without.
- **`length`** as for the n-gram. Each step adds a slot per action, one for the start, and one per remembered input: length 8 cost about 1.7 times length 3.

**Throws** when `length` or `memory` isn't a whole number of 1 or more, `replay` or `familiar_depth` isn't a whole number of 0 or more, `layers` isn't an array of whole numbers of 1 or more, `learn_rate` or `familiar_k` isn't above 0, `familiar_bins` or `familiar_capacity` isn't a whole number of 1 or more, `remember` isn't an array of names, or the network settings are invalid. Loading throws when the save remembers different inputs or the layers differ.

### gmsa_learn_tdnn_break

```gml
gmsa_learn_tdnn_break(model, agent)
```

As [gmsa_learn_ngram_break](#gmsa_learn_ngram_break), for a TDNN.

### What sequence learners cost

Measured on the VM target, per call, with a player of 4 actions and 1 input after 800 choices, unless the row says otherwise:

| | Predict | Observe | Training per choice |
| --- | --- | --- | --- |
| N-gram, length 1 | 121 us | 145 us | |
| N-gram, length 3 | 205 us | 267 us | |
| N-gram, length 8 | 366 us | 657 us | |
| N-gram, length 3, 4 inputs | 201 us | 367 us | |
| N-gram, length 3, 12 actions | 363 us | 453 us | |
| N-gram, length 8, 4 inputs, 12 actions | 476 us | 1248 us | |
| TDNN, `replay` 0 | 335 us | 1314 us | none |
| TDNN, `replay` 4 | 339 us | 1319 us | 4.9 ms |
| TDNN, `replay` 8 | 341 us | 1323 us | 9.9 ms |
| TDNN, length 8 | 538 us | 2302 us | 8.7 ms |
| TDNN, 4 inputs | 438 us | 1627 us | 6.1 ms |
| TDNN, 12 actions | 1152 us | 4023 us | 15.1 ms |
| TDNN, `layers` `[32, 16]` | 1219 us | 5562 us | 21.9 ms |

- **The n-gram suits many agents and every frame,** the TDNN a few predictions at a time, a shop or a boss. Predictor inputs cache their prediction per frame, so many agents reading one costs one prediction.
- **The TDNN's training per choice is spread by the budget** you give it, see [gmsa_learn_schedule](#gmsa_learn_schedule). Keep its options few: its cost grows with every option on offer.
- **A full n-gram** (here length 8, or 4 inputs) forgets a tenth of its contexts about every 20 choices, the slowest observe then taking 6 to 11 ms. The defaults at length 3 and 1 input never fill.

### Good to know

- **Outcome learners learn only what the agent tries.** A move that pays off in one rare moment and is bad everywhere else is seldom tried there, so it's learned slowly or not at all. In testing, "a heavy attack lands after a feint and a sweep", a moment that came up 2% of the time, was the model's favourite there only about 30% of the time even after 1,500 moves. Exploration is the agent's selection, see [Fair learning and exploration](#fair-learning-and-exploration).
- **Hints and thresholds read `sure`, not `confidence`,** see [gmsa_learn_predict](#gmsa_learn_predict).
- **A history is per model and per agent.** Two models watching one player keep two histories, both on the player's agent.

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

## Plan

Planning for goals that take several steps: get the key, get through the door, open the chest. Utility scoring decides *what* an agent wants, Plan works out *how*, in two ways that mix freely:

- **Recipes (HTN, hierarchical task networks):** the designer writes the ways to do a job, the planner picks the ones that work right now.
- **Goals (GOAP, goal-oriented action planning):** the designer only describes what each step needs, does and costs, and names the result wanted. The planner searches for the cheapest chain of steps that gets there. See [Goals](#goals).

Either way, the planner keeps the plan working while the world changes.

The Plan module depends on Core only, Core never depends on it. It never touches your game: it reads facts through your callbacks, hands you one step at a time, and you report how it went. Inspired by [urosidoki/htn_planner](https://github.com/urosidoki/htn_planner).

**Words used here:**
- A **fact** is a number or a bool the planner reasons with, read from your game by a callback (`gold`, `has_key`).
- A **step** is something your game performs (`pick_up_key`). It can require facts and change them.
- A **task** is a job with recipes (`loot_chest`). Its **methods** are the recipes for it, each a list of steps, smaller tasks and goals.
- A **goal** is a result wanted (`chest_open` is true), reached by a chain of steps the planner finds itself.
- A **plan** is the steps the planner chose, in order.

```gml
// once, shared by every goblin
var _d = gmsa_plan_domain_create("goblin");
gmsa_plan_add_fact(_d, "has_key", function(_owner) { return _owner.has_key; });
gmsa_plan_add_fact(_d, "gold",    function(_owner) { return _owner.gold; });

gmsa_plan_add_step(_d, "go_to_key");
gmsa_plan_add_step(_d, "pick_up_key", { effects : [["has_key", true]] });
gmsa_plan_add_step(_d, "buy_key",     { requires : [["gold", ">=", 10]], effects : [["gold", "-", 10], ["has_key", true]] });
gmsa_plan_add_step(_d, "open_chest",  { requires : [["has_key", true]] });

var _loot = gmsa_plan_add_task(_d, "loot_chest");
gmsa_plan_add_method(_loot, "have_key", { requires : [["has_key", true]], subtasks : ["open_chest"] });
gmsa_plan_add_method(_loot, "buy",      { subtasks : ["buy_key", "open_chest"] });
gmsa_plan_add_method(_loot, "fetch",    { subtasks : ["go_to_key", "pick_up_key", "open_chest"] });
global.goblin_domain = gmsa_plan_domain_build(_d);

// Create: one planner per goblin, facts are read from the goblin
planner = gmsa_plan_planner_create(global.goblin_domain, id);
gmsa_plan_make(planner, "loot_chest");

// Step: do the current step, report when it's over
switch (gmsa_plan_current(planner)) {
    case "go_to_key":
        if (move_towards(key_x, key_y)) gmsa_plan_step_done(planner);
        break;
    case "pick_up_key":
        has_key = true;
        gmsa_plan_step_done(planner);
        break;
    // ...
}
```

### The workflow

1. **Build a domain once** and share it, like a profile: facts, steps, tasks and their methods.
2. **Create a planner per owner.** The owner is your instance or struct, facts are read from it.
3. **Make a plan** with `gmsa_plan_make` when the agent wants the task or goal done.
4. **Do the current step** in your game. Report it with `gmsa_plan_step_done` or `gmsa_plan_step_failed`. Change the facts the step changes before reporting it done.
5. **Refresh** with `gmsa_plan_refresh` when the world changes under a step (the player took the key). The plan repairs itself.
6. **Stop** with `gmsa_plan_stop` when the agent wants something else.

Plans are made at once by default. For large domains or many planners, they can be made across frames, see [Planning across frames](#planning-across-frames).

### Working with utility

Utility picks what to do, the game asks for the plan. Core never knows Plan exists, the bridge is one call in your code:

```gml
var _decision = gmsa_agent_consume(agent);
if (_decision != undefined) {
    var _option = gmsa_decision_get_chosen(_decision);
    if (_option != undefined) {
        gmsa_agent_set_current_option(agent, _option);
        if (_option.action.name == "loot") {
            // keep a running plan, utility choosing loot again isn't a reason to start over
            if (gmsa_plan_get_status(planner) != gmsa_plan_status.RUNNING) gmsa_plan_make(planner, "loot_chest");
        } else {
            gmsa_plan_stop(planner);  // fleeing beats looting, drop the plan
        }
    }
}
```

Holding two plans at once (one paused, one running) is two planners.

### gmsa_plan_domain_create

```gml
gmsa_plan_domain_create(name) -> domain
```

A new, empty domain. **Throws** when `name` isn't a non-empty string.

### gmsa_plan_add_fact

```gml
gmsa_plan_add_fact(domain, name, read, [params]) -> domain
```

| Parameter | Type | Description |
| --- | --- | --- |
| `name` | string | The fact's name, used in conditions and effects |
| `read` | function | `function(owner)` returning a number or a bool, called when planning and before each step |

| Param | Type | Default | Description |
| --- | --- | --- | --- |
| `min`, `max` | real | undefined | The fact's usual range. Planning ignores it, learning needs it to turn a number into 0..1, see [PlanLearn](#planlearn). Give both or neither |

**Throws** when the domain is built, the name is empty, `read` isn't callable, only one of `min` and `max` is given, or `max` isn't above `min`.

### gmsa_plan_add_step

```gml
gmsa_plan_add_step(domain, name, [params]) -> step
```

| Param | Type | Default | Description |
| --- | --- | --- | --- |
| `requires` | array | `[]` | Conditions that must hold before the step, see [Conditions and effects](#conditions-and-effects) |
| `effects` | array | `[]` | How the step changes facts when it's done |
| `check` | function | undefined | `function(state)` returning true when the step can be done, for conditions data can't express. See [Check functions](#check-functions) |
| `targets` | function | undefined | `function(owner)` returning an array of candidates, read when the step becomes current |
| `score` | function | undefined | `function(owner, target)` returning a number, picks the target. See [Targets](#targets) |
| `cost` | real or function | 1 | What the step costs when a goal searches: a number above 0, or `function(owner, state)` returning one (0 or less rules the step out in that state). Recipes ignore it. See [Goals](#goals) |

**Throws** when the domain is built or the name is empty. Everything else is checked at build.

### gmsa_plan_add_task

```gml
gmsa_plan_add_task(domain, name, [params]) -> task
```

A goal, broken down by the methods you add to it. Step and task names share one namespace, each must be unique.

| Param | Type | Default | Description |
| --- | --- | --- | --- |
| `select` | `gmsa_select` | `BEST` | `BEST` tries methods best score first. `TOP_N_WEIGHTED` draws the order among the top `top_n` by score, see [Method order](#method-order) |
| `top_n` | integer | 3 | How many top methods the weighted draw covers |
| `adjust` | function | undefined | `function(planner, state, scores)`, changes the methods' scores before they're ordered, see [Adjusting scores](#adjusting-scores) |

**Throws** when the domain is built, the name is empty, `select` isn't `BEST` or `TOP_N_WEIGHTED`, `top_n` is below 1 or `adjust` isn't callable.

### gmsa_plan_add_method

```gml
gmsa_plan_add_method(task, name, params) -> method
```

| Param | Type | Default | Description |
| --- | --- | --- | --- |
| `subtasks` | array | `[]` | Names of steps and tasks, in order. Empty for "nothing to do", such as a method for when the key is already in hand |
| `requires` | array | `[]` | Conditions for using this method |
| `check` | function | undefined | `function(state)`, like a step's |
| `score` | function | undefined | `function(owner, state)` returning a number. See [Method order](#method-order) |

A method may use its own task in `subtasks` ("grab a coin, then grab the rest"), the planner's depth cap stops endless recursion.

**Throws** when `task` doesn't come from `gmsa_plan_add_task`, its domain is built or the name is empty.

### gmsa_plan_add_goal

```gml
gmsa_plan_add_goal(domain, name, params) -> goal
```

A result wanted, reached by a chain of steps the planner searches for. Make it the root of a plan with `gmsa_plan_make(planner, name)`, or put its name in a method's `subtasks`. Goals share one namespace with steps and tasks.

| Param | Type | Default | Description |
| --- | --- | --- | --- |
| `conditions` | array | | What must hold when the chain is done, written like `requires`, see [Conditions and effects](#conditions-and-effects). At least one |
| `actions` | array | every step | Names of the steps the search may use. In a domain that mixes recipes and goals, keep a goal to its own steps |
| `variety` | real | 0 | Each search multiplies every step's cost by a random factor between 1 and 1 + `variety`, so identical agents don't all take the same route. See [Variety](#variety) |
| `prune` | bool | true | Leave out steps that can never help reach the conditions. See [Pruning](#pruning) |

**Throws** when the domain is built or the name is empty. Everything else is checked at build.

### gmsa_plan_domain_build

```gml
gmsa_plan_domain_build(domain) -> domain
```

Checks the whole domain, turns every name into an index and locks it. Nothing changes unless all of it is valid.

**Throws** when the domain has no steps, a name is used twice, a condition or effect is malformed or uses an unknown fact, a method uses an unknown step, task or goal, a task has no methods, a step's cost isn't above 0 or callable, a goal has no conditions, lists something that isn't a step or lists one twice, its `variety` is below 0 or its `prune` isn't a bool, or a callback isn't callable.

### gmsa_plan_fact_index

```gml
gmsa_plan_fact_index(domain, name) -> integer
```

A fact's position in the state array check functions receive, -1 when unknown. Available after build.

### gmsa_plan_add_listener

```gml
gmsa_plan_add_listener(domain, listener)
```

`listener` is `function(report)`, called by every planner of the domain when a method or step succeeds or fails, and when a reward arrives. See [Reports](#reports). Listeners can be added before or after build, and run in the order added.

**Throws** when `domain` isn't a domain or `listener` isn't callable.

### gmsa_plan_set_step_chance

```gml
gmsa_plan_set_step_chance(domain, chance)
```

`chance` is `function(planner, step, state)` returning a step's chance of success, 0 to 1. `step` is the step's index in `domain.steps`, `state` the imagined facts. When a task is planned, each method's score is multiplied by the chance of each step directly in its subtasks (steps inside nested tasks count when their own task is planned). A method whose steps tend to fail sinks in the order. When a goal searches, each step's cost is divided by its chance, so a step that works half the time costs twice as much, and one that never works is left out. Pass `undefined` to remove it. One per domain, set before or after build.

[gmsa_plan_learn_steps](#gmsa_plan_learn_steps) sets one that learns the chances from the plans' own results.

**Throws** when `domain` isn't a domain or `chance` isn't callable.

### Conditions and effects

Both are arrays of small arrays, built into flat number arrays so planning allocates nothing.

| Form | Meaning |
| --- | --- |
| `["has_key", true]` | Condition: the fact equals the value |
| `["gold", ">=", 10]` | Condition with an operator: `==`, `!=`, `<`, `<=`, `>`, `>=` |
| `["has_key", true]` in `effects` | Effect: the fact becomes the value |
| `["gold", "-", 10]` | Effect with an operator: `=`, `+`, `-` |

Values are numbers or bools, bools are stored as 1 and 0. Every condition of a list must hold.

### Check functions

For conditions data can't express. A check receives the imagined state as an array of numbers, one per fact in the order they were added. Read it, never write it:

```gml
var _gold = 1;  // gold was the second fact added, or use gmsa_plan_fact_index after build
gmsa_plan_add_step(_d, "bribe_guard", {
    check : method({ gold : _gold }, function(_state) { return _state[gold] >= global.bribe_price; }),
});
```

A check is invisible to [gmsa_plan_explain](#gmsa_plan_explain) beyond "its check failed", so prefer `requires` when it can say the same.

### gmsa_plan_planner_create

```gml
gmsa_plan_planner_create(domain, owner, [params]) -> planner
```

| Parameter | Type | Description |
| --- | --- | --- |
| `domain` | struct | A built domain |
| `owner` | instance or struct | What facts, targets and scores read from |

| Param | Type | Default | Description |
| --- | --- | --- | --- |
| `budget` | integer | 250 | Nodes one planning call may use, see [What planning costs](#what-planning-costs) |
| `depth` | integer | 32 | How deep tasks may nest, the cap for tasks that use themselves |
| `retries` | integer | 3 | Failed steps in a row before the plan fails. A done step resets the count |
| `slice` | real | undefined | Microseconds of planning per call. Undefined plans at once. See [Planning across frames](#planning-across-frames) |
| `clock` | function | `get_timer` | Time source returning microseconds, used only when planning in slices. Tests pass a fake clock |
| `seed` | integer | 1 | Seeds the planner's own generator, used by tasks with `TOP_N_WEIGHTED`. GameMaker's `random` is never touched |

**Throws** when the domain isn't built, a param is out of range, `slice` isn't above 0 or `clock` isn't callable.

### gmsa_plan_make

```gml
gmsa_plan_make(planner, name) -> bool
```

Reads the facts, plans the named task, goal or single step and starts the plan, replacing whatever was running, or a plan being made. **Returns** true when the plan started or is being made, false when planning already failed. When it fails, `gmsa_plan_last_result` and `gmsa_plan_explain` say why.

- Without a slice, the whole plan is made in this call.
- With a slice, this call plans for one slice. A plan that isn't ready yet leaves the status `PLANNING`, and `gmsa_plan_work` carries on.
- A scheduled planner only reads the facts here, the scheduler makes the plan.

**Throws** when the domain has no step or task with that name.

### gmsa_plan_current

```gml
gmsa_plan_current(planner) -> string
```

The name of the step your game should be doing, undefined unless a plan is running.

### gmsa_plan_target

```gml
gmsa_plan_target(planner) -> any
```

The target picked for the current step, undefined when the step has no targets or no plan is running.

### gmsa_plan_step_done

```gml
gmsa_plan_step_done(planner) -> gmsa_plan_status
```

The current step is finished. The facts are read again and the rest of the plan is checked against them, a broken plan is repaired. **Returns** the new status, `PLANNING` when a sliced or scheduled planner needs more time for the repair. Does nothing unless a plan is running, so a late report after `gmsa_plan_stop` is harmless.

### gmsa_plan_step_failed

```gml
gmsa_plan_step_failed(planner) -> gmsa_plan_status
```

The current step couldn't be done. The smallest task around it is planned again from the real facts. Each failure in a row uses one retry. **Returns** the new status, possibly `PLANNING`.

### gmsa_plan_refresh

```gml
gmsa_plan_refresh(planner) -> gmsa_plan_status
```

Reads the facts now and repairs the plan if they broke it. Call it when something changed during a step, such as the player taking the key the goblin is walking to. Facts that changed without breaking the plan change nothing. **Returns** the status, possibly `PLANNING`.

### gmsa_plan_stop

```gml
gmsa_plan_stop(planner)
```

Drops the plan, or the plan being made or repaired. The status becomes `IDLE`. Nothing is reported, an interruption isn't a failure.

### gmsa_plan_reward

```gml
gmsa_plan_reward(planner, reward) -> integer
```

Something good or bad happened that the plan earned: the loot made it home, the raid took too long. Listeners receive a `METHOD_REWARD` report for each method it reaches:

- While a plan runs or is being repaired, the methods around the current step, from its own task up to the top of the plan.
- Once the plan is done, every method of the plan, once each.

**Returns** how many methods it reached, 0 when there's no plan. Rewards are numbers you choose, roughly -1 to 1, as in [Rewards](#rewards).

**Throws** when `reward` isn't a number.

### gmsa_plan_get_status

```gml
gmsa_plan_get_status(planner) -> gmsa_plan_status
```

### gmsa_plan_last_result

```gml
gmsa_plan_last_result(planner) -> gmsa_plan_result
```

How the last planning call (a make or a repair) went.

### gmsa_plan_position

```gml
gmsa_plan_position(planner) -> integer
```

How many steps of the plan come before the current one.

### gmsa_plan_length

```gml
gmsa_plan_length(planner) -> integer
```

Steps in the plan, done ones included, 0 when there's none. After a repair it counts the repaired plan.

### gmsa_plan_step_at

```gml
gmsa_plan_step_at(planner, index) -> string
```

The name of the plan's step at `index`, undefined when out of range.

### gmsa_plan_nodes_used

```gml
gmsa_plan_nodes_used(planner) -> integer
```

Nodes the last planning call used, for tuning the budget.

### gmsa_plan_work

```gml
gmsa_plan_work(planner, [budget]) -> gmsa_plan_status
```

Carries on making or repairing a plan for up to `budget` microseconds, the planner's `slice` by default. Does nothing unless the status is `PLANNING`. Every call makes progress, even with a tiny budget. **Returns** the new status.

**Throws** when `budget` isn't above 0.

### gmsa_plan_schedule

```gml
gmsa_plan_schedule(planner, scheduler, [priority]) -> planner
```

The scheduler makes and repairs this planner's plans inside its budget, taking turns with the agents, see [gmsa_scheduler_add_work](#gmsa_scheduler_add_work). Your own calls (`gmsa_plan_make`, `gmsa_plan_step_done`, ...) still read facts and check the plan, but never search: when planning is needed they return `PLANNING` and the scheduler carries on. The planner's `slice`, when set, caps each of its turns.

**Throws** when the planner is already scheduled.

### gmsa_plan_unschedule

```gml
gmsa_plan_unschedule(planner) -> bool
```

Takes the planner out of its scheduler, it plans inside your calls again. **Returns** false when it wasn't scheduled.

### gmsa_plan_lines

```gml
gmsa_plan_lines(planner) -> array
```

The plan as data, one struct per line, for your own UI or [gmsa_debug_draw_tree](#gmsa_debug_draw_tree). `gmsa_plan_explain` is these lines as text.

| Field | Description |
| --- | --- |
| `kind` | `"title"`, `"note"`, `"reason"`, `"task"`, `"goal"`, `"skipped"`, `"step"`, `"done"` or `"current"` |
| `depth` | Nesting, 0 at the top |
| `text` | The name or sentence, without indentation or markers |
| `repaired` | True for what the last repair put in, until the next step is done |
| `progress` | On the title while planning, 0 to 1 of the node budget. Undefined otherwise |

A new array each call: meant for debugging and UI, not for every agent every frame.

### gmsa_plan_explain

```gml
gmsa_plan_explain(planner) -> string
```

The goal, the status and the plan as a tree: each task with the method it uses, the methods tried before it with the reason they didn't work, the steps marked done, and `>` on the current one. Every line keeps a two character slot for the arrow, so indentation always shows the nesting.

```
loot_chest (running, step 2 of 3)
  loot_chest: fetch
    have_key skipped: has_key is false, needs true
    buy skipped: buy_key: gold is 3, needs at least 10
    go_to_key, done
  > pick_up_key
    open_chest
```

Reasons are judged on the facts as they were when that task was planned. A skipped method shows its first failing condition, otherwise its first step that couldn't be done, otherwise that the rest of the plan didn't work with it. Methods ruled out by a score of 0 are listed as such, and the chosen method shows its score when the task has scored methods.

When no plan was found, it lists each of the task's methods with its reason instead, or for a goal, what the search couldn't reach (see [Goals](#goals)). While planning, it's the title only, such as `loot_chest (planning, 140 of 250 nodes)`.

### Method order

A task's methods are tried in the order you added them, the first that leads to a whole plan wins. Give methods a `score` and they're tried best first instead, so the situation decides between "steal the key" and "buy the key":

```gml
gmsa_plan_add_method(_get_key, "steal", { score : function(_owner, _state) { return _owner.sneaky; }, subtasks : ["sneak", "steal_key"] });
gmsa_plan_add_method(_get_key, "buy",   { score : function(_owner, _state) { return 1 - _owner.sneaky; }, subtasks : ["buy_key"] });
```

- A method without a score counts as 1. Ties keep your order.
- A score of 0 or less rules the method out, like a 0 in utility scoring.
- Scores are read in the imagined state, when the planner reaches the task. A method early in the plan sees today's facts, one later sees the facts the plan expects by then.

**Weighted order.** A task with `select : gmsa_select.TOP_N_WEIGHTED` doesn't always try its best method first. Its top `top_n` methods are put in a random order drawn by score (a method with twice the score is twice as likely to go first), the rest follow best first. Goblins with the same recipes then don't all do the same thing, and a learning model gets to see every recipe tried.

- The draw uses the planner's own generator, seeded with `seed`. The same seed and the same facts give the same plans.
- Backtracking works as always: when the drawn method can't work, the next in the drawn order is tried.
- Each chosen method knows its **chance**: its score over its own and every later method's in the drawn order. Explain shows it as `(score 0.60, chance 0.45)`, and reports carry it.

### Adjusting scores

When the planner reaches a task, the scores go through these stages, in order:

1. Each method's `score`, or 1.
2. The domain's [step chance](#gmsa_plan_set_step_chance), multiplied in for each step directly in the method.
3. The task's `adjust`, which sees and changes every score at once.
4. The order: best first, or the weighted draw.

```gml
var _fight = gmsa_plan_add_task(_d, "fight", {
    adjust : function(_planner, _state, _scores) {
        // late in the night, every method but the first (sneak) is less appealing
        if (global.hour > 3) for (var _i = 1; _i < array_length(_scores); _i++) _scores[@ _i] *= 0.5;
    },
});
```

`scores` holds one number per method, in the order the methods were added. Write it with `[@ ]`. A score of 0 or less rules the method out, as always. [gmsa_plan_learn_methods](#gmsa_plan_learn_methods) is an `adjust` that learns.

### How planning works

The planner goes depth first: it breaks the task into its first method's subtasks, then the first of those, and so on, imagining each step's effects. When a step or method can't be used in the imagined state, it backs up to the latest task that has another method left and tries that. This can undo a task that already looked finished, when a later step needs it done differently.

- **Nodes.** Every step and every method tried costs one node. A planning call stops with `OUT_OF_BUDGET` when it has used its budget, it never goes over.
- **Depth.** A task nested deeper than the planner's `depth` fails that branch only, the search goes on elsewhere.
- **No allocations.** The imagined state, the to-do list, the choices and the plan live in arrays the planner reuses. Planning allocates nothing after its first calls.

### How a running plan repairs itself

Before each step the planner reads the facts again and checks the rest of the plan against them. When the plan still works, nothing changes, even when facts did (the goblin found gold, but it's already fetching the key). When a step can't be done anymore, or your game reports a failure:

1. The smallest task around the broken step is planned again. A task later in the plan is planned as if the steps before it were done, and the current step carries on. A task the current step belongs to starts over from the real facts.
2. The new part is kept only if the rest of the plan still works after it.
3. Otherwise the next larger task is tried, up to the top of the plan. If that can't be planned, the plan fails.

A goal is repaired the same way: a broken step in its chain makes the goal search again from the real facts, the rest of the plan stays.

Repairs share one budget per call. `gmsa_plan_make` plans from scratch instead, which can pick a better plan than the one being repaired.

### Reports

Listeners added with [gmsa_plan_add_listener](#gmsa_plan_add_listener) hear how plans go, from every planner of the domain. This is what learning is built on, and you can use it for your own stats or logs.

| Report | When |
| --- | --- |
| `STEP_SUCCESS` | `gmsa_plan_step_done` |
| `STEP_FAILURE` | `gmsa_plan_step_failed`, or the step had no target |
| `METHOD_SUCCESS` | The plan passed the end of a task: the method did its job. A method with no subtasks succeeds at once |
| `METHOD_FAILURE` | A repair replaced the method: each method around the broken step, up to the task that was planned again. This includes repairs after facts changed, the method didn't work out in the world as it is. When the plan fails, each method up to the top |
| `METHOD_REWARD` | `gmsa_plan_reward` reached the method |
| `GOAL_SUCCESS` | The plan passed the end of a goal's chain |
| `GOAL_FAILURE` | A repair searched the goal again, or the plan failed with it. Like `METHOD_FAILURE`, including repairs after facts changed |

Not reported: `gmsa_plan_stop`, an interruption isn't a failure. A step that breaks because facts changed under it gets no `STEP_FAILURE`, the step itself never failed, but the methods the repair replaces are reported.

The report is one struct per planner, reused by every report, so copy what you keep:

| Field | Description |
| --- | --- |
| `kind` | `gmsa_plan_report` |
| `planner` | The planner that reported |
| `task`, `task_name` | The task's index in `domain.tasks`, and its name |
| `method`, `method_name` | The method's index in its task, and its name |
| `step`, `step_name` | The step's index in `domain.steps`, and its name. Step reports only |
| `chance` | The chance the method had of being chosen. 1 for `BEST` tasks, for methods tried after a weighted task's top `top_n`, and on step reports |
| `reward` | The reward, `METHOD_REWARD` only |
| `goal`, `goal_name` | The goal's index in `domain.goals`, and its name, on goal reports and on step reports from a goal's chain. -1 and undefined otherwise |
| `state` | The facts as the planner saw them when it planned this task or searched this goal (for steps, theirs), indexed like `domain.facts`. Read only |

```gml
// count which recipes finish, for a balance pass
gmsa_plan_add_listener(global.goblin_domain, function(_r) {
    if (_r.kind != gmsa_plan_report.METHOD_SUCCESS) return;
    var _key = _r.task_name + "." + _r.method_name;
    global.recipe_stats[$ _key] = (global.recipe_stats[$ _key] ?? 0) + 1;
});
```

Goals have no methods, so `gmsa_plan_reward` skips them and doesn't count them. On goal reports and the steps of a goal's chain, `task` is -1.

A domain with no listeners pays one array length check per reporting point.

### Planning across frames

A plan that needs hundreds of nodes, or a room where many goblins plan at once, can cost more than a frame should. Two ways to spread it out, both giving exactly the same plan, node for node, as planning at once:

**Slices.** Give the planner a `slice` and call `gmsa_plan_work` each step while it's planning:

```gml
planner = gmsa_plan_planner_create(global.goblin_domain, id, { slice : 300 });  // 0.3 ms per call

// Step
if (gmsa_plan_get_status(planner) == gmsa_plan_status.PLANNING) gmsa_plan_work(planner);
```

**The scheduler.** Schedule the planner, and the scheduler you already step every frame makes its plans inside its budget, taking turns with the agents:

```gml
gmsa_plan_schedule(planner, global.scheduler);
```

While a plan is being made or repaired:

- The status is `PLANNING`, `gmsa_plan_current` is undefined, and reports such as `gmsa_plan_step_done` are ignored. Keep the goblin idle, or doing what it was doing.
- The facts were read when planning started. A plan made over several calls is checked against fresh facts before it starts, and repaired if the world moved on.
- The node `budget` still caps the whole plan. The time slice only decides how much happens per call.

What isn't sliced: the node a call has already started, and finishing a plan (checking it against fresh facts and picking the first target, about 5 us per step of the plan). A call can therefore go over its slice by a few tens of microseconds for typical plans.

### Goals

A goal names a result, and the planner finds the steps. You write no recipe, only what each step needs, does and costs:

```gml
var _d = gmsa_plan_domain_create("escape");
gmsa_plan_add_fact(_d, "has_key",  function(_owner) { return _owner.has_key; });
gmsa_plan_add_fact(_d, "box_open", function(_owner) { return global.box_open; });
gmsa_plan_add_fact(_d, "out",      function(_owner) { return _owner.out; });

gmsa_plan_add_step(_d, "pry_box",     { effects : [["box_open", true]], cost : 4 });
gmsa_plan_add_step(_d, "take_key",    { requires : [["box_open", true]], effects : [["has_key", true]], cost : 1 });
gmsa_plan_add_step(_d, "unlock_door", { requires : [["has_key", true]], effects : [["out", true]], cost : 2 });
gmsa_plan_add_step(_d, "smash_window", { effects : [["out", true]], cost : function(_owner, _state) { return _owner.strong ? 3 : 12; } });
gmsa_plan_add_goal(_d, "escape", { conditions : [["out", true]] });
global.escape = gmsa_plan_domain_build(_d);

// a strong prisoner smashes the window (3), a weak one pries the box, takes the key and unlocks the door (4 + 1 + 2)
gmsa_plan_make(planner, "escape");
```

Everything else works as with recipes: you do one step at a time and report it, the plan repairs itself, it can be made across frames or in the scheduler, and explain shows it. A domain of facts, steps and goals only is plain GOAP, no tasks needed.

**Steps are your actions.** GOAP usually calls them actions, here they're the same steps recipes use. One `take_key` serves both.

#### How a goal searches

The planner runs an A* search over imagined states: from the facts as they are, it tries every allowed step whose `requires` hold, imagines its effects, and keeps going from the cheapest state so far until the conditions hold.

- **The chain found is the cheapest,** by your costs. Its guess of the cost still to go never overestimates, which is what guarantees it. One exception: a cost function returning less than the cheapest number cost among the goal's steps can make the guess too high, so the chain found may not be the very cheapest.
- **Costs are what you choose them to be.** Seconds of work, walking distance, risk, money. A cost function sees the imagined state, so a step can cost more or less depending on where the agent will be by then, for example through a fact holding its position.
- **Deterministic.** The same facts give the same chain. [Variety](#variety) adds controlled randomness.
- **Bounded.** Every step tried in a state costs one node of the planner's `budget`. A goal over many steps uses nodes much faster than a recipe, so give goal planners a larger budget (2000 to 8000 is typical) and plan across frames when chains get long. Searching remembers the states it has seen, in arrays sized by the budget and reused.
- **A goal already met** gives an empty chain, and a plan that's done at once.
- **Learned chances count.** With a [step chance](#gmsa_plan_set_step_chance) on the domain, such as [learned step reliability](#gmsa_plan_learn_steps), each step's cost is divided by its chance: unreliable steps get avoided without changing any cost.

#### Goals inside recipes

A method's `subtasks` can name a goal. The recipe gives the structure, the search fills the gap:

```gml
var _job = gmsa_plan_add_task(_d, "job");
gmsa_plan_add_method(_job, "the_plan", { subtasks : ["case_the_bank", "get_inside", "crack_vault", "get_away"] });  // get_inside and get_away are goals
```

- The goal is searched from the imagined state where the recipe reaches it.
- **One answer per visit.** If a later part of the recipe fails, the planner backs up past the goal instead of asking it for its second best chain. When backing up changes something before the goal, the goal is reached again from a different state and searches again.
- A broken step in the goal's chain repairs by searching the goal again. The recipe around it stays.
- Give goals in a mixed domain an `actions` list, so a goal doesn't wander into the steps of other recipes.

#### Variety

Without it, identical agents in the same situation all take the same route. With `variety : 0.3`, each search multiplies every step's cost by a random factor between 1 and 1.3, drawn once per search from the planner's own generator (seeded with the planner's `seed`):

- Routes within about 30% of each other get mixed between agents, a clearly worse route stays rare.
- The factors only raise costs, so each search still finds the cheapest chain for its draw.
- A repair is a new search, with a new draw.

Variety is noise. When the difference should have a reason, put it in the costs instead: a cost function can read the agent's own traits (a strong agent smashes cheaply) or the world (an exit others are already heading to costs more).

#### Pruning

At build, each goal keeps only the steps that can help: a step that changes a fact the conditions need is relevant, then the facts it requires become needed too, until nothing changes. Steps that never become relevant are left out of that goal's search. A goal over a domain's full list of steps then searches only the ones that matter, often many times faster.

- **It never changes the chain found,** with one exception: a step that only makes other steps cheaper through a cost function (running shoes that make walking cheaper) is left out, since no condition or requirement needs it. Use `prune : false` for such a goal.
- A relevant step with a `check` can read any fact, so pruning steps aside for that goal and every allowed step is kept.

#### Explaining goals

A goal shows in the plan tree as one line with its chain under it:

```
escape (running, step 1 of 3)
  escape: 3 steps, cost 7, searched 12 nodes
  > pry_box
    take_key
    unlock_door
```

When no chain reaches a goal planned on its own, explain says how close it came. Here the goal's `actions` list forgot the door and the window:

```
escape (failed, no plan)
escape: no chain of steps reaches it
  out is false, needs true, and none of the goal's steps changes it
  closest it came: after pry_box, take_key
  still out is false, needs true
```

- A condition no allowed step changes is named first: usually a missing step or a wrong `actions` list.
- The closest state is the one with the fewest unmet conditions, the cheapest of those, with the steps that led there.

### Targets

A step with a `targets` callback asks your game for candidates when it becomes current, never while planning:

```gml
gmsa_plan_add_step(_d, "grab_coin", {
    targets : function(_owner) { return _owner.coins_in_reach; },
    score : function(_owner, _coin) { return 1 / (1 + point_distance(_owner.x, _owner.y, _coin.x, _coin.y)); },
});
```

- The best score wins. Without a score the first target wins. A score of 0 or less rules a target out.
- No target at all counts as a failed step: the plan is repaired, using a retry.
- When the target disappears during the step, report `gmsa_plan_step_failed`.

### Facts and your game

- **Change facts when a step ends,** then report it done. The rest of the plan is checked against the facts from the current step on, so a fact that changes halfway through a step (the gold is spent, the key isn't in hand yet) can make the plan look broken.
- **A failure needs a fact that explains it.** When the key vanishes and no fact says so, the planner can only try the same plan again, until the retries run out. A `key_exists` fact lets it pick a different method at once.
- **Facts are about the owner and the world as one set of numbers.** Per-target questions (is this coin reachable?) belong in `targets` and `score`.

### What planning costs

| Measure | VM |
| --- | --- |
| Making an 11 step plan | 329 us, 23 nodes |
| Making a 101 step plan | 2.7 ms, 203 nodes |
| Backtracking through 19 wrong methods | 879 us, 98 nodes |
| One node | about 9 us of search, about 13 us counting make's fixed work |
| `gmsa_plan_step_done` | about 5 us per step left in the plan |
| `gmsa_plan_refresh` | 100 us with a repair, 16 us with nothing broken |
| `gmsa_plan_explain`, 4 step plan | 71 us |
| The 101 step plan in 200 us slices | 3.3 ms over 13 calls, about 20% more in total, worst call 1.1 ms (finishing the long plan) |
| Idle scheduled planners | about 0.7 us each per scheduler step |
| 12 planners asking at once, about 100 nodes each | ready after 117 steps at a 100 us budget, 24 at 500 us, 7 at 2000 us |
| Scheduler steps with planning | over the budget by 22 to 37 us, at every budget |
| A goal: one node | about 10 to 11 us, flat at every search size |
| A goal over 5 steps, or a recipe with a goal inside | about 350 us, 23 to 25 nodes |
| A goal, 17 steps, of which 6 can't help: pruned / not pruned | 1.3 ms, 121 nodes / 82 ms, 7633 nodes |
| The unpruned 17 step search in 1 ms slices | 114 calls, worst call 1.1 ms |
| Cost functions, variety | 10 to 20% more per node, almost nothing |

The default budget of 250 nodes keeps a hopeless search to a few milliseconds on the VM, many times what typical domains use. Raise it for large domains, and plan across frames when a plan costs more than a frame can spare. Game plans usually have under 20 steps, where every running call stays well under 0.1 ms. Schedule planners for agents that may plan, hundreds of idle scheduled planners add up. Goals cost more than recipes: the search tries every allowed step in every promising state, and states multiply with every step that looks like progress. Keep goals to the steps that matter (pruning does most of it), and plan across frames when a search needs more than a few hundred nodes.

### Planner fields

| Field | Description |
| --- | --- |
| `domain`, `owner` | As given to `gmsa_plan_planner_create` |
| `budget`, `depth`, `retries`, `slice`, `clock` | Settings |
| `goal` | The name given to the last `gmsa_plan_make` |
| `status`, `result` | `gmsa_plan_status` and `gmsa_plan_result` |
| `nodes` | Nodes the last planning call used |
| `depth_cut` | True when the depth cap cut a branch in the last planning call |
| `target` | The current step's target |
| `failures` | Failed steps in a row |

---

## PlanLearn

Planning meets learning. The designer still writes every recipe, learning decides which recipe when, which steps to trust, and what the player is about to do. PlanLearn depends on Plan and Learn, neither depends on it.

| You want plans to | Use | Learns from |
| --- | --- | --- |
| Pick the recipe that works in this situation | [gmsa_plan_learn_methods](#gmsa_plan_learn_methods) | Which methods finish, fail and earn rewards |
| Route around steps that keep failing | [gmsa_plan_learn_steps](#gmsa_plan_learn_steps) | Which steps are reported done or failed |
| Anticipate the player | [gmsa_plan_learn_fact](#gmsa_plan_learn_fact) | The player's choices, through any choice model |

```gml
// the raid domain of Demo 11: get in by the door, the window or the tunnel
var _d = gmsa_plan_domain_create("raid");
gmsa_plan_add_fact(_d, "night", function(_g) { return global.night; });
// ... the other facts and steps
var _get_in = gmsa_plan_add_task(_d, "get_in");
gmsa_plan_add_method(_get_in, "door", { subtasks : ["enter_door"] });
gmsa_plan_add_method(_get_in, "window", { subtasks : ["enter_window"] });
gmsa_plan_add_method(_get_in, "tunnel", { subtasks : ["dig_tunnel"] });

// which steps fail by night or by day, and which way in pays off by night or by day
global.reliability = gmsa_plan_learn_steps(_d, { inputs : ["night"] });
global.entrances = gmsa_learn_count_create({ learns : gmsa_learn_target.OUTCOMES });
gmsa_plan_learn_methods(_get_in, global.entrances, { inputs : ["night"] });
global.raid = gmsa_plan_domain_build(_d);

// when a raid is over: quick raids are worth more
gmsa_plan_reward(planner, 1 - raid_time / max_raid_time);
```

**Inputs are facts.** Bool facts are used as 0 and 1. A number fact needs `min` and `max` in [gmsa_plan_add_fact](#gmsa_plan_add_fact) to become 0..1. Pick the facts that explain why a recipe works or a step fails: a model that sees `night` learns "the window works at night", one that doesn't can only learn "the window works half the time".

### gmsa_plan_learn_methods

```gml
gmsa_plan_learn_methods(task, model, [params]) -> task
```

An outcome model learns which of the task's methods work in which situation, and the task's methods are scored by it.

| Param | Type | Default | Description |
| --- | --- | --- | --- |
| `influence` | real | 1 | 0..1, how much say the model gets |
| `inputs` | array | every fact | Names of the facts the model sees |
| `success` | real | 1 | Reward when a method finishes its task |
| `failure` | real | -1 | Reward when a method fails |
| `select` | `gmsa_select` | `TOP_N_WEIGHTED` | Replaces the task's `select` |
| `top_n` | integer | every method | Replaces the task's `top_n` |

- **Scoring:** the task's `adjust` becomes `score * max(0.0001, lerp(1, p / best p, influence * confidence))`, as in [How re-ranking works](#how-re-ranking-works). Scores only go down, the method the model likes most keeps its score, and a method you ruled out stays out. A fresh model changes nothing.
- **Learning:** a listener turns the task's reports into outcomes: `METHOD_SUCCESS` learns `success`, `METHOD_FAILURE` learns `failure`, `METHOD_REWARD` learns the reward. Each outcome uses the method's chance of being chosen, for [fair learning](#fair-learning-and-exploration).
- **Exploration** comes from the weighted order, which is why `select` defaults to `TOP_N_WEIGHTED` over every method. With `BEST`, a task tries its first working method forever and learns only about that one.
- Use any model that learns from outcomes. Count suits a few bool facts, Linear suits more facts or ranges.

Wire it after the task's last method and the facts it uses, before the domain is built.

**Throws** when `task` isn't a task, the domain is built, the model doesn't learn from outcomes, the task has fewer than two methods or already has an `adjust`, a param is out of range, or an input isn't a fact of the domain. When planning: when a number fact without `min` and `max` is among the inputs, or methods were added to the task after wiring.

### gmsa_plan_learn_steps

```gml
gmsa_plan_learn_steps(domain, [params]) -> reliability
```

Learns each step's chance of success per situation, from the plans' own step reports, and sets it as the domain's [step chance](#gmsa_plan_set_step_chance). Methods whose steps keep failing sink in the order.

| Param | Type | Default | Description |
| --- | --- | --- | --- |
| `inputs` | array | `[]` | Names of the facts that make up the situation. None: one chance per step |
| `bins` | integer | 4 | Buckets for facts with a range, 2 or more. Bool facts have 2 |
| `half_life` | real | 50 | Step reports, from all steps of the domain together, until old evidence counts half |
| `prior` | real | 2 | Successes a step starts with |

- A step's chance is `(successes + prior) / (tries + prior)`, both fading with `half_life`. An untried step counts as fully reliable, so methods with more steps aren't punished before anything is known.
- **It works within a plan.** When a step fails, the repair plans its task again, and the failure has already lowered that step's chance in this situation. So the goblin turns to the window at once instead of trying the trapped door again. Without it, a failure no fact explains makes the planner retry the same plan, see [Facts and your game](#facts-and-your-game).
- **Goals use it too:** a goal's search divides each step's cost by its learned chance, so a goal finds a route around the failing step on its next search, the repair included.
- Situations multiply: three bool facts and one ranged fact with 4 bins are 2 x 2 x 2 x 4 = 32 situations per step, at most 4096.

Wire it after the facts it uses, before or after build. **Returns** the reliability, for the functions below.

**Throws** when `domain` isn't a domain or already has a step chance, a param is out of range, an input isn't a fact of the domain, or there would be more than 4096 situations. When planning: when a number fact without `min` and `max` is among the inputs.

### gmsa_plan_learn_step_chance

```gml
gmsa_plan_learn_step_chance(reliability, planner, step) -> real
```

A step's learned chance of success, by name, in the facts the planner read last. For debugging and UI.

**Throws** when the domain has no step with that name.

### gmsa_plan_learn_steps_reset

```gml
gmsa_plan_learn_steps_reset(reliability)
```

Forgets everything learned.

### gmsa_plan_learn_steps_save

```gml
gmsa_plan_learn_steps_save(reliability) -> string
```

Everything learned, as JSON. Steps are saved by name, so a save survives steps being added or reordered. The outcome model of `gmsa_plan_learn_methods` is saved with [gmsa_learn_save](#gmsa_learn_save) as usual.

### gmsa_plan_learn_steps_load

```gml
gmsa_plan_learn_steps_load(reliability, json) -> bool
```

Loads a save made with the same inputs and bins. Steps the domain no longer has are skipped. **Returns** true.

**Throws** when the text isn't a plan steps save, it comes from a newer version, or it was made with other inputs or bins. Nothing changes when it throws.

### gmsa_plan_learn_fact

```gml
gmsa_plan_learn_fact(domain, name, model, observed, action, [params]) -> domain
```

A fact reading how likely the observed agent, usually the player, is to pick `action` right now: [gmsa_learn_input](#gmsa_learn_input) as a fact with the range 0 to 1. `params` are those of `gmsa_learn_input` (`fallback`, `refresh`, `clock`).

```gml
// the player as an agent nobody runs: its profile only describes the player's choices
global.guard = gmsa_agent_create(global.guard_profile, obj_player);
global.habits = gmsa_learn_linear_create();

// at every bell: the player picked a post, the model learns
gmsa_learn_observe(global.habits, gmsa_observe(global.guard, ["guard_1", "guard_2", "guard_3"], _post));

// the goblins plan around the prediction
gmsa_plan_learn_fact(_d, "next_1", global.habits, global.guard, "guard_1", { fallback : 1 / 3 });
gmsa_plan_add_step(_d, "break_in_1", { requires : [["next_1", "<", 0.4]], effects : [["inside", true]] });
```

- **Plans follow the prediction.** Facts are read again before every step, so when the prediction shifts, a plan built on the old one is repaired: the goblin at the door of the vault the guard is now likely to visit picks another vault.
- **One evaluation per frame.** Predictions are cached per model and observed agent, so a crowd of planners reading it costs one evaluation, then a few microseconds per read.
- Usable in conditions, scores and as a learning input, like any fact with a range.

**Throws** like `gmsa_learn_input` and `gmsa_plan_add_fact`.

### What learning in plans costs

Measured on the VM target with Demo 11's raid: six steps, one task of three methods, the situation from two facts.

| Setup | Making the plan | The whole raid, make to reward | A raid whose first entrance fails |
| --- | --- | --- | --- |
| No learning | 94 us | 184 us | 281 us |
| Step reliability | 129 us | 306 us | 442 us |
| Learned methods (Count) | 149 us | 393 us | 605 us |
| Both | 186 us | 466 us | 705 us |

| Player facts | VM |
| --- | --- |
| One read, first in a frame | 65 us, one evaluation of the observed agent |
| One read, cached | 2.7 us |
| Making a plan reading three, first in a frame / cached | 139 / 72 us, 49 us with plain facts |

- Step reliability costs about 6 us per method step when a task is planned, and about 30 us per step result learned.
- Learned methods cost one prediction when the task is planned, and one outcome per method result and per reward.
- All of it is paid per plan or per step, never per frame.

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

### Planner

See [Planner fields](#planner-fields) in Plan.

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
| Plan fact `read` | `function(owner)` | A number or a bool |
| Plan step or method `check` | `function(state)` | True when it can be used. `state` is read only |
| Plan step `targets` | `function(owner)` | Array of targets |
| Plan step `score` | `function(owner, target)` | A number, 0 or less rules the target out |
| Plan step `cost` | `function(owner, state)` | The step's cost when a goal searches, 0 or less rules it out in that state. `state` is read only |
| Plan method `score` | `function(owner, state)` | A number, 0 or less rules the method out |
| Plan task `adjust` | `function(planner, state, scores)` | Nothing, changes `scores` with `[@ ]` |
| Plan listener | `function(report)` | Nothing. The report is reused, copy what you keep |
| Plan step chance | `function(planner, step, state)` | The step's chance of success, 0 to 1. `step` is an index into `domain.steps` |
| Scheduler work `work` | `function(budget)` | True when it did something, false when it had nothing to do |

Custom model methods run with the model as `self`, see [gmsa_learn_custom](#gmsa_learn_custom).

Callbacks can be anonymous functions, methods or script functions, including built-in functions such as `get_timer`. They're checked when you configure, but in GML a function reference can be a plain number, so a number passed by mistake isn't always caught. Bind data to them with `method(struct, function)` when they need more than the agent.

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