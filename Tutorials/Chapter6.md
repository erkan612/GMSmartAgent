# Chapter 6: From Choice to Action

So far the goblin has only made up its mind. It knows which coin it wants, it draws a line to it, and it stands still. This chapter makes it act: walk to the coin, pick it up, drink the potion, run from the player, and decide again when it's done.

Acting sounds like the easy part, and the code is short, but this is where most game AI looks broken. Agents that turn back and forth between two coins, walk to things that are already gone, freeze after finishing a task, or react to everything a fraction of a second too late all have the same cause: a cycle of thinking and acting that isn't quite right. So this chapter is mostly about that cycle: when to think, how to act on a decision exactly once, how to know an action is finished, and the small bonus called **commitment** that keeps an agent from dithering.

---

## Thinking and acting are separate

Up to now the goblin has thought every step and done nothing with the result. Once it acts, it helps to see thinking and acting as two separate jobs, running at different speeds:

- **Thinking** looks at the situation and decides what's best. It's the expensive part, and it doesn't need to happen every frame: a goblin that re-decides six times a second looks just as alert as one that re-decides sixty times.
- **Acting** carries out whatever was decided. It happens every frame: walking a step, playing an animation, checking whether it's arrived.

Between thinks, the goblin keeps doing what it last decided. When it thinks again, it might decide the same thing, and nothing changes, or something new, and it switches.

That separation is also what makes the cycle robust. Later, in Chapter 8, many goblins will think on a shared schedule, not in their own Step events, and a goblin won't know exactly when its next think will happen. The acting code shouldn't care. It just needs a way to notice that a new decision has arrived.

---

## A fresh decision, exactly once

That way is `gmsa_agent_consume`. Every time the agent thinks, its decision is marked **fresh**. `gmsa_agent_consume` returns the decision if it's fresh, and marks it as used. Called again before the next think, it returns `undefined`.

```gml
var _decision = gmsa_agent_consume(agent);
if (_decision != undefined) {
    // a new decision: act on it
}
```

This guarantees that each decision is acted on **once**. Without it, you'd have to remember whether you'd already handled the latest decision, and it's easy to get wrong: re-starting the same walk every frame, playing an "I've spotted a coin" sound sixty times, or resetting a timer that should have kept running. With it, the shape is always the same: think when it's time, and act when there's something fresh.

---

## Telling GMSmartAgent what the agent is doing

When the goblin starts acting on a choice, tell its agent:

```gml
gmsa_agent_set_current_option(agent, _chosen);
```

and when it stops, because it finished or gave up:

```gml
gmsa_agent_clear_current(agent);
```

The agent keeps track of its **current option**: the action and the target it's working on. That might look like bookkeeping for its own sake, but several things depend on it. The most immediate is commitment, later in this chapter, which needs to know what the agent is already doing in order to favour it. Learning, much later in the series, uses it to know which decision an outcome belongs to.

The rule is simple: **set it when the agent starts something, clear it when the agent stops.** Every path out of an action, done, failed or interrupted, should end with either a new current option or a cleared one.

---

## The cycle

Here's the whole cycle for the goblin. First, a few variables and two small helpers in Create:

```gml
// o_goblin > Create (add)
doing = "nothing";
goal = noone;
gold = 0;
think_timer = irandom(9);  // stagger: goblins don't all think on the same step

// move toward a point; true once it's there
move_to = function(_x, _y, _speed) {
    var _dist = point_distance(x, y, _x, _y);
    var _dir = point_direction(x, y, _x, _y);
    x += lengthdir_x(min(_speed, _dist), _dir);
    y += lengthdir_y(min(_speed, _dist), _dir);
    return _dist <= _speed;
};

// stop whatever it's doing and decide again right away
finish = function() {
    doing = "nothing";
    goal = noone;
    gmsa_agent_clear_current(agent);
    think_timer = 0;
};
```

Then the Step event, in three parts:

```gml
// o_goblin > Step
if (keyboard_check_pressed(vk_down)) hp = max(0, hp - 10);
if (keyboard_check_pressed(vk_up))   hp = min(100, hp + 10);

// 1. think every 10 steps, or sooner when asked
think_timer--;
if (think_timer <= 0) {
    think_timer = 10;
    gmsa_agent_think(agent);
}

// 2. act on a fresh decision, once
var _decision = gmsa_agent_consume(agent);
if (_decision != undefined) {
    var _chosen = gmsa_decision_get_chosen(_decision);
    if (_chosen == undefined) {
        doing = "nothing";
        goal = noone;
        gmsa_agent_clear_current(agent);
    } else {
        doing = _chosen.action.name;
        goal = _chosen.target;
        gmsa_agent_set_current_option(agent, _chosen);
    }
}

// 3. carry out what it's doing, every step
switch (doing) {
    case "loot":
    case "drink":
        if (!instance_exists(goal)) {   // someone else got there first
            finish();
            break;
        }
        if (move_to(goal.x, goal.y, 2)) {
            if (doing == "drink") hp = min(100, hp + 40);
            else gold += goal.value;
            instance_destroy(goal);
            finish();
        }
        break;

    case "flee":
        if (instance_exists(o_player)) {
            var _away = point_direction(o_player.x, o_player.y, x, y);
            x = clamp(x + lengthdir_x(2.5, _away), 16, room_width - 16);
            y = clamp(y + lengthdir_y(2.5, _away), 16, room_height - 16);
        }
        break;
}
```

And the profile gets one change, in `__goblin_profile_build`:

```gml
var _p = gmsa_profile_create("goblin", { commitment : 0.15 });
```

Run it. The goblin walks to its chosen coin, picks it up and immediately heads for the next. Hurt it and it turns toward a potion. Bring the player close while it's hurt and it runs. Move away and it calms down and goes back to work.

The rest of the chapter takes the cycle apart, piece by piece.

---

## Part 1: when to think

```gml
think_timer--;
if (think_timer <= 0) {
    think_timer = 10;
    gmsa_agent_think(agent);
}
```

The goblin thinks every 10 steps, six times a second at 60 frames per second. That's a **reaction time** of up to a sixth of a second, about what a person needs to notice something and respond, and it reads as natural. Faster thinking rarely looks smarter; it mostly costs more. Slower thinking starts to look sluggish around half a second, but for agents far from the player, or for slow creatures, even a second can be fine.

Three details make the timer work well:

- **Stagger.** `think_timer = irandom(9)` in Create means goblins placed at the same moment don't all think on the same step. Twenty goblins thinking together every tenth step makes every tenth frame heavier than the rest; staggered, the cost spreads evenly.
- **Think now when something happens.** `think_timer = 0` makes the goblin think on the very next step. `finish()` does that, so a goblin that's just picked up a coin doesn't stand around for up to a sixth of a second before choosing the next one. Do the same when something important happens: the goblin is hit, an alarm goes off, the player appears. A goblin that reacts to being hit *instantly* reads as far more alive than one that reacts on its next scheduled think.
- **Don't think while it can't act.** A goblin in the middle of a stun or an animation that can't be interrupted gains nothing by thinking. Skip the timer while it's busy, and think the moment it's free.

Chapter 8 replaces this hand-made timer with the scheduler, which decides when each agent thinks based on a shared time budget. The acting code you're writing now won't need to change, because it only ever looks at fresh decisions.

---

## Part 2: acting on a decision

```gml
var _decision = gmsa_agent_consume(agent);
if (_decision != undefined) {
    var _chosen = gmsa_decision_get_chosen(_decision);
    ...
}
```

When a fresh decision arrives, there are two cases.

**Nothing was chosen.** Every option was vetoed, or there were none: no coins in range, no potions, and the goblin isn't hurt enough to flee. The goblin stops, and its current option is cleared. Standing still is a correct reaction to "nothing is worth doing", but it looks dead, and Chapter 7 is about giving the goblin something better to do in that case.

**Something was chosen.** The goblin copies what it needs, the action's name and the target, into its own variables, and tells its agent this is what it's doing now. Copying is Chapter 2's rule in action: the decision will be overwritten by the next think, so the goblin keeps its own `doing` and `goal`.

Notice what happens when the chosen option is the same as what the goblin is already doing: same action, same coin. `doing` and `goal` are set to the values they already had, the current option is set to what it already was, and the goblin carries on without a hitch. Re-deciding the same thing is free, and that's what makes thinking regularly safe: a goblin that keeps choosing the same coin keeps walking to it smoothly.

---

## Part 3: carrying it out

```gml
switch (doing) {
    case "loot":
    case "drink":
        ...
    case "flee":
        ...
}
```

This is where GMSmartAgent hands over completely. It decided `"loot"` on a particular coin; *how* to loot is your game's business: walking, pathfinding around walls, animations, sounds. Here it's a straight walk with `move_to`. In a real game it might be a path from your navigation system, a physics impulse or a tween.

Three kinds of action show up here, and each ends differently:

- **Actions that finish.** Looting and drinking end when the goblin arrives and picks the thing up. The action calls `finish()`, which clears the current option and asks for a new think straight away.
- **Actions that fail.** The coin might be gone before the goblin gets there, picked up by another goblin, or by the player. That's what `if (!instance_exists(goal))` catches: the action can't continue, so it finishes too, and the goblin chooses again. Without that check, the goblin would try to read `goal.x` from a destroyed instance and the game would error. **Every action with an instance target needs this check**, because between two thinks, the world keeps moving.
- **Actions that continue.** Fleeing has no natural end. It keeps going for as long as it's the best option, and stops when a think picks something else, because the player moved away or the goblin healed. There's nothing to finish.

That last kind is worth noticing. Most of the time, **you don't stop an action; a better decision replaces it.** The goblin doesn't need a rule saying "stop fleeing when the player is 300 pixels away". Fleeing's score falls as the player leaves, looting's rises past it, and the next think switches.

---

## Commitment

Run the goblin with two coins of the same value at almost the same distance, one either side of it, and watch closely with commitment set to 0. Every so often, the goblin turns toward one coin, takes a step, then turns toward the other, then back. It's the most visible failure in utility AI, and the cause is simple: two options with nearly equal scores, and small changes, a step taken, the player moving a little, swap which one is ahead. Each think obediently picks the new leader.

**Commitment** fixes it. With `commitment : 0.15` on the profile, the option the agent is currently doing, the same action on the same target, gets its score multiplied by 1.15 every time it thinks. To take over, another option has to beat the current one by more than 15%.

Here's how that plays out with two coins:

| | Coin A, the current one | Coin B | Winner |
| --- | --- | --- | --- |
| Scores without commitment | 0.40 | 0.41 | B, the goblin turns |
| Scores with commitment 0.15 | 0.46 | 0.41 | A, the goblin keeps going |
| B becomes clearly better | 0.46 | 0.52 | B, the goblin switches, deliberately |

Small differences no longer cause turns, and real ones still do. To a player, that's the difference between an agent that dithers and one that commits to a choice and changes its mind only for a good reason.

This is why `gmsa_agent_set_current_option` matters: commitment can only favour what the agent is doing if the agent has been told. It's also why `finish()` clears the current option: once a coin is picked up, the goblin shouldn't keep favouring a coin that no longer exists, and the next choice should start fresh.

### How much commitment?

- **0.1 to 0.2** suits most agents. It removes dithering and keeps them responsive.
- **Too little,** and close calls cause turning.
- **Too much,** and the agent becomes stubborn: with 0.5, a goblin walking to a 1-coin ignores a 5-coin that appears right next to it, because the new coin has to score 50% higher to win. Stubbornness looks just as unintelligent as dithering, only slower.

Commitment only applies to the *same action on the same target*. A goblin committed to coin A gets no bonus for coin B, and none for drinking. So commitment never stops the goblin noticing that it's badly hurt and needs a potion; it only stops it swapping between near-equal ways of doing the same thing.

---

## When the game decides for the agent

Sometimes your game, not the agent, decides what the goblin is doing: it's stunned, it's in a cutscene, it's been grabbed by the player. While that's going on, skip the think timer. When it ends, clear the current option and think at once, so the goblin starts fresh from wherever it ended up:

```gml
// o_goblin > Create (add)
stunned = 0;
```

```gml
// o_goblin > Step, at the top
if (stunned > 0) {
    stunned--;
    if (stunned == 0) finish();  // clears, and thinks on the next step
    exit;
}
```

And if your game ever puts the goblin into one of its own actions directly, say a scripted moment where it must flee, tell the agent with `gmsa_agent_set_current(agent, "flee")`, so commitment and everything else that follows the current option stay in step with what's really happening.

---

## Cooldowns

One more tool belongs with acting. Some actions shouldn't be repeated straight away, even when they score best: a taunt, a special attack, a shout for help. An action's **cooldown** is a time, in microseconds, during which it can't be chosen again after it was chosen:

```gml
var _taunt = gmsa_profile_add_action(_p, "taunt", { cooldown : 3000000 });  // 3 seconds
```

While an action is cooling down, it can't be chosen anew: it produces no options, as if it had no targets. When the cooldown ends, it's scored normally again. Cooldowns are counted from the moment the action is chosen, so a taunt that's chosen, played and finished can't be chosen again for three seconds from when it started.

The one exception is what the goblin is doing right now. If the taunt takes a second to play and the goblin thinks halfway through, the taunt is still its current option, so it stays on offer, with its commitment, and the goblin carries on. Carrying on doesn't restart the cooldown. That's one more reason `finish()` clears the current option: once the taunt is over, it really is off the table until its three seconds are up.

---

## Common problems, and the part of the cycle they come from

| What you see | Usual cause |
| --- | --- |
| Turning back and forth between two targets | No commitment, or `gmsa_agent_set_current_option` never called |
| Ignores a much better target that just appeared | Commitment too high |
| Stands still for a moment after finishing | `think_timer` not reset when an action finishes |
| Error reading `x` of a destroyed instance | Missing `instance_exists` check on the target |
| Restarts the same animation or sound every frame | Acting on `agent.decision` directly instead of on `gmsa_agent_consume` |
| Keeps favouring a coin it already picked up | Current option not cleared when the action finished |
| All goblins hitch on the same frame | Think timers not staggered |

---

## Try this

- **Turn commitment off,** with `commitment : 0`, and place two equal coins at the same distance either side of the goblin. Watch for the turning. Then try 0.15, and then 0.6, and walk the player toward the goblin's target to see stubbornness.
- **React instantly to being hit.** Make pressing down also set `think_timer = 0`. Compare how quickly the goblin turns toward a potion with and without it.
- **Slow thinking down.** Set the think interval to 60 steps, one think a second. The goblin still works, but watch how long it walks toward a coin the player has already taken before it notices, and how that reads.
- **Add a taunt.** A `taunt` action with no targets, a weight of 0.3, a consideration that rises as the player gets closer, and a cooldown of three seconds. When it's chosen, set a `bubble` timer to 60 steps, call `finish()` straight away, and draw a speech bubble while the timer runs. The taunt itself is instant, so thinking can't cut it short.

---

## What you've learned

- **Thinking** decides and can run a few times a second. **Acting** carries the decision out every frame. Between thinks, the agent keeps doing what it last decided.
- `gmsa_agent_consume` returns each decision once, so each one is acted on exactly once, however and whenever the thinking happened.
- Tell the agent what it's doing with `gmsa_agent_set_current_option`, and clear it with `gmsa_agent_clear_current` when it stops. Every way out of an action ends in one or the other.
- Think when it's time, think at once when something happens or an action finishes, and stagger thinking across agents.
- Actions finish, fail or continue. Every action with an instance target must check the target still exists. Most actions aren't stopped; a better decision replaces them.
- **Commitment** multiplies the current option's score, so only a clearly better option takes over. 0.1 to 0.2 removes dithering without making agents stubborn. It applies only to the same action on the same target.
- **Cooldowns** keep an action from being chosen again for a while after it was chosen.

## What's next

[Chapter 7](Chapter7.md) is about the moment nothing is worth doing: why an agent with no good option stands still, why that's the right answer and the wrong look, and how to give it something sensible to do instead, from wandering to idling to waiting for its moment.