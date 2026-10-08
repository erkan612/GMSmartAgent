<img width="1200" height="360" alt="GMSmartAgent_banner" src="https://github.com/user-attachments/assets/bdd70835-30b0-491e-a181-25ff6324d654" />


A pure GML utility AI framework. Your agents score every option they have, every time they think, and pick the best one. State machines answer *what am I doing*. GMSmartAgent answers *what should I be doing*, and works alongside the state machine you already have. You describe what matters, GMSmartAgent does the math. No external DLLs or extensions.

---

## Overview

GMSmartAgent replaces hand-written `if` chains and rigid state machines with **utility scoring**. Every possible action an agent could take gets a score between 0 and 1 based on what the agent knows right now (its health, the distance to a target, whether it holds a key), and the highest-scoring option wins. Add a new behavior by adding an action, not by rewriting the decision tree.

For goals that take several steps (get the key, get through the door, open the chest), the **Plan** module works out the steps and keeps the plan working while the world changes. Utility picks what to do, planning works out how: from recipes you write (HTN), from a goal and a list of actions it searches through itself (GOAP), or both in one plan. Plans can learn too: which recipe works in which situation, which steps to trust, and what the player is about to do. And models can learn sequences: what the player does after what they just did, from a combo to which potion comes after a sword. Others learn each input on its own, so many inputs need only a few dozen choices, or remember whole moments, so "last time it looked like this" becomes a prediction. Beyond choices, GMSmartAgent can also tell how good each player is, from who wins matches of any shape, and how they play, by sorting players into styles found from many sessions or written by hand. Both are ready to use as inputs.

GMSmartAgent **only decides**. It never moves anything, never queries your room, never owns collision or spatial data. Your game hands it numbers, GMSmartAgent hands back a ranked list of options, or a plan one step at a time. What the agent does with it is up to you.

---

## Features at a Glance

### Scoring
- **Response curves** - Linear, power, logistic, step, or your own function or animation curve, each with an invert flag
- **Considerations** - One input through one curve, multiplied together so any zero vetoes the option
- **Compensation** - Actions with many considerations aren't punished for having more of them
- **Targets** - Options are action plus target pairs, so "attack goblin" and "attack troll" are scored separately
- **Weights and cooldowns** - Per action
### Inputs
- **Pull inputs** - Callbacks GMSmartAgent calls only when the agent actually thinks, cached once per think
- **Push inputs** - Values you feed in yourself, for things your game already has lying around
- **Normalization** - Every raw value mapped to 0..1 from a range you set
### Selection
- **Best** - Always the top option
- **Top N weighted** - Weighted random among the best few, so agents don't look robotic
- **Commitment** - A bonus for what the agent is already doing, so near-equal options don't flicker
### Scale
- **Frame budget** - A time budget per step in microseconds, so frame rate stays stable no matter how many agents you add
- **Priority tiers** - Important agents think first, background agents use what's left
- **Shared work** - Planning, model training and your own long jobs can take turns with the agents inside the same budget
- **Per-agent intervals** - Slow-witted enemies think less often, sharp ones more often
- **Shared profiles** - One profile, thousands of agents, only per-agent state is duplicated
### Observation
- **Record choices made by others** - Log what the player picked out of the options on offer, in the same shape as an agent's own decision
- **Features** - Choose which inputs are recorded with every option, for learning models
- **Evaluate** - Score an agent's current options without deciding anything, no side effects
### Learning
- **Learning from the player** - Models learn habits and preferences from the player's recorded choices
- **Count model** - Habits per situation, learns from a handful of choices and explains itself in plain words
- **Linear model** - Preferences across actions and targets, learns which item the player prefers, not just which action
- **RankNet model** - A small neural network that learns habits depending on combinations of inputs, like "walks far for coins only when healthy"
- **LambdaMART model** - Boosted decision trees for the most detailed rankings and sharp thresholds, trained in batches from the recent choices
- **N-gram model** - What follows what, in which situation: combos, habits in order and many habits in one model, learned from dozens of choices
- **TDNN model** - A neural network over the last few choices: which target comes next, and patterns where the moves in between don't matter
- **Naive Bayes model** - Each input learned on its own, so many inputs need only a few dozen choices, and which target from what was on offer against what was picked
- **Nearest neighbor model** - Remembers whole moments and predicts from the most similar: combinations, places on a map, rare moments, no training, and explains itself by pointing at a past moment with the game's own note
- **Background training** - Batch models and the TDNN's replays train a little at a time, by hand or on the scheduler inside the same budget as the agents, and the old model keeps working until the new one is ready
- **How sure** - Every prediction names its favourite and how sure the model is of it, so hints appear only when they're likely right
- **Re-ranking** - Companions and enemies drift toward what a model learned, under an influence cap, never above the designer's score
- **Prediction as input** - "How likely is the player to drink right now" becomes an ordinary input any profile can use
- **Confidence** - A model only gets a say once it has data, so there is no cold-start tuning
- **Decay, freeze, reset, save and load** - Old habits fade, learning pauses on demand, and models persist with the save game
- **Custom models** - Plug in your own model with a handful of methods, batch training included
### Learning From Outcomes
- **Agents that discover what works** - Any model can learn from how an agent's own decisions turn out, instead of copying someone. You define what counts as good, never which action is right
- **Precise or ambient results** - Report a result for one exact decision with a ticket, or reward an agent and let its recent decisions share the credit, fading with age
- **Shared experience** - One model per squad, colony or village: every result any member gets teaches all of them
- **Fair learning** - Rarely tried options aren't misjudged from too little data, and exploring only happens among the options your scoring ranks highest
- **Every model** - Count, Linear, RankNet, LambdaMART, the n-gram, the TDNN, Naive Bayes, nearest neighbor and custom models all learn from outcomes through one setting
- **Moves in order** - A boss learns which of its moves pays off after which: "after my feint and sweep, the heavy attack lands"
### Neural Networks
- **Small feed-forward networks** - Dense layers, backpropagation, SGD or Adam, the building block under RankNet and usable on their own
- **Sparse inputs** - One-hot codes cost only the values that aren't zero
- **Deterministic and allocation-free** - Seeded starting weights, every buffer allocated once at creation
### Planning
- **Recipes (HTN)** - A hierarchical task network planner: you write the recipes, the planner picks the ones that work right now, utility picks the job
- **Goals (GOAP)** - Name the result, describe what each action needs, does and costs, and the planner searches for the cheapest chain itself, A* over imagined states
- **Both in one plan** - A recipe can leave a part to a goal: your structure where you want control, the search where you want the agent to figure it out
- **Costs from your game** - A number or a function per action, seeing the imagined state, so distance, risk or an agent's own traits decide the route
- **Variety and pruning** - Identical agents can spread over routes of similar cost, and actions that can't help are left out of the search at build
- **Facts as data** - What each step requires and changes is declared, checked at build, and planned without allocating
- **Self-repairing plans** - Before each step the facts are read again, and a broken plan is replanned from the smallest task around the break, keeping the rest
- **Scored recipes** - Let the situation choose between "steal the key" and "buy the key"
- **Targets per step** - Your game offers candidates when a step starts, scoring picks the best one
- **Bounded cost** - A node budget per plan and a depth cap for tasks that use themselves
- **Planning across frames** - Large plans and many planners spread over several frames, in slices or inside the scheduler budget, giving exactly the same plan as planning at once
- **Explain** - The plan as a tree, as text or as data for your own UI, with the reason every skipped recipe didn't work, and for a goal no chain reaches, how close the search came
- **Weighted recipes** - A task can draw its recipe by score instead of always taking the best, so a crowd with the same recipes doesn't all do the same thing
- **Reports** - Listeners hear every recipe that finishes or fails, every step result and every reward, for learning or your own stats
### Planning Meets Learning
- **Learned recipes** - An outcome model finds out which recipe works in which situation, from the plans' own results and rewards you choose
- **Step reliability** - Steps that keep failing get a learned chance of success per situation, and plans route around them, even within the same plan
- **The player as facts** - A choice model's prediction ("the player will guard the vault") becomes a fact plans require, and plans repair themselves when the prediction shifts
- **Under the designer** - Learning only lowers recipe scores, never above yours, and a recipe you ruled out stays out
- **Learn spaces** - Any model can learn from choices that aren't an agent's, described by names and numbers
### Player Profiling
- **Skill rating** - How good each player, agent or encounter is, and how sure that is, learned from matches of any shape: one on one, teams, free for alls, alliances, everyone against a boss, partial results and partial play (Weng and Lin)
- **Win chance** - The chance one side beats another, as a number to show or an input an agent decides by
- **Pick and balance** - The opponent or encounter for a chosen win chance (dynamic difficulty, matchmaking), and lobbies split into fair teams of any sizes
- **Several pools** - One rating per mode or skill, a new pool starting from another
- **Play styles** - Styles found in many players' sessions (a mixture model choosing how many there are), written by hand, or both in one set, named, adjusted, merged, and kept by name when fitted again
- **Live matching** - A tracker per player, fed as things happen, says how much like each style they play now, how well they fit any, and how sure that is yet
- **Explained** - "erkan: 1620, fairly sure, 34 matches, last: beat the ogre", "rusher 97%, sniper 3% (fits well, sure): kills 3.10 (rusher 3.00)"

### Developer Tools
- **Debug view** - Ranked options with scores, probabilities and every consideration's value, drawn or as text, with the designer's score shown wherever learning changed it
- **Plan tree view** - A drawn plan tree: the current step, the done ones, skipped recipes with their reasons, what the last repair changed, and progress while a plan is being made
- **Test module** - Assertions, a runner, stubs, a fake clock, and scenario tests to lock in your profile tuning
- **Invariant checks** - Catch broken decisions while you tune
- **Deterministic** - Own seedable random generator, never touches GameMaker's global random sequence

---

## How It Works

```
inputs (pull or push)
   -> normalized to 0..1
   -> through a response curve         = consideration
   -> considerations multiplied        = raw score
   -> compensation, weight, commitment = option score
   -> options ranked high to low
   -> selection (best or top N weighted)
   -> decision handed back to you
```
 
Each agent thinks inside a scheduler. The scheduler gives each step a time budget, walks priority tiers highest first, takes turns fairly within a tier, and stops when the budget is spent. Agents it didn't reach continue next step.

When the chosen action is a goal that takes several steps, a planner breaks it down:

```
goal (a task)
   -> its methods tried in order, or best score first
   -> each method's steps and smaller tasks, effects imagined along the way
   -> backtracking to the next method when something can't be done
   -> a plan, handed to you one step at a time
   -> facts read again before each step, broken parts replanned
   (planning can be spread over several frames, inside the scheduler budget)
```

---

## Quick Example

An enemy that picks up nearby items, but goes for a heart when it's hurt.
 
**The profile**, built once and shared by every enemy:
 
```gml
function enemy_profile() {
    static _profile = __enemy_profile_build();
    return _profile;
}
 
function __enemy_profile_build() {
    var _p = gmsa_profile_create("enemy", { commitment : 0.15 });
 
    gmsa_profile_add_input(_p, gmsa_input_pull("missing_hp", function(_agent, _target) {
        return 1 - _agent.owner.hp / _agent.owner.hp_max;
    }));
    gmsa_profile_add_input(_p, gmsa_input_pull("distance", function(_agent, _target) {
        var _o = _agent.owner;
        return point_distance(_o.x, _o.y, _target.x, _target.y);
    }, 0, 300, true));
 
    var _near = gmsa_curve_make(gmsa_curve.LINEAR, { m : -1, b : 1 });  // 1 up close, 0 at 300 px
 
    var _a = gmsa_profile_add_action(_p, "pick_up", {
        weight  : 0.6,
        targets : function(_agent) { return _agent.owner.find(o_item); },
    });
    gmsa_action_add_consideration(_a, "distance", _near);
 
    _a = gmsa_profile_add_action(_p, "heal", {
        weight  : 1.2,
        targets : function(_agent) { return _agent.owner.find(o_heart); },
    });
    gmsa_action_add_consideration(_a, "distance", _near);
    gmsa_action_add_consideration(_a, "missing_hp", gmsa_curve_make(gmsa_curve.POWER));  // 0 at full health
 
    gmsa_profile_add_action(_p, "idle", { weight : 0.05 });
 
    return gmsa_profile_build(_p);
}
```
 
**The scheduler**, in a controller object:
 
```gml
// Create
global.ai = gmsa_scheduler_create(2000);  // 2 ms of AI per step
 
// Step
gmsa_scheduler_step(global.ai);
```
 
**The enemy**:
 
```gml
// Create
hp     = 100;
hp_max = 100;
 
// your own query, GMSmartAgent never searches the world itself
find = function(_object) {
    var _found = [];
    var _x = x, _y = y;
    with (_object) {
        if (point_distance(x, y, _x, _y) <= 300) array_push(_found, id);
    }
    return _found;
};
 
agent = gmsa_agent_create(enemy_profile(), id, { interval : 100000 });  // think at most 10 times a second
gmsa_scheduler_add(global.ai, agent);
 
// Step
var _decision = gmsa_agent_consume(agent);
if (_decision != undefined) {
    var _option = gmsa_decision_get_chosen(_decision);
    if (_option != undefined) {
        gmsa_agent_set_current_option(agent, _option);
        // act on _option.action.name and _option.target: your movement, your rules
    }
}
 
// Clean Up
gmsa_scheduler_remove(global.ai, agent);
```
 
**Seeing why it chose what it chose**, in the enemy's Draw GUI event:
 
```gml
gmsa_debug_draw(agent.decision, 10, 10);
```
 
---

## Testing Your Tuning
 
Utility AI goes wrong in tuning, not in code. The Test module lets you lock in the behavior you want, so a later weight change can't silently break it. Pull callbacks read `agent.owner`, so a plain struct stands in for the game object:
 
```gml
gmsa_test_suite("Enemy tuning", function() {
    var _fake = function(_hp) {
        return {
            hp : _hp, hp_max : 100, x : 0, y : 0,
            find : function(_object) { return [{ x : 10, y : 0 }]; },
        };
    };
    gmsa_test_case("hurt enemy heals", method({ fake : _fake }, function() {
        gmsa_test_scenario(enemy_profile(), fake(20), {}, "heal");
    }));
    gmsa_test_case("healthy enemy picks up items", method({ fake : _fake }, function() {
        gmsa_test_scenario(enemy_profile(), fake(100), {}, "pick_up");
    }));
});
gmsa_test_run(true);
```

---

## Learning From the Player

Record what the player chooses, together with what they passed up:

```gml
var _offered = [];
for (var _i = 0; _i < array_length(loot_in_reach); _i++) {
    array_push(_offered, { action : "take", target : loot_in_reach[_i] });
}
gmsa_learn_observe(global.taste, gmsa_observe(player_agent, _offered, _picked_index));
```

Let a companion drift toward the player's taste. The model only reorders what the designer's profile allows:

```gml
global.taste = gmsa_learn_linear_create();
gmsa_profile_set_model(companion_profile, global.taste, 1);   // before gmsa_profile_build
```

Or let any profile read what the player is likely to do next:

```gml
gmsa_profile_add_input(_p, gmsa_input_pull("will_drink", gmsa_learn_input(global.habits, player_agent, "drink")));
```

Pick the model by what the player's habits look like. Everything else stays the same:

```gml
global.taste = gmsa_learn_count_create();       // habits per situation, learns from a handful of choices
global.taste = gmsa_learn_linear_create();      // clear preferences, the default
global.taste = gmsa_learn_ranknet_create();     // habits that depend on combinations of inputs
global.taste = gmsa_learn_lambdamart_create();  // the most detailed, trained in batches:
gmsa_learn_train(global.taste, 2000);           // a little each step until done, or once at a checkpoint
global.taste = gmsa_learn_ngram_create();       // what follows what, see Learning Sequences below
global.taste = gmsa_learn_tdnn_create();        // which target follows what, needs hundreds of choices
global.taste = gmsa_learn_bayes_create();       // many inputs, each on its own, see Many Inputs, Whole Moments below
global.taste = gmsa_learn_neighbor_create();    // whole moments: combinations, places and rare moments
```

---

## Learning What Works

Learning from the player copies them. Learning from outcomes discovers what works, for the things you can't know while writing the profile: a shuffled world, rules the player changes, systems that interact. If you know the rule, write it as a consideration. If you can't, let the agents find out:

```gml
// one model shared by the whole squad, learning from results instead of choices
global.tactics = gmsa_learn_linear_create({ learns : gmsa_learn_target.OUTCOMES });

// each soldier keeps a history of its decisions and uses the shared model
gmsa_learn_track(agent);
gmsa_agent_set_model(agent, global.tactics, 1);

// acting on a decision gives a ticket for it
gmsa_agent_set_current_option(agent, _option);
shot = gmsa_learn_remember(agent);

// when the arrow lands, the ticket gets the result
gmsa_learn_outcome(global.tactics, shot, _hit ? 1 : -0.2);
```

When you can't point to the one decision that caused something, reward the agent instead, and its recent decisions share the credit:

```gml
gmsa_learn_reward(global.tactics, agent, -0.5);  // took damage just now
```

---

## Learning Sequences

Some habits come in order: jab, jab, then an uppercut; a sword, then the cheapest potion. Two models learn from the last few choices as well as the moment:

```gml
// the player's fighting habits
global.habits = gmsa_learn_ngram_create({ length : 4 });
gmsa_learn_observe(global.habits, gmsa_observe(player_agent, moves, _picked));

// the boss reads them, and only speaks up when it's sure
var _out = gmsa_learn_predict(global.habits, gmsa_agent_evaluate(player_agent));
if (_out.sure >= 0.6) boss_says = "I know your " + moves[_out.best] + " is coming";
```

- **The n-gram** learns what follows what, in which situation, from a few dozen choices. One model holds many habits at once: in testing, one learned seven different habits from one player, from potions when hurt to combos that depend on distance.
- **The TDNN** is a small neural network over the last few choices. It learns *which* target comes next ("after a sword, the cheapest potion") and patterns where the moves in between don't matter, from hundreds of choices. Its heavier training runs on the scheduler:

```gml
global.next_buy = gmsa_learn_tdnn_create({ remember : ["price"] });
gmsa_learn_schedule(global.next_buy, global.ai);  // trains in the scheduler's spare budget
```

Both learn from outcomes too, explain themselves, and save with the game. Demo 15 is a sparring partner that learns how you fight, Demo 16 a shop where the TDNN learns which potion you'll buy while the n-gram can only tell it'll be a potion.

---

## Many Inputs, Whole Moments

Two more models read the same choices in opposite ways:

- **Naive Bayes** learns each input on its own, then combines them. Eight scout reports, two of which decide where the player attacks: it finds the two within about a hundred attacks, where Count, which has to see every combination, is still guessing. It learns which item from what was on offer against what was picked, so a rare item the player always takes reads as wanted, and a common one they take by chance doesn't. It can't learn what only shows when inputs are read together.
- **Nearest neighbor** remembers whole moments and predicts from the most similar ones. That's exactly what Naive Bayes can't do: a place on a map from x and y, "escapes only when low on health and surrounded", a rare moment worth remembering. It needs no training, and its explain points at a moment the player actually played, with a note from your game:

```gml
global.spots = gmsa_learn_neighbor_create();
gmsa_learn_observe(global.spots, gmsa_observe(player_agent, acts, _act), "by the mill");

// fish: like 12 choices ago, by the mill (x 40%, y 62%, fish), 7 of 8 similar moments agree (p 0.81)
```

Both learn from outcomes too, and save with the game. Demo 17 is a scout where Naive Bayes reads eight reports, Demo 18 a fighter who escapes only when cornered, with both models on it, and Demo 19 a map where each model draws what it learned about where a wanderer does what: nearest neighbor draws the river and the forests, Naive Bayes can't.

---

## Who's Better, and How They Play

Two modules model the players themselves rather than their next choice.

**Rating** learns how good each player, agent or encounter is from who wins, with how sure it is: a newcomer moves fast, a veteran settles. A match has any number of teams of any size, in any places, with any rivalries:

```gml
global.ladder = gmsa_rating_pool_create();
gmsa_rating_match(global.ladder, { teams : [["erkan", "ada"], ["bot_1", "bot_2"]], places : [1, 2] });

var _p = gmsa_rating_chance(global.ladder, ["erkan", "ada"], ["bot_3", "bot_4"]);   // 0 to 1
var _fair = gmsa_rating_balance(global.ladder, lobby_names, 2);                     // two fair teams
var _next = gmsa_rating_pick(global.fights, "player", monsters, 0.6);               // won 60% of the time
```

Next to Elo on Demo 20's ladder (simulated, 60 runs), its predicted chances were closer to the truth early on (0.09 off against 0.13 after 100 matches), and it placed a strong newcomer on top within a median of 27 matches, against Elo's 92. In Demo 21 it picks each fight for a 60% win as the player improves, where a fixed difficulty curve suits only the player it was tuned for.

**Style** recognizes how someone plays, separate from how well. Styles are found from many players' sessions, where the data is pooled, or written by hand. Each player's tracker is fed as things happen, and matched live:

```gml
gmsa_style_count(tracker, "kills");
gmsa_style_sample(tracker, "distance", _distance);
gmsa_style_tick(tracker);

show_debug_message(gmsa_style_explain(global.styles, tracker));
// rusher 97%, sniper 3% (fits well, sure): kills 3.10 (rusher 3.00), distance 160 (rusher 150), cover 0.12 (rusher 0.10)
```

Demo 22 sorts a crowd of sessions into styles nobody named, then matches a live player as they switch between them, "not sure yet" at first, and "like none of them" for a mix nobody plays.

---

## Plans That Take Several Steps

Write the recipes once. Each step declares what it requires and what it changes, each task lists the ways to do it:

```gml
var _d = gmsa_plan_domain_create("goblin");
gmsa_plan_add_fact(_d, "has_key",    function(_owner) { return _owner.has_key; });
gmsa_plan_add_fact(_d, "key_exists", function(_owner) { return instance_exists(o_key); });
gmsa_plan_add_fact(_d, "gold",       function(_owner) { return _owner.gold; });

gmsa_plan_add_step(_d, "go_to_key",   { requires : [["key_exists", true]] });
gmsa_plan_add_step(_d, "pick_up_key", { requires : [["key_exists", true]], effects : [["has_key", true], ["key_exists", false]] });
gmsa_plan_add_step(_d, "buy_key",     { requires : [["gold", ">=", 10]], effects : [["gold", "-", 10], ["has_key", true]] });
gmsa_plan_add_step(_d, "open_chest",  { requires : [["has_key", true]] });

var _loot = gmsa_plan_add_task(_d, "loot_chest");
gmsa_plan_add_method(_loot, "have_key", { requires : [["has_key", true]], subtasks : ["open_chest"] });
gmsa_plan_add_method(_loot, "fetch",    { requires : [["key_exists", true]], subtasks : ["go_to_key", "pick_up_key", "open_chest"] });
gmsa_plan_add_method(_loot, "buy",      { subtasks : ["buy_key", "open_chest"] });
global.goblin_domain = gmsa_plan_domain_build(_d);
```

Each goblin gets a planner. Your game does the current step and reports how it went:

```gml
planner = gmsa_plan_planner_create(global.goblin_domain, id);
gmsa_plan_make(planner, "loot_chest");  // when utility picks the loot action

// Step
if (gmsa_plan_current(planner) == "go_to_key" && move_towards(key_x, key_y)) gmsa_plan_step_done(planner);
```

When the player snatches the key on the way, `gmsa_plan_refresh` repairs the plan: the goblin buys a key instead, if it can afford one. `gmsa_plan_explain` shows why:

```
loot_chest (running, step 1 of 2)
  loot_chest: buy
    have_key skipped: has_key is false, needs true
    fetch skipped: key_exists is false, needs true
  > buy_key
    open_chest
```

When many goblins plan at once, let the scheduler do it inside the AI budget you already have. The plans are the same, they just arrive over a few frames instead of all in one:

```gml
gmsa_plan_schedule(planner, global.ai);

// Draw GUI: the plan as a drawn tree
gmsa_debug_draw_tree(gmsa_plan_lines(planner), 10, 300);
```

---

## Plans That Learn

The recipes are yours, learning decides which one when. Here the lock jams in the rain, a rule nobody wrote down, and quick raids are worth more:

```gml
gmsa_plan_add_fact(_d, "raining", function(_owner) { return global.raining; });
// ... steps and tasks as before

// how often each step works, rain or dry, and which recipe pays off, rain or dry
global.lock_sense = gmsa_plan_learn_steps(_d, { inputs : ["raining"] });
global.raid_sense = gmsa_learn_count_create({ learns : gmsa_learn_target.OUTCOMES });
gmsa_plan_learn_methods(_loot, global.raid_sense, { inputs : ["raining"] });
global.goblin_domain = gmsa_plan_domain_build(_d);

// your game reports results as before, and what the finished raid was worth
gmsa_plan_reward(planner, 1 - raid_time / max_raid_time);
```

After a few jams, goblins in the rain stop reaching for the key, in the dry they keep using it. Plans can anticipate the player the same way: a model learns where the player goes, and its prediction becomes a fact the plan requires.

```gml
gmsa_plan_learn_fact(_d, "guard_here", global.habits, player_agent, "guard_vault");
gmsa_plan_add_step(_d, "break_in", { requires : [["guard_here", "<", 0.4]] });
```

---

## Plans Nobody Wrote

Name the result, describe the actions, and the planner finds the cheapest way:

```gml
var _d = gmsa_plan_domain_create("escape");
gmsa_plan_add_fact(_d, "has_key",  function(_owner) { return _owner.has_key; });
gmsa_plan_add_fact(_d, "box_open", function(_owner) { return global.box_open; });
gmsa_plan_add_fact(_d, "out",      function(_owner) { return _owner.out; });

gmsa_plan_add_step(_d, "pry_box",      { effects : [["box_open", true]], cost : 4 });
gmsa_plan_add_step(_d, "take_key",     { requires : [["box_open", true]], effects : [["has_key", true]], cost : 1 });
gmsa_plan_add_step(_d, "unlock_door",  { requires : [["has_key", true]], effects : [["out", true]], cost : 2 });
gmsa_plan_add_step(_d, "smash_window", { effects : [["out", true]], cost : function(_owner, _state) { return _owner.strong ? 3 : 12; } });
gmsa_plan_add_goal(_d, "escape", { conditions : [["out", true]], variety : 0.2 });
global.escape = gmsa_plan_domain_build(_d);

gmsa_plan_make(planner, "escape");  // the strong smash the window, the rest pry the box, take the key and unlock the door
```

Nobody wrote either route. Take the key away mid-escape and the plan repairs itself into another one. Learned step reliability counts too: a step that keeps failing costs more, so the search routes around it. And a recipe can leave its tricky parts to a goal:

```gml
gmsa_plan_add_method(_job, "the_plan", { subtasks : ["case_the_bank", "get_inside", "crack_vault", "get_away"] });  // get_inside and get_away are goals
```

---
 
## Performance
 
Measured on the VM target with trivial callbacks, so these numbers are GMSmartAgent's own overhead. Your input callbacks (distance queries, line of sight) come on top. YYC is faster.
 
| Measurement | Result |
| --- | --- |
| Curve evaluation | ~1.2 us |
| Cost per scored option | ~8 us, flat from 10 to 500 targets |
| Simple agent think (3 options) | ~23 us |
| Thinks per step, 2 ms budget | ~84, from 100 up to 10,000 agents |
| Budget overshoot | under 60 us once running, up to ~170 us on the first lap with 10,000 agents |
 
What that means at 60 fps with a 2 ms budget:
 
| Agents | Simple agents re-think every | Agents with ~20 options re-think every |
| --- | --- | --- |
| 500 | ~6 frames | ~40 frames |
| 1,000 | ~12 frames | ~85 frames |
 
Learning models add their own cost to every re-ranked think, at 3 options:

| Model | Added per think | Best for |
| --- | --- | --- |
| Count, Linear | ~40 us | Every agent in the room |
| RankNet | ~100 us | A few agents, a boss or a companion |
| LambdaMART | ~500 us | A few agents, or a shared predictor input read once per frame |

The sequence learners cost more per prediction. The n-gram predicts in about 0.2 to 0.5 ms and learns a choice in 0.15 to 1.3 ms. The TDNN predicts in about 0.35 ms with 4 options and learns a choice in 1.3 ms, plus about 1.2 ms per replayed choice, spread over frames by its training budget. See [What sequence learners cost](ApiReference.md#what-sequence-learners-cost).

Naive Bayes predicts in about 0.2 to 0.5 ms and learns a choice in 0.2 to 0.7 ms, however much it has seen. Nearest neighbor's cost grows with its memory, about 1.2 us per remembered moment: with the default 256 moments it predicts in about 0.6 ms and learns a choice in 0.75 ms, with 1024 in 1.5 and 2 ms. Choosing among many items is its expensive case, about 4.5 ms with 8 on offer. See [What Naive Bayes and nearest neighbor cost](ApiReference.md#what-naive-bayes-and-nearest-neighbor-cost).

LambdaMART trains inside a budget you set, with a measured overshoot under 130 us at 2 ms. Learning from outcomes costs about 25 us per reported result with Count, Linear or LambdaMART, and about 180 us with RankNet. The [API Reference](ApiReference.md#what-models-cost) has the full table.

Planning costs about 9 to 13 us per node searched. A plan of around ten steps takes about 0.3 ms to make, and each step after that about 30 us to check and hand over. The default budget of 250 nodes keeps a hopeless search to a few milliseconds. Scheduled planners make their plans inside the scheduler budget, going over it by under 40 us, and cost about 0.7 us per step while idle. See [What planning costs](ApiReference.md#what-planning-costs).

Learning in plans is paid per plan and per step, never per frame. With step reliability and a learned recipe both on, a six-step raid costs about 0.47 ms from making the plan to its reward, against 0.18 ms without learning. A player fact costs one evaluation of the player's model per frame, about 65 us, shared by every planner that reads it. See [What learning in plans costs](ApiReference.md#what-learning-in-plans-costs).

Goals cost about 10 us per node searched, flat at every size. A goal over a handful of actions takes about 0.35 ms. Searches grow with every action that looks like progress, so goals leave out the actions that can't help: with 17 actions of which 6 are irrelevant, 1.3 ms pruned against 82 ms searching everything. Big searches can be spread over frames like any plan.

A rating match costs 45 us for a 1 v 1 and about 0.3 ms for a free for all of 8, a chance 8 us, and splitting 30 players into 5 fair teams 22 ms at most, a lobby screen call. A style tracker costs 2 to 4 us per event, and matching a player 30 to 60 us. Finding styles is background work in slices: 200 sessions take about 15 s of slices on VM and 2.5 s on YYC, 1000 sessions about 21 s on VM. See [What rating costs](ApiReference.md#what-rating-costs) and [What style costs](ApiReference.md#what-style-costs).

Use priority tiers so the agents near the player think first, and give the AI a bigger budget if your game can afford it. Frame rate stays stable either way: adding agents or heavier models slows how often each one re-decides, never the game.
 
---
 
## Design Principles
 
- **The caller owns the world.** Collision, spatial queries, pathfinding and movement stay in your game. A second spatial system inside the framework would only fight yours.
- **Profiles are shared and locked.** Build once, reference from any number of agents. Agents hold only their own state.
- **No hidden globals.** You create schedulers yourself, and can run several with separate budgets.
- **Deterministic.** Same seed and same inputs give the same decisions, so tests and replays are repeatable.
- **Allocation-free thinking.** Decisions and options are reused, so many agents don't churn the garbage collector.
- **Learning stays under the designer.** Models reorder options within what the designer's scoring allows. They can't bring back a vetoed option or lift a score above the designer's, and agents only experiment among the options your scoring ranks highest.
- **Plans are made of your actions.** The planner only combines the steps, recipes and goals you wrote, it never invents an action. It hands your game one step at a time and never performs anything itself.

---
 
## Roadmap

- **Later** - GMNav input providers such as path cost and reachability, a full debug view with overlays and a scheduler budget view, YYC benchmarks, and a recurrent learner (GRU) for patterns longer than any window.

---
 
## Documentation
 
- [**Getting Started**](GettingStarted.md) - From one small enemy to a room full of goblins sharing one AI budget, one that learns to play like you, a crowd that learns which coins bite, goblins that plan their way into a locked chest on a shared budget, plans that learn which recipe works and when the player is watching, plans nobody wrote, goblins that read the rhythm of your play, models that learn your taste input by input and moment by moment, and ratings and play styles
- [**Full Documentation**](ApiReference.md) - Complete reference for every public function, enum and data structure
---
 
## References

**Utility theory for game AI** Mark, D. (2009) "[Behavioral Mathematics for Game AI](https://books.google.com/books/about/Behavioral_Mathematics_for_Game_AI.html?id=iJ2pOgAACAAJ)", Charles River Media

Mark, D. and Dill, K. (2010) "[Improving AI Decision Modeling Through Utility Theory](https://www.gdcvault.com/play/1012410/Improving-AI-Decision-Modeling-Through)", Game Developers Conference ([slides](https://media.gdcvault.com/gdc10/slides/MarkDill_ImprovingAIUtilityTheory.pdf))

Mark, D. and Lewis, M. (2015) "[Building a Better Centaur: AI at Massive Scale](https://www.gdcvault.com/play/1021848/Building-a-Better-Centaur-AI)", Game Developers Conference

Mark, D. "[Infinite Axis Utility System](https://www.gameai.com/iaus.php)", Intrinsic Algorithm

**Random number generation** Marsaglia, G. (2003) "[Xorshift RNGs](https://www.jstatsoft.org/article/view/v008i14)", Journal of Statistical Software, 8(14)

**Choice modeling, Linear model** McFadden, D. (1974) "[Conditional Logit Analysis of Qualitative Choice Behavior](https://escholarship.org/uc/item/61s3q2xr)", in Zarembka, P. (ed.) Frontiers in Econometrics, Academic Press

Cao, Z., Qin, T., Liu, T-Y., Tsai, M-F. and Li, H. (2007) "[Learning to Rank: From Pairwise Approach to Listwise Approach](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/02/tr-2007-40.pdf)", ICML '07

**Learning to rank** Liu, T-Y. (2009) "[Learning to Rank for Information Retrieval](https://www.nowpublishers.com/article/Details/INR-016)", Foundations and Trends in Information Retrieval, 3(3), 225-331

**RankNet** Burges, C., Shaked, T., Renshaw, E., Lazier, A., Deeds, M., Hamilton, N. and Hullender, G. (2005) "[Learning to Rank using Gradient Descent](https://icml.cc/Conferences/2015/wp-content/uploads/2015/06/icml_ranking.pdf)", ICML '05, 89-96

**LambdaRank and LambdaMART** Burges, C. J. C., Ragno, R. and Le, Q. V. (2006) "[Learning to Rank with Nonsmooth Cost Functions](https://papers.nips.cc/paper/2971-learning-to-rank-with-nonsmooth-cost-functions)", NIPS 2006

Burges, C. J. C. (2010) "[From RankNet to LambdaRank to LambdaMART: An Overview](https://www.microsoft.com/en-us/research/publication/from-ranknet-to-lambdarank-to-lambdamart-an-overview/)", Microsoft Research Technical Report MSR-TR-2010-82

Wu, Q., Burges, C. J. C., Svore, K. M. and Gao, J. (2010) "[Adapting Boosting for Information Retrieval Measures](https://www.microsoft.com/en-us/research/publication/adapting-boosting-information-retrieval-measures/)", Information Retrieval, 13(3), 254-270

**HTN planning** Nau, D., Cao, Y., Lotem, A. and Muñoz-Avila, H. (1999) "[SHOP: Simple Hierarchical Ordered Planner](https://mlanthology.org/ijcai/1999/nau1999ijcai-shop/)", IJCAI-99, 968-975

Nau, D., Au, T-C., Ilghami, O., Kuter, U., Murdock, J. W., Wu, D. and Yaman, F. (2003) "[SHOP2: An HTN Planning System](https://arxiv.org/abs/1106.4869)", Journal of Artificial Intelligence Research, 20, 379-404

Humphreys, T. (2013) "[Exploring HTN Planners through Example](http://www.gameaipro.com/GameAIPro/GameAIPro_Chapter12_Exploring_HTN_Planners_through_Example.pdf)", in Rabin, S. (ed.) Game AI Pro, CRC Press

urosidoki "[htn_planner](https://github.com/urosidoki/htn_planner)", a hierarchical task network planner for game AI

**Learning in HTN planning** Ilghami, O., Nau, D. S., Muñoz-Avila, H. and Aha, D. W. (2002) "[CaMeL: Learning Method Preconditions for HTN Planning](https://www.aaai.org/Papers/AIPS/2002/AIPS02-014.pdf)", AIPS-02

**Weighted recipe order** Luce, R. D. (1959) "[Individual Choice Behavior: A Theoretical Analysis](https://catalog.hathitrust.org/Record/000580649)", Wiley

Plackett, R. L. (1975) "[The Analysis of Permutations](https://ideas.repec.org/a/bla/jorssc/v24y1975i2p193-202.html)", Journal of the Royal Statistical Society, Series C (Applied Statistics), 24(2), 193-202

**N-grams in games** Rabin, S. (2013) "[Implementing N-Grams for Player Prediction, Procedural Generation, and Stylized AI](https://www.taylorfrancis.com/books/9780429100277/chapters/10.1201/b16725-54)", in Rabin, S. (ed.) Game AI Pro, CRC Press

**Context models and blending** Cleary, J. G. and Witten, I. H. (1984) "[Data Compression Using Adaptive Coding and Partial String Matching](https://prism.ucalgary.ca/handle/1880/45790)", IEEE Transactions on Communications, 32(4), 396-402

Willems, F. M. J., Shtarkov, Y. M. and Tjalkens, T. J. (1995) "[The Context-Tree Weighting Method: Basic Properties](https://research.tue.nl/en/publications/the-context-tree-weighting-method-basic-properties/)", IEEE Transactions on Information Theory, 41(3), 653-664

**Time-delay neural networks** Waibel, A., Hanazawa, T., Hinton, G., Shikano, K. and Lang, K. J. (1989) "[Phoneme Recognition Using Time-Delay Neural Networks](https://doi.org/10.1109/29.21701)", IEEE Transactions on Acoustics, Speech, and Signal Processing, 37(3), 328-339

**Experience replay** Lin, L-J. (1992) "[Self-Improving Reactive Agents Based on Reinforcement Learning, Planning and Teaching](https://mlanthology.org/mlj/1992/lin1992mlj-selfimproving)", Machine Learning, 8, 293-321

**Leaky ReLU** Maas, A. L., Hannun, A. Y. and Ng, A. Y. (2013) "[Rectifier Nonlinearities Improve Neural Network Acoustic Models](https://ai.stanford.edu/~amaas/papers/relu_hybrid_icml2013_final.pdf)", ICML 2013 Workshop on Deep Learning for Audio, Speech and Language Processing

**Confidence of neural networks** Guo, C., Pleiss, G., Sun, Y. and Weinberger, K. Q. (2017) "[On Calibration of Modern Neural Networks](https://arxiv.org/abs/1706.04599)", ICML 2017

Nguyen, A., Yosinski, J. and Clune, J. (2015) "[Deep Neural Networks are Easily Fooled: High Confidence Predictions for Unrecognizable Images](https://arxiv.org/abs/1412.1897)", CVPR 2015

**Naive Bayes** Domingos, P. and Pazzani, M. (1997) "[On the Optimality of the Simple Bayesian Classifier under Zero-One Loss](https://doi.org/10.1023/A:1007413511361)", Machine Learning, 29, 103-130

Zadrozny, B. and Elkan, C. (2001) "[Obtaining Calibrated Probability Estimates from Decision Trees and Naive Bayesian Classifiers](https://mlanthology.org/icml/2001/zadrozny2001icml-obtaining)", ICML 2001. Why combined evidence needs softening

**Nearest neighbor** Cover, T. M. and Hart, P. E. (1967) "[Nearest Neighbor Pattern Classification](https://doi.org/10.1109/TIT.1967.1053964)", IEEE Transactions on Information Theory, 13(1), 21-27

Dudani, S. A. (1976) "[The Distance-Weighted k-Nearest-Neighbor Rule](https://doi.org/10.1109/TSMC.1976.5408784)", IEEE Transactions on Systems, Man, and Cybernetics, 6(4), 325-327

Aha, D. W., Kibler, D. and Albert, M. K. (1991) "[Instance-Based Learning Algorithms](https://doi.org/10.1007/BF00153759)", Machine Learning, 6, 37-66. Keeping some moments longer than others

**Learned input weights (Relief)** Kira, K. and Rendell, L. A. (1992) "[A Practical Approach to Feature Selection](https://mlanthology.org/icml/1992/kira1992icml-practical)", ICML 1992, 249-256

Kononenko, I. (1994) "[Estimating Attributes: Analysis and Extensions of RELIEF](https://mlanthology.org/ecmlpkdd/1994/kononenko1994ecml-estimating)", ECML-94, 171-182

**Player modeling** Yannakakis, G. N. and Togelius, J. (2018) "[Artificial Intelligence and Games](https://gameaibook.org/)", Springer, chapter 5, "Modeling Players"

**Skill rating** Elo, A. E. (1978) "[The Rating of Chessplayers, Past and Present](https://en.wikipedia.org/wiki/Elo_rating_system)", Arco Publishing

Bradley, R. A. and Terry, M. E. (1952) "[Rank Analysis of Incomplete Block Designs: I. The Method of Paired Comparisons](https://doi.org/10.2307/2334029)", Biometrika, 39(3/4), 324-345

Glickman, M. E. (1999) "[Parameter Estimation in Large Dynamic Paired Comparison Experiments](https://ideas.repec.org/a/bla/jorssc/v48y1999i3p377-394.html)", Journal of the Royal Statistical Society, Series C (Applied Statistics), 48(3), 377-394

Weng, R. C. and Lin, C-J. (2011) "[A Bayesian Approximation Method for Online Ranking](https://jmlr.org/papers/v12/weng11a.html)", Journal of Machine Learning Research, 12, 267-300. The method Rating uses

**Play styles** Dempster, A. P., Laird, N. M. and Rubin, D. B. (1977) "[Maximum Likelihood from Incomplete Data via the EM Algorithm](https://doi.org/10.1111/j.2517-6161.1977.tb01600.x)", Journal of the Royal Statistical Society, Series B, 39(1), 1-38

Schwarz, G. (1978) "[Estimating the Dimension of a Model](https://doi.org/10.1214/aos/1176344136)", The Annals of Statistics, 6(2), 461-464. Choosing how many styles (BIC)

Arthur, D. and Vassilvitskii, S. (2007) "[k-means++: The Advantages of Careful Seeding](https://dl.acm.org/doi/10.5555/1283383.1283494)", SODA '07, 1027-1035

Drachen, A., Canossa, A. and Yannakakis, G. N. (2009) "[Player Modeling using Self-Organization in Tomb Raider: Underworld](https://pure.itu.dk/en/publications/player-modeling-using-self-organization-in-emtomb-raider-underwor/)", IEEE Symposium on Computational Intelligence and Games

**Goal-oriented action planning (GOAP)** Orkin, J. (2006) "[Three States and a Plan: The A.I. of F.E.A.R.](https://gdcvault.com/play/1013282/Three-States-and-a-Plan)", Game Developers Conference

**A\* search** Hart, P. E., Nilsson, N. J. and Raphael, B. (1968) "[A Formal Basis for the Heuristic Determination of Minimum Cost Paths](https://ieeexplore.ieee.org/document/4082128)", IEEE Transactions on Systems Science and Cybernetics, 4(2), 100-107

**Relevance pruning** Nebel, B., Dimopoulos, Y. and Koehler, J. (1997) "[Ignoring Irrelevant Facts and Operators in Plan Generation](https://gki.informatik.uni-freiburg.de/papers/nebel-etal-ecp-97.pdf)", ECP-97, Lecture Notes in Computer Science 1348, 338-350

**Time-sliced search** Buckland, M. (2004) "[Programming Game AI by Example](https://catdir.loc.gov/catdir/toc/ecip0419/2004015103.html)", Wordware Publishing, chapter 8, "Time-Sliced Path Planning"

**Neural networks** Rumelhart, D. E., Hinton, G. E. and Williams, R. J. (1986) "[Learning Representations by Back-Propagating Errors](https://doi.org/10.1038/323533a0)", Nature, 323, 533-536

Glorot, X. and Bengio, Y. (2010) "[Understanding the Difficulty of Training Deep Feedforward Neural Networks](https://proceedings.mlr.press/v9/glorot10a.html)", AISTATS 2010, 249-256

He, K., Zhang, X., Ren, S. and Sun, J. (2015) "[Delving Deep into Rectifiers: Surpassing Human-Level Performance on ImageNet Classification](https://arxiv.org/abs/1502.01852)", ICCV 2015

Kingma, D. P. and Ba, J. (2015) "[Adam: A Method for Stochastic Optimization](https://arxiv.org/abs/1412.6980)", ICLR 2015

Loshchilov, I. and Hutter, F. (2019) "[Decoupled Weight Decay Regularization](https://arxiv.org/abs/1711.05101)", ICLR 2019

**Gradient boosting and regression trees** Breiman, L., Friedman, J. H., Olshen, R. A. and Stone, C. J. (1984) "[Classification and Regression Trees](https://doi.org/10.1201/9781315139470)", Wadsworth

Friedman, J. H. (2001) "[Greedy Function Approximation: A Gradient Boosting Machine](https://www.jstor.org/stable/2699986)", The Annals of Statistics, 29(5), 1189-1232

Ke, G., Meng, Q., Finley, T., Wang, T., Chen, W., Ma, W., Ye, Q. and Liu, T-Y. (2017) "[LightGBM: A Highly Efficient Gradient Boosting Decision Tree](https://proceedings.neurips.cc/paper/2017/hash/6449f44a102fde848669bdd9eb6b76fa-Abstract.html)", NIPS 2017

**Ranking measures (NDCG)** Järvelin, K. and Kekäläinen, J. (2002) "[Cumulated Gain-Based Evaluation of IR Techniques](https://dl.acm.org/doi/10.1145/582415.582418)", ACM Transactions on Information Systems, 20(4), 422-446

**Contextual bandits, outcome learning** Langford, J. and Zhang, T. (2007) "[The Epoch-Greedy Algorithm for Contextual Multi-armed Bandits](https://proceedings.neurips.cc/paper_files/paper/2007/file/4b04a686b0ad13dce35fa99fa4161c65-Paper.pdf)", NIPS 2007

Li, L., Chu, W., Langford, J. and Schapire, R. E. (2010) "[A Contextual-Bandit Approach to Personalized News Article Recommendation](https://arxiv.org/abs/1003.0146)", WWW '10

**Propensity weighting** Horvitz, D. G. and Thompson, D. J. (1952) "[A Generalization of Sampling Without Replacement From a Finite Universe](https://doi.org/10.1080/01621459.1952.10483446)", Journal of the American Statistical Association, 47(260), 663-685

Dudík, M., Langford, J. and Li, L. (2011) "[Doubly Robust Policy Evaluation and Learning](https://arxiv.org/abs/1103.4601)", ICML '11

**Credit assignment and exploration** Sutton, R. S. and Barto, A. G. (2018) "[Reinforcement Learning: An Introduction](http://incompleteideas.net/book/the-book-2nd.html)", 2nd edition, MIT Press. Section 2.6, "Optimistic Initial Values", is the idea behind step reliability's starting trust