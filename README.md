### STILL IN DEVELOPMENT FOR SOME TIME NOW. INITIAL FILES WILL BE UPLOADED SOON

# GMSmartAgent

**Decision-weighting AI engine for GameMaker**

A pure GML utility AI framework. Your agents score every option they have, every time they think, and pick the best one. You describe what matters, GMSmartAgent does the math. No external DLLs or extensions.

---

## Overview

GMSmartAgent replaces hand-written `if` chains and rigid state machines with **utility scoring**. Every possible action an agent could take gets a score between 0 and 1 based on what the agent knows right now (its health, the distance to a target, whether it holds a key), and the highest-scoring option wins. Add a new behavior by adding an action, not by rewriting the decision tree.

GMSmartAgent is a **scoring engine only**. It never moves anything, never queries your room, never owns collision or spatial data. Your game hands it numbers, GMSmartAgent hands back a ranked list of options. What the agent does with its choice is up to you.

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
- **Per-agent intervals** - Slow-witted enemies think less often, sharp ones more often
- **Shared profiles** - One profile, thousands of agents, only per-agent state is duplicated
### Observation
- **Record choices made by others** - Log what the player picked out of the options on offer, in the same shape as an agent's own decision. The foundation for the upcoming learning module.
### Developer Tools
- **Debug view** - Ranked options with scores, probabilities and every consideration's value, drawn or as text
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
 
Use priority tiers so the agents near the player think first, and give the AI a bigger budget if your game can afford it. Frame rate stays stable either way: adding agents slows how often each one re-decides, never the game.
 
---
 
## Design Principles
 
- **The caller owns the world.** Collision, spatial queries, pathfinding and movement stay in your game. A second spatial system inside the framework would only fight yours.
- **Profiles are shared and locked.** Build once, reference from any number of agents. Agents hold only their own state.
- **No hidden globals.** You create schedulers yourself, and can run several with separate budgets.
- **Deterministic.** Same seed and same inputs give the same decisions, so tests and replays are repeatable.
- **Allocation-free thinking.** Decisions and options are reused, so many agents don't churn the garbage collector.
---
 
## Roadmap
 
- **Learn** - Tiered models behind one interface, from instant habit counting to pairwise ranking and boosted trees, learning both from an agent's own outcomes and from observed player choices. Designer scoring stays the base, learning is blended in under a cap you control.
- **Link** - GMNav input providers.
- **Full Debug** - Overlays, scheduler budget view, starved tier detection.
---
 
## Documentation
 
- **Getting Started** - In progress
- **Full Documentation** - In progress
---
 
## References
 
**Utility theory for game AI** Mark, D. (2009) "[Behavioral Mathematics for Game AI](https://books.google.com/books/about/Behavioral_Mathematics_for_Game_AI.html?id=iJ2pOgAACAAJ)", Charles River Media
Mark, D. and Dill, K. (2010) "[Improving AI Decision Modeling Through Utility Theory](https://www.gdcvault.com/play/1012410/Improving-AI-Decision-Modeling-Through)", Game Developers Conference ([slides](https://media.gdcvault.com/gdc10/slides/MarkDill_ImprovingAIUtilityTheory.pdf))
Mark, D. and Lewis, M. (2015) "[Building a Better Centaur: AI at Massive Scale](https://www.gdcvault.com/play/1021848/Building-a-Better-Centaur-AI)", Game Developers Conference
Mark, D. "[Infinite Axis Utility System](https://www.gameai.com/iaus.php)", Intrinsic Algorithm

**Random number generation** Marsaglia, G. (2003) "[Xorshift RNGs](https://www.jstatsoft.org/article/view/v008i14)", Journal of Statistical Software, 8(14)
