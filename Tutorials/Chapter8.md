# Chapter 8: Many Agents, One Budget

One goblin thinking six times a second costs next to nothing. A room of them is another matter. Every think scores every option, every option reads its inputs and runs its curves, and all of that happens inside the frame, alongside drawing, collisions and everything else your game does. Add enough goblins and the frame rate starts to drop, and a game that stutters whenever a crowd appears is worse than one with dumber goblins.

This chapter is about the **scheduler**: one shared slice of time per frame for all of your agents' thinking. Agents take turns inside it, and when it's used up, the rest wait for the next frame. The frame rate stays where it was however many agents there are; what changes is how often each one gets to re-think. By the end, the room can hold a hundred goblins without a hitch, the ones near the player react first, and you can see on screen exactly how the budget is being spent.

---

## What thinking costs

Measuring is better than guessing, so here are the numbers. Scoring one option, reading its inputs and running its curves, costs about **8 microseconds on the VM**, the target every run from GameMaker's IDE uses, and about 2 on YYC, the compiled target most release builds use. A think costs roughly that per option, plus a little.

The goblin from Chapter 7 has up to five potions and five coins as targets, plus fleeing, watching, wandering and idling: around fourteen options when the room is busy. That's on the order of 110 microseconds per think on the VM. Thinking six times a second, that's about 0.7 milliseconds per second per goblin, which sounds like nothing, and for one goblin it is.

At 60 frames per second, each frame has about 16.7 milliseconds for *everything*. Here's what the goblins' thinking alone costs per frame, on the VM, at six thinks per second each:

| Goblins | Thinks per frame, on average | Thinking per frame |
| --- | --- | --- |
| 10 | 1 | about 0.1 ms |
| 100 | 10 | about 1.1 ms |
| 500 | 50 | about 5.5 ms |
| 1,000 | 100 | about 11 ms |

The averages are only half the problem. Chapter 6 staggered the goblins' think timers so they wouldn't all think on the same frame, but goblins created at different moments, finishing actions and thinking at once, and reacting to the same event, drift into clumps. Some frames get twice the average, some get none. A game can survive a steady cost; it's the spikes that make it stutter.

What's needed is a way to say: **this much time per frame goes to thinking, and no more.**

---

## The idea: a budget

The scheduler holds a list of agents and a **budget**, a number of microseconds per step. Each step, you call it once. It goes through the agents that are due to think, letting each one think in turn, and checks the clock between thinks. When the budget is spent, it stops, and the agents that didn't get a turn are first in line next step.

That changes what happens as the room fills up:

- **Without a scheduler,** more agents means more time per frame. Past some number, the frame rate drops.
- **With a scheduler,** more agents means each agent re-thinks a little less often. The time per frame stays at the budget, whatever the number.

That second kind of slowdown is far gentler. A goblin that re-thinks every 10 frames instead of every 6 is a goblin with a slightly longer reaction time, a sixth of a second instead of a tenth. Nobody notices. A game that drops from 60 to 45 frames per second, everyone notices. The scheduler trades the cost nobody sees for the one everybody does.

---

## Setting it up

The scheduler lives in a controller object, so it exists before any goblin and outlives all of them. Create an object `o_controller`, and place it in the room **before** the goblins, or create it in the room's creation code, so its Create event runs first:

```gml
// o_controller > Create
global.ai = gmsa_scheduler_create(2000);  // 2 ms of thinking per step, in microseconds
```

```gml
// o_controller > Step
gmsa_scheduler_step(global.ai);
```

The goblin changes in three places. First, the agent is added to the scheduler when it's created, with an **interval**:

```gml
// o_goblin > Create, replace the agent line
agent = gmsa_agent_create(goblin_profile(), id, { interval : 100000 });  // at most 10 thinks a second
gmsa_scheduler_add(global.ai, agent);
```

Second, the think timer from Chapter 6 goes. Delete part 1 of the Step event, the `think_timer` block, and the `think_timer = irandom(9)` line in Create. The scheduler now decides when the goblin thinks. Part 2, acting on a fresh decision with `gmsa_agent_consume`, stays exactly as it is: that's the payoff of keeping thinking and acting separate. The acting code never knew who did the thinking.

`finish()` used to set `think_timer = 0` to decide again at once. Replace that line:

```gml
// o_goblin > Create, in finish(), replace "think_timer = 0;"
gmsa_agent_think(agent);  // decide again right away
```

Third, the goblin leaves the scheduler when it's destroyed:

```gml
// o_goblin > Clean Up
gmsa_scheduler_remove(global.ai, agent);
```

That last one isn't optional. A scheduler keeps every agent it's given. Without it, a destroyed goblin's agent stays on the list, and the scheduler keeps calling its pull inputs, which read `_agent.owner.hp` from an instance that's gone. Clean Up runs however an instance ends, destroyed, room change or game end, so it's the right place.

---

## Interval: how often at most

The `interval` is the shortest time, in microseconds, between two thinks of the same agent. `100000` is a tenth of a second, so this goblin thinks at most ten times a second. An agent is **due** when it has never thought, or when its interval has passed since its last think. The scheduler only ever gives turns to due agents.

The interval and the budget work together:

- When there's **room in the budget**, every agent thinks as often as its interval allows, and the scheduler finishes early. With ten goblins, each thinks ten times a second and the scheduler uses a fraction of its budget.
- When the **budget is full**, agents get turns as the budget allows, and wait longer than their interval. With a thousand goblins, each might think twice a second.

An interval of 0 means "as often as the budget allows", which is fine for a handful of important agents and wasteful for a crowd: a goblin doesn't need to re-decide sixty times a second, and every think it doesn't need is time another goblin could have used.

### Deciding again at once, outside the budget

The new `finish()` calls `gmsa_agent_think` directly. That think happens right there, outside the scheduler, and doesn't count against the budget. It's the right call for a goblin that's just picked up a coin: waiting for its next turn would leave it standing still for a moment, and players notice idle characters.

It's also a door to undoing the whole point of the scheduler. If every goblin thinks outside the budget whenever anything happens, the budget stops meaning anything. Keep direct thinks for moments that really need an instant reaction, like finishing an action or being hit, and let everything else wait its turn.

---

## How a step runs

Knowing the order things happen in explains everything the scheduler does:

1. **The clock is read once.** Every think in this step sees the same time, so cooldowns and intervals are consistent across agents.
2. **Tiers run from the highest priority down.** Every agent has a **priority**, 0 by default. All the agents with the same priority form a tier.
3. **Within a tier, agents take turns,** starting where the last step left off. If the budget ran out after the 40th goblin last step, this step starts with the 41st. Nobody gets skipped forever.
4. **Before each think, except the first, the clock is checked.** Once the budget is spent, the step stops. The first think always happens, so a step always makes progress even with a tiny budget, and a step can go over the budget by at most one think.
5. **Callbacks run last,** outside the timed part. More on those below.

`gmsa_scheduler_step` returns how many agents thought, and the details of the last step are in `global.ai.stats`:

| Field | Meaning |
| --- | --- |
| `thinks` | How many agents thought this step |
| `time` | Microseconds spent |
| `stopped` | True if the budget ran out before every due agent got a turn |

---

## Seeing the budget

Put the numbers on screen, along with a way to fill the room:

```gml
// o_controller > Create (add)
thinks_avg = 0;
```

```gml
// o_controller > Step (add)
if (keyboard_check_pressed(ord("G"))) {
    repeat (20) {
        instance_create_depth(random(room_width), random(room_height), 0, o_goblin);
        instance_create_depth(random(room_width), random(room_height), 0, o_coin);
    }
}
thinks_avg = lerp(thinks_avg, global.ai.stats.thinks, 0.05);
```

```gml
// o_controller > Draw GUI
var _s = global.ai.stats;
var _n = gmsa_scheduler_count(global.ai);
var _h = display_get_gui_height();
draw_text(10, _h - 60, string(_n) + " goblins   " + string(_s.thinks) + " thinks   " + string(_s.time) + " us" + (_s.stopped ? "   budget full" : ""));
if (thinks_avg > 0) draw_text(10, _h - 44, "each goblin re-thinks every " + string_format(_n / thinks_avg, 0, 1) + " steps");
draw_text(10, _h - 28, "fps " + string(fps_real));
```

`gmsa_scheduler_count` is the number of agents in the scheduler. Dividing it by the average thinks per step gives how many steps go by between one goblin's thinks: its reaction time, in frames.

Now press G a few times and watch:

- **With a few goblins,** the time is well under 2000, `budget full` never shows, and every goblin re-thinks about every 6 steps, its interval.
- **As the count climbs,** the time reaches the budget and stays there. `budget full` appears. The re-think figure starts to grow: 8 steps, 12, 20.
- **The frame rate doesn't move,** whatever the count, as far as thinking is concerned. If it drops, the cost is somewhere else: goblins drawing, moving and colliding cost time too, and a hundred instances aren't free even with no AI at all. The overlay tells you which it is: if the scheduler's time is at or under its budget, GMSmartAgent isn't what's slowing the game down.

---

## Sizing the budget

There's no right budget, only a choice about how much of the frame AI is worth. Some starting points:

- **Know your frame.** At 60 frames per second, a frame is 16.7 ms. At 30, it's 33.3.
- **Know what else needs it.** Drawing, physics, your own game logic. Measure them; GameMaker's debugger shows where frame time goes.
- **Give AI a fixed share.** 2 ms, about 12% of a 60 fps frame, is a reasonable default for a game where AI matters. A strategy game with hundreds of units might give it 4 or 5. A platformer with three enemies needs a fraction of a millisecond and will never fill even a small budget.
- **Then read the re-think figure.** If your agents re-think every 6 to 15 steps, they'll feel responsive. Past about 30 steps, half a second, reactions start to look slow, and you either raise the budget, lower the cost per think, or decide which agents matter most.

Lowering the cost per think is often the better lever, and Chapter 5 already covered it: fewer options. A goblin that scores five coins instead of fifty thinks ten times faster, and gets to think ten times as often within the same budget.

---

## Who thinks first

With a full budget, every agent waits its turn, and the turn order is fair. Fair isn't always what you want. A goblin right next to the player matters far more than one in the far corner: a slow reaction up close is something the player sees, while a slow reaction off screen is invisible.

**Priority tiers** handle that. Higher tiers think first, every step, and lower tiers get what's left of the budget:

```gml
// o_controller > Create (add)
priority_timer = 0;
```

```gml
// o_controller > Step (add)
priority_timer--;
if (priority_timer <= 0) {
    priority_timer = 30;   // twice a second
    with (o_goblin) {
        var _close = instance_exists(o_player) && point_distance(x, y, o_player.x, o_player.y) < 400;
        gmsa_scheduler_set_priority(global.ai, agent, _close ? 1 : 0);
    }
}
```

Goblins within 400 pixels of the player move to tier 1 and think first; the rest share whatever budget tier 1 leaves. Fill the room and stand near a few goblins: they keep reacting quickly while the far ones slow down. Walk across the room and the fast ones follow you.

`gmsa_scheduler_set_priority` moves an agent between tiers and keeps its interval timing, so changing priority often doesn't make agents think more. You can update priorities whenever you like, but there's no need to do it every frame; twice a second is plenty for "who's near the player".

One thing to watch: **a higher tier can starve the lower ones.** If tier 1 has enough agents to use the whole budget every step, tier 0 never gets a turn, and those goblins freeze mid-action until they're promoted. Two ways to keep that from happening:

- **Keep the top tier small,** a few dozen agents at most, the ones that really matter.
- **Rely on the interval.** An agent that thought recently isn't due again until its interval passes, so tier 1 agents with an interval of 0.1 seconds leave the rest of the budget to tier 0 most of the time.

Priority isn't only about distance. A boss, a companion, an enemy currently in combat, or the one goblin the player is looking at are all good candidates for a higher tier.

---

## Reacting to decisions with a callback

The consume pattern from Chapter 6, checking for a fresh decision every step, works with the scheduler unchanged. There's an alternative for agents that would rather be told: `on_decide`, a function the scheduler calls after the agent thinks:

```gml
agent = gmsa_agent_create(goblin_profile(), id, {
    interval  : 100000,
    on_decide : function(_agent) {
        // runs after each of this agent's thinks by the scheduler
        _agent.owner.decided_at = current_time;
    },
});
```

Callbacks run at the end of `gmsa_scheduler_step`, after the timed part, so whatever they do doesn't eat into the budget, and a callback can safely remove agents from the scheduler. They're handy for things that should happen *because* a decision was made, like logging, playing a bark when the chosen action changes, or notifying other systems. For acting on the decision itself, the consume pattern is usually simpler, because the acting code runs in the goblin's own Step where the goblin's own state lives.

---

## More than one scheduler

You create schedulers yourself, and you can create as many as you like, each with its own budget. That's useful when different kinds of agents shouldn't compete:

```gml
global.enemies = gmsa_scheduler_create(2000);
global.critters = gmsa_scheduler_create(300);  // birds and rats: nice to have, never at the enemies' expense
```

Step both in the controller. However many rats fill the sewer level, they share their 0.3 milliseconds and never take a microsecond from the enemies. An agent can be in only one scheduler at a time.

---

## Repeatable decisions

One more thing the scheduler gives you, quietly. When agents choose with a little randomness, which comes later in the series, they draw their random numbers from the scheduler's own generator, never from GameMaker's `random`. It starts from a seed:

```gml
global.ai = gmsa_scheduler_create(2000, { seed : 42 });
```

With the same seed and the same inputs, agents make the same decisions, every run. That's what makes replays and tests possible, and Chapter 10 relies on it. It also means adding GMSmartAgent to a game never changes the sequence of your own `random` calls.

---

## Try this

- **Find your limit.** With the overlay up, keep pressing G until the re-think figure passes 30 steps. Note the goblin count. Then halve `find_nearest`'s count from Chapter 5 and do it again.
- **Starve a tier.** Create every goblin with an interval of 0, fill the room, and promote every goblin to tier 1 except one in the far corner. Watch the lone goblin freeze. Put the interval back.
- **Two budgets.** Make a second object, a rat that wanders and flees, give it its own small profile, and put rats in a second scheduler with a budget of 300. Fill the room with rats and check the goblins' re-think figure: it shouldn't move.
- **Remove the Clean Up.** Delete the `gmsa_scheduler_remove` line, destroy a goblin, and see what happens on the scheduler's next turn for it. Put it back.

---

## What you've learned

- A think costs roughly 8 microseconds per option on the VM and 2 on YYC. Fine for one agent; a crowd adds up, and clumps of agents thinking together cause spikes.
- The **scheduler** gives all agents one **budget** per step. Agents take turns; when the budget is spent, the rest wait for the next step. More agents means slower re-thinking, never a slower game.
- Create it in a controller, step it once per step, add agents with an **interval**, and remove them in Clean Up. The acting code from Chapter 6 doesn't change.
- An agent is **due** when its interval has passed. Direct thinks outside the scheduler are for instant reactions only.
- Each step reads the clock once, runs tiers highest first, takes turns within a tier where the last step stopped, always makes at least one think, and runs callbacks after the timed part.
- `stats` shows thinks, time and whether the budget filled up. The re-think figure, agents divided by thinks per step, is the reaction time to watch.
- **Priority tiers** let important agents think first. Keep the top tier small, or it starves the rest.
- `on_decide` reports each think; several schedulers keep kinds of agents from competing; and a seeded scheduler makes decisions repeatable.

## What's next

[Chapter 9](Chapter9.md) is about seeing why. The debug list has been on screen since Chapter 2; this chapter reads it properly, explains every number in it, and turns it into a way of tuning: spotting the consideration that's dragging a score down, the curve in the wrong place, and the weight that's a little too strong, by looking rather than guessing.