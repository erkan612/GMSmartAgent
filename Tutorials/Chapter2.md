# Chapter 2: Thinking in Scores

Chapter 1 ended on an idea: instead of checking rules in order, rate every option and take the best. This chapter turns that idea into a working goblin. It has two options, looting and drinking, and one thing it knows, its health. By the end it switches from one to the other on its own, you can see exactly why on screen, and you know what every number on that screen means.

Along the way you'll meet the words the rest of the series is built on: **option**, **score**, **consideration**, **weight**, **profile**, **agent**, **input** and **curve**. Two of them, inputs and curves, get whole chapters of their own next. Here you'll meet just enough of each to make the goblin choose.

---

## Getting GMSmartAgent into your project

GMSmartAgent comes as a local package:

1. Download `GMSmartAgent.yymps` from the latest release on GitHub.
2. In GameMaker, open **Tools > Import Local Package** and pick the file.
3. Import the folders you need.

For the Basic chapters you need three of them:

| Folder | What it is |
| --- | --- |
| Core | The engine: profiles, agents, scoring, curves, the scheduler |
| Debug | Drawing what an agent thought, on screen |
| Test | Tests for your agents, and Debug needs it too |

The others, for learning, planning and player profiling, can come later; nothing in Core depends on them. GMSmartAgent is plain GML, so there are no extensions and no DLLs, and it runs on every platform GameMaker exports to.

---

## Options and scores

An **option** is one thing the agent could do right now. For our goblin there are two: loot, and drink. Later there will be one option per coin and one per potion, but the idea doesn't change.

A **score** is a number from 0 to 1 that says how good an option is *right now*. Not how good it is in general, not how good it was a second ago. Right now, given everything the agent knows at this moment.

**Thinking** is scoring every option and ranking them. The highest score wins. A moment later the agent thinks again, every option is scored again against the new situation, and maybe something else wins. That's the whole loop. There's no memory of which rule fired last, no state to transition out of. Each think is a fresh look at the world.

Why 0 to 1, and not any number at all? Three reasons that matter in practice:

- **Every option is on the same scale.** Drinking and looting can be compared directly, because a score of 0.7 means the same amount of "good" wherever it comes from.
- **The ends mean something.** 0 means "not at all": the option can't win, whatever else is going on. 1 means "as good as it gets". Everything in between is a matter of degree.
- **Scores can be combined without drifting off.** As you're about to see, a score is built by multiplying smaller numbers together, and multiplying numbers between 0 and 1 always gives another number between 0 and 1.

---

## Considerations: what a score is made of

A score isn't typed in by hand. It's built from the things that matter to that option. Each of those things is a **consideration**: one fact about the situation, turned into a value from 0 to 1 that says how much it favours the option.

Take drinking a potion. Two things obviously matter: how hurt the goblin is, and whether a potion is anywhere near. As considerations:

- **How hurt:** 0 at full health (no reason to drink), 1 when nearly dead (every reason to).
- **How near the potion:** 1 when it's right there, falling to 0 when it's out of reach.

The option's score is the considerations **multiplied** together:

| Situation | How hurt | How near | Score |
| --- | --- | --- | --- |
| Badly hurt, potion close | 0.9 | 0.9 | 0.81 |
| Badly hurt, potion far | 0.9 | 0.2 | 0.18 |
| Barely hurt, potion close | 0.1 | 0.9 | 0.09 |
| Badly hurt, no potion in reach | 0.9 | 0 | 0 |

Why multiply rather than add? Look at the last row. If the considerations were added, a badly hurt goblin with no potion anywhere would still score 0.9 out of 2, a respectable score for an option it *can't do*. Multiplying gives 0, which is the truth: no potion, no drinking.

Multiplication makes every consideration a kind of "and". The option is good when the goblin is hurt **and** the potion is near **and** whatever else matters. Each consideration can only pull the score down, never push it up, and a single 0 vetoes the option outright. That's exactly how decisions feel when you describe them in words: "I'd drink it if I were hurt and it were close" means both, not either.

There's one side effect worth knowing about. Multiply enough numbers below 1 together and the result shrinks, even when each one is fairly good: three considerations of 0.8 multiply to 0.51. Left alone, that would quietly punish options for having more considerations. GMSmartAgent corrects for it, so an option with five considerations isn't at a disadvantage against one with a single consideration. You don't need to do anything about it; just know that it's handled, and that the exact formula is in the API Reference's [Scoring Pipeline](../ApiReference.md#scoring-pipeline).

### Weight

Each option's action also has a **weight**: a multiplier on its final score, 1 by default. Weight is how important the action is *overall*, before any consideration has a say. A goblin that loves gold might give looting a weight of 0.8. A cowardly one gives fleeing a weight of 1.2.

An action with **no considerations at all** simply scores its weight, every time. That sounds useless, but it's one of the most useful tools there is: a steady baseline the other options have to beat. "Loot unless something better comes along" is exactly an action with no considerations and a medium weight.

---

## Profiles and agents

GMSmartAgent separates two things you'll use constantly:

- A **profile** is the design of a brain: which inputs it knows about, which actions it can take, and how each action is scored. A profile is built once, then **locked**. You never change a built profile.
- An **agent** is one individual using a profile. It has its own values for its inputs, its own memory of what it's doing and what it last decided. A goblin instance owns an agent.

A room of fifty goblins has fifty agents and one profile. Each goblin knows its own health and makes its own choice, but they all *think the same way*, because they share the design. If you want goblins that think differently, a greedy one and a cautious one, you make two profiles. You'll do exactly that later in this chapter.

Locking the profile isn't a restriction for its own sake. A built profile has been checked for mistakes, its names have been turned into fast lookups, and it can be shared by any number of agents without one of them accidentally changing the others' minds.

---

## Inputs and curves, just enough

Two more pieces, both introduced lightly here because each gets the next chapter or two.

An **input** is a named value the agent knows, with a range. The goblin's health is an input called `"hp"`, ranging from 0 to 100. GMSmartAgent always works with inputs **normalized** to 0..1, so 50 health becomes 0.5 and 100 becomes 1. That's what lets any input feed any consideration, whatever its units.

There are two ways an agent gets an input's value. A **push** input is one you set yourself, whenever you like. A **pull** input is one the agent reads by calling a function of yours when it thinks. This chapter uses a push input, because it's the simplest. Chapter 3 is all about inputs, and pull inputs are where they get powerful.

A **curve** turns a normalized input into a consideration. It answers: at this value of the input, how much does this option care? The simplest curve is a straight line. For drinking, we want the consideration to be 1 at 0 health and 0 at full health, falling evenly in between:

```
consideration = 1 - hp
```

That's a straight line with a slope of -1 that starts at 1. In GMSmartAgent it's written:

```gml
gmsa_curve_make(gmsa_curve.LINEAR, { m : -1, b : 1 })
```

`m` is the slope and `b` is where the line starts. A straight line is rarely the best shape for something like health, and Chapter 4 is about choosing better ones, but it's perfect for seeing the mechanics with nothing hidden.

---

## Building the goblin's profile

Create a script called `Goblin_Profile`:

```gml
/// The goblin's brain, built once and shared by every goblin.
function goblin_profile() {
    static _profile = __goblin_profile_build();
    return _profile;
}

function __goblin_profile_build() {
    var _p = gmsa_profile_create("goblin");

    // what the goblin knows: its health, 0 to 100, starting at 100
    gmsa_profile_add_input(_p, gmsa_input_push("hp", 0, 100, 100));

    // drink: one consideration, how hurt it is
    var _drink = gmsa_profile_add_action(_p, "drink");
    gmsa_action_add_consideration(_drink, "hp", gmsa_curve_make(gmsa_curve.LINEAR, { m : -1, b : 1 }));

    // loot: no considerations, so it always scores its weight
    gmsa_profile_add_action(_p, "loot", { weight : 0.5 });

    return gmsa_profile_build(_p);
}
```

Line by line:

- **`gmsa_profile_create("goblin")`** starts a new, empty profile. The name shows up in error messages and debug output, so give every profile a clear one.
- **`gmsa_input_push("hp", 0, 100, 100)`** declares a push input called `"hp"` with a range of 0 to 100 and a starting value of 100. The range is how GMSmartAgent normalizes it: 0 becomes 0, 100 becomes 1, and anything outside the range is clamped.
- **`gmsa_profile_add_action(_p, "drink")`** adds an action and returns it, so you can give it considerations.
- **`gmsa_action_add_consideration(_drink, "hp", curve)`** says: one thing that matters to drinking is the `"hp"` input, passed through this curve. Inputs are referred to by name, and the name is checked when the profile is built.
- **`gmsa_profile_add_action(_p, "loot", { weight : 0.5 })`** adds looting, with no considerations and a weight of 0.5. It will always score exactly 0.5: the steady baseline drinking has to beat.
- **`gmsa_profile_build(_p)`** checks the whole profile, locks it and returns it.

The two functions together are a common GML pattern. `static _profile = ...` runs the build the first time `goblin_profile()` is called, and every call after that returns the same, already-built profile. Every goblin calls `goblin_profile()` and they all share one.

---

## The goblin object

Create an object called `o_goblin`, give it any sprite, and place one in a room.

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

What each part does:

- **`gmsa_agent_create(goblin_profile(), id)`** makes an agent for this goblin from the shared profile. The second argument is the agent's **owner**, the instance it belongs to. This chapter doesn't use the owner yet; Chapter 3 does.
- **`gmsa_agent_set_input(agent, "hp", hp)`** pushes the goblin's current health into its agent. A push input only changes when you set it, so we set it every step, right before thinking.
- **`gmsa_agent_think(agent)`** scores every option and ranks them. It's cheap, a few microseconds for a profile this small, so one goblin thinking every step is fine. With many goblins you'll want a scheduler, which is Chapter 8.
- **`gmsa_debug_draw(agent.decision, 10, 40)`** draws the agent's latest decision. Every agent keeps its most recent decision in `agent.decision`.

---

## Running it

Run the game. The debug list shows a single line:

```
> 0.500  p1.00  loot
```

Where's drinking? At full health its only consideration is 0, so its score is 0, and an option scoring 0 is **vetoed**: it's dropped before the ranking and never appears. That's the multiplication rule from earlier doing its job. A goblin at full health doesn't consider drinking a weak option; it doesn't consider it at all.

Press down once. At 90 health, drinking scores 0.1 and shows up:

```
> 0.500  p1.00  loot
  0.100  p0.00  drink  [hp 0.10]
```

Each line is one option. Reading from the left:

- **`>`** marks the option that was chosen.
- **`0.500`** is the option's score.
- **`p1.00`** is the chance it was picked. With the default selection the best option always wins, so the winner shows 1 and the rest 0. This column gets interesting when you let agents pick with a little randomness, which comes later in the series.
- **`loot`** is the action's name.
- **`[hp 0.10]`** is the value of each of the option's considerations, after its curve. Looting has none, so it shows nothing. When a score looks wrong, this is where you look first: one of these numbers is lower than you expected.

Keep pressing down and watch the two lines change places:

| HP | drink | loot | Chosen |
| --- | --- | --- | --- |
| 100 | vetoed | 0.50 | loot |
| 80 | 0.20 | 0.50 | loot |
| 60 | 0.40 | 0.50 | loot |
| 50 | 0.50 | 0.50 | drink |
| 40 | 0.60 | 0.50 | drink |
| 10 | 0.90 | 0.50 | drink |

Drinking's score is `1 - hp/100`, exactly the straight line. Looting is always 0.5. They cross at 50 health, and that's where the goblin changes its mind.

Notice what you didn't write: there's no `if (hp < 50)` anywhere. The switch point *falls out* of two choices you made, the curve on drinking and the weight on looting. Change either one and the switch point moves.

**What about exactly 50?** Both options score 0.5. When scores are equal, the option that was created first keeps the higher place, and `drink` was added to the profile before `loot`. So at exactly 50 the goblin drinks. Ties are rare once considerations are real measurements, but it's good to know they're decided the same way every time, never at random.

---

## Reading a decision in code

The debug list is for you. Your game needs the same information as values. `gmsa_agent_think` returns the decision, and the chosen option is one call away:

```gml
// o_goblin > Step, replace the gmsa_agent_think line
var _decision = gmsa_agent_think(agent);
var _chosen = gmsa_decision_get_chosen(_decision);
doing = (_chosen == undefined) ? "nothing" : _chosen.action.name;
```

```gml
// o_goblin > Create (add)
doing = "nothing";
```

```gml
// o_goblin > Draw
draw_self();
draw_set_halign(fa_center);
draw_text(x, y - 32, doing);
draw_set_halign(fa_left);
```

Now the goblin says what it's doing above its head. That one string, `"loot"` or `"drink"`, is what your game acts on: play an animation, walk somewhere, start a timer. Acting on decisions properly is Chapter 6; for now, a label is enough to see the choice.

A decision holds more than the winner. Its `options` array has every option, ranked from best to worst, each with its action and its score:

```gml
var _options = _decision.options;
for (var _i = 0; _i < array_length(_options); _i++) {
    var _o = _options[_i];
    show_debug_message(_o.action.name + " " + string(_o.score));
}
```

One rule to remember from the start: **decisions are reused**. Every agent has one decision struct, and every think overwrites it. If you want to keep something from a decision, like the chosen action's name, copy it into a variable of your own, the way `doing` does. Holding on to the decision or one of its options and reading it later gives you whatever the most recent think put there. This is what keeps thinking fast: hundreds of agents thinking every few frames don't create any garbage for GameMaker to collect.

---

## Weight is personality

Here's where scores start to pay off. Change looting's weight from 0.5 to 0.7 and run it again:

| HP | drink | loot (0.7) | Chosen |
| --- | --- | --- | --- |
| 60 | 0.40 | 0.70 | loot |
| 40 | 0.60 | 0.70 | loot |
| 30 | 0.70 | 0.70 | drink |
| 20 | 0.80 | 0.70 | drink |

The goblin now keeps looting until it's down to 30 health. It's greedier. You didn't touch any logic; you changed how much one thing matters.

That makes personalities cheap. Two kinds of goblin, built from one function:

```gml
// Goblin_Profile (add)
function greedy_goblin_profile() {
    static _profile = __goblin_profile_build_with("greedy goblin", 0.7);
    return _profile;
}

function cautious_goblin_profile() {
    static _profile = __goblin_profile_build_with("cautious goblin", 0.3);
    return _profile;
}

function __goblin_profile_build_with(_name, _greed) {
    var _p = gmsa_profile_create(_name);
    gmsa_profile_add_input(_p, gmsa_input_push("hp", 0, 100, 100));

    var _drink = gmsa_profile_add_action(_p, "drink");
    gmsa_action_add_consideration(_drink, "hp", gmsa_curve_make(gmsa_curve.LINEAR, { m : -1, b : 1 }));

    gmsa_profile_add_action(_p, "loot", { weight : _greed });
    return gmsa_profile_build(_p);
}
```

Give one goblin `greedy_goblin_profile()` and another `cautious_goblin_profile()` in their Create events, press down a few times, and watch them disagree. The cautious one goes for a potion at 70 health; the greedy one holds out until 30. Same decision, different characters, and a player watching them would describe them in exactly those words.

Weights work this way for every action. They're the first dial you reach for when an agent does the right *kind* of thing at the wrong *moment*.

---

## What a profile checks for you

`gmsa_profile_build` doesn't just lock the profile; it checks it. Misspell the input in drinking's consideration:

```gml
gmsa_action_add_consideration(_drink, "health", gmsa_curve_make(gmsa_curve.LINEAR, { m : -1, b : 1 }));
```

and the build throws an error starting with `GMSA:`, naming the profile, the action and the unknown input `"health"`. Mistakes in a profile surface the first time the profile is built, usually the moment the first goblin is created, instead of as a goblin that quietly ignores its health in the middle of a playtest. The same goes for two actions with the same name, a negative weight, an action with no targets reading a per-target input, and every other mistake the build can see.

Every configuration error in GMSmartAgent works this way: thrown early, starting with `GMSA:`, saying what's wrong and where.

---

## How often to think

The goblin above thinks every step, sixty times a second. For one goblin with two options, that costs almost nothing, a few microseconds. It's also more than it needs: a goblin's health doesn't change sixty times a second, and a decision that's re-made identically sixty times is wasted work.

Two habits to start with:

- **Think when it can matter.** A goblin that re-decides every few steps looks just as responsive to a player. You'll set that up properly in Chapter 6.
- **Many agents need a budget.** Fifty goblins thinking every step is where cost starts to add up. Chapter 8 introduces the **scheduler**, which gives all of your agents one shared slice of time per frame, so adding agents never drops your frame rate.

For now, every step is fine. It keeps the example simple, and it lets you see the decision change the instant you press a key.

---

## Try this

A few experiments that make the ideas stick. Each one is a one-line change.

- **Make the goblin ignore potions completely above 60 health, care only a little at 50, and switch to drinking at 30.** Try it with a straight line: you can get any two of those, never all three, because the three points don't sit on one line. Chapter 4's curves get all three.
- **Set looting's weight to 1.** Drinking's straight line never goes above 1, so it can only tie with looting, at exactly 0 health, and wins that tie because it was created first. An option's ceiling is its weight.
- **Set looting's weight to 0.** Looting now scores 0 and is vetoed, so drinking wins at every health below 100. At exactly 100 both are vetoed, and the debug list says `no selectable options`: there's nothing the goblin is willing to do. Chapter 7 is about exactly that situation.
- **Add a third action, `rest`, with a weight of 0.4 and no considerations.** It never wins, because looting at 0.5 always beats it. Then set looting's weight to 0.3 and see where `rest` takes over.

---

## What you've learned

- An **option** is something the agent could do now. Its **score**, from 0 to 1, says how good it is right now. **Thinking** scores every option and the best one wins.
- A score is built from **considerations**, one per thing that matters, multiplied together. Multiplying makes them work like "and": each one can only lower the score, and a 0 vetoes the option. GMSmartAgent corrects for the number of considerations, so options with many aren't punished.
- An action's **weight** multiplies its score. An action with no considerations scores its weight, which makes it a steady baseline.
- A **profile** is a shared, locked brain design. An **agent** is one individual using it. Many agents share one profile.
- An **input** is a named value with a range, normalized to 0..1. A **push** input is one you set. A **curve** turns an input into a consideration.
- Where an agent changes its mind isn't written anywhere as a rule. It falls out of curves and weights, and moving them moves it.
- Decisions are reused by every think: copy what you need from them.

## What's next

[Chapter 3](Chapter3.md) is about inputs: what an agent can know, the difference between pushing and pulling, inputs that differ for every target, and how to choose ranges so that 0 to 1 means what you want it to.