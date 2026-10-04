<img width="1200" height="360" alt="GMSmartAgent_banner" src="https://github.com/user-attachments/assets/bdd70835-30b0-491e-a181-25ff6324d654" />


A pure GML utility AI framework. Your agents score every option they have, every time they think, and pick the best one. State machines answer *what am I doing*. GMSmartAgent answers *what should I be doing*, and works alongside the state machine you already have. You describe what matters, GMSmartAgent does the math. No external DLLs or extensions.

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
- **Record choices made by others** - Log what the player picked out of the options on offer, in the same shape as an agent's own decision
- **Features** - Choose which inputs are recorded with every option, for learning models
- **Evaluate** - Score an agent's current options without deciding anything, no side effects
### Learning
- **Learning from the player** - Models learn habits and preferences from the player's recorded choices
- **Count model** - Habits per situation, learns from a handful of choices and explains itself in plain words
- **Linear model** - Preferences across actions and targets, learns which item the player prefers, not just which action
- **Re-ranking** - Companions and enemies drift toward what a model learned, under an influence cap, never above the designer's score
- **Prediction as input** - "How likely is the player to drink right now" becomes an ordinary input any profile can use
- **Confidence** - A model only gets a say once it has data, so there is no cold-start tuning
- **Decay, freeze, reset, save and load** - Old habits fade, learning pauses on demand, and models persist with the save game
- **Custom models** - Plug in your own model with five methods
### Developer Tools
- **Debug view** - Ranked options with scores, probabilities and every consideration's value, drawn or as text, with the designer's score shown wherever learning changed it
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
- **Learning stays under the designer.** Models reorder options within what the designer's scoring allows. They can't bring back a vetoed option or lift a score above the designer's.
---
 
## Roadmap

- **v1.2: RankNet and LambdaMART** - The pairwise and boosted-tree learning-to-rank models, joining Count and Linear and trained from the same recorded choices.
- **v1.3: Learning from outcomes** - Agents that learn from how their own choices turn out: rewards, credit over time, and exploration limited to plausible options.
- **v1.4: Planning** - A Plan module where utility scoring picks the goal and a hierarchical task network planner works out the steps.
- **v1.5: Planning across frames** - Resumable planning inside the scheduler budget, and the plan tree in the debug view.
- **Later** - GMNav input providers such as path cost and reachability, and a full debug view with overlays and a scheduler budget view.
---
 
## Documentation
 
- [**Getting Started**](GettingStarted.md) - From one small enemy to room full of goblins sharing one AI budget
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

**Gradient boosting and regression trees** Breiman, L., Friedman, J. H., Olshen, R. A. and Stone, C. J. (1984) "[Classification and Regression Trees](https://doi.org/10.1201/9781315139470)", Wadsworth

Friedman, J. H. (2001) "[Greedy Function Approximation: A Gradient Boosting Machine](https://www.jstor.org/stable/2699986)", The Annals of Statistics, 29(5), 1189-1232

**Ranking measures (NDCG)** Järvelin, K. and Kekäläinen, J. (2002) "[Cumulated Gain-Based Evaluation of IR Techniques](https://dl.acm.org/doi/10.1145/582415.582418)", ACM Transactions on Information Systems, 20(4), 422-446

**Contextual bandits, outcome learning** Langford, J. and Zhang, T. (2007) "[The Epoch-Greedy Algorithm for Contextual Multi-armed Bandits](https://proceedings.neurips.cc/paper_files/paper/2007/file/4b04a686b0ad13dce35fa99fa4161c65-Paper.pdf)", NIPS 2007

Li, L., Chu, W., Langford, J. and Schapire, R. E. (2010) "[A Contextual-Bandit Approach to Personalized News Article Recommendation](https://arxiv.org/abs/1003.0146)", WWW '10

**Propensity weighting** Horvitz, D. G. and Thompson, D. J. (1952) "[A Generalization of Sampling Without Replacement From a Finite Universe](https://doi.org/10.1080/01621459.1952.10483446)", Journal of the American Statistical Association, 47(260), 663-685

Dudík, M., Langford, J. and Li, L. (2011) "[Doubly Robust Policy Evaluation and Learning](https://arxiv.org/abs/1103.4601)", ICML '11

**Credit assignment and exploration** Sutton, R. S. and Barto, A. G. (2018) "[Reinforcement Learning: An Introduction](http://incompleteideas.net/book/the-book-2nd.html)", 2nd edition, MIT Press
