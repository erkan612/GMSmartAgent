# Chapter 1: AI in Games

Before a single line of GMSmartAgent, this chapter is about the problem it solves. What does "AI" even mean in a game, what are the usual ways of building it, why does each of them work, and where does each of them start to hurt? By the end you'll know the vocabulary the rest of the series uses, and you'll know why GMSmartAgent is built the way it is, which makes everything after this much easier to follow.

There is almost no code here, and none of it is GMSmartAgent's yet. That starts in Chapter 2.

---

## What "AI" means in a game

Outside games, artificial intelligence usually means a system that is genuinely good at something: recognizing faces, translating text, playing chess better than any human. Game AI borrows the name, but its goal is different, and it helps to be clear about that from the start.

**A game's AI exists for the player.** Its job is not to be smart. Its job is to make the game fun, and the player's experience is the only thing that judges it. An enemy that plays perfectly is easy to build and miserable to play against: it never misses, it always knows where you are, it never makes a mistake you can punish. An enemy that plays badly in the wrong ways is just as miserable: it walks into walls, ignores you while you shoot it, or forgets you exist the moment you step behind a crate. What a game wants is an opponent, a companion or a creature that behaves *believably*, *readably* and *fairly*, and that can lose in a way that feels earned.

That makes game AI a craft of appearances. The player never sees your code. They see a goblin stop, look at a coin, glance at them, and run for a potion. From that they build a story: *it's greedy, but it's scared of me*. Players are remarkably generous here. They fill in intentions, personalities and plans from very little, as long as what they see is consistent. A goblin that does something sensible for a reason the player can guess feels intelligent, even if the logic behind it is three lines long. A goblin that does something brilliant for a reason the player can't follow feels broken.

So when this series says an agent is "smart", it means the player would describe it that way. Here are the qualities that matter, and every chapter after this one is about getting one of them right:

- **Readable.** The player can tell what it's doing and roughly why. A guard that hears a noise and turns toward it reads well. A guard that silently changes its route for reasons nobody can see reads as random.
- **Consistent.** The same situation leads to the same kind of behavior. A goblin that drinks a potion at low health on Tuesday and ignores one at lower health on Wednesday feels buggy, not clever.
- **Responsive.** When the world changes, the agent notices. If you drop a bag of gold next to a goblin and it keeps walking toward a coin across the room, the illusion breaks.
- **Stable.** It commits to things. An agent that switches between two goals every frame, walking two steps left and two steps right, is the most common and most visible failure in game AI.
- **Fair.** It acts on what it could plausibly know. Enemies that see through walls or react before you've moved feel like cheating, even when the game technically allows it.
- **Beatable, and interesting to beat.** It has patterns a player can learn and weaknesses they can exploit, and it changes enough that exploiting them stays interesting.
- **Cheap.** It runs inside a frame, alongside rendering, physics and everything else. A decision that takes ten milliseconds is not a decision a game can afford, and fifty agents making one each is worse.

None of these is about being clever. All of them are about decisions, made many times a second, that look right from the outside.

---

## Sense, think, act

Every game agent, from a Pac-Man ghost to a squad of soldiers, does three things over and over:

- **Sense:** find out what's going on. Its own health, where the player is, what's in the room, what it heard, how much time is left.
- **Think:** decide what to do about it. Go for the coin, drink the potion, run, attack, wait.
- **Act:** do it. Walk there, play the animation, swing the sword, pick the coin up.

Most of a game's code already handles sensing and acting. Your game knows where everything is, has collision, has movement, has animation. What it usually doesn't have is a good, general way to *think*: to take everything the agent knows and turn it into the single thing it should do right now.

That middle step is where game AI lives, and it's where all of the approaches below differ. It's also the only step GMSmartAgent takes part in. It never moves anything, never searches your room, never plays an animation. Your game tells it what the agent knows, and it tells your game what the agent should do. Keeping thinking separate from sensing and acting is not a limitation; it means GMSmartAgent works with whatever movement, physics and pathfinding your game already has, and never fights them.

---

## Our goblin

The whole series uses one small running example, because it's easier to compare approaches on the same problem.

A goblin lives in a room with coins and potions on the floor. It loves gold. It also wants to stay alive. Sometimes the player walks in. Here's what we'd like it to do, in plain words:

- Pick up coins, preferring the close ones.
- When it's hurt, drink a potion. The more hurt, the more urgently.
- When the player is near and the goblin is in no state to fight, run away.
- When there's nothing to do, wander around instead of standing still.

Four wishes, and already they pull against each other. A hurt goblin standing next to a coin, with a potion across the room: what should it do? A healthy goblin with the player approaching and a pile of gold in the corner: is it brave or greedy? There isn't one right answer; there's the answer that makes *your* goblin feel like your goblin. A good way of thinking makes those trade-offs easy to express and easy to change.

Let's try the common ways.

---

## The first way: a chain of ifs

The natural first attempt is to write the wishes down as conditions, in order of importance:

```gml
if (hp < 30 && potion_nearby) {
    target = nearest_potion;
    action = "drink";
} else if (player_nearby && hp < 50) {
    action = "flee";
} else if (coin_nearby) {
    target = nearest_coin;
    action = "loot";
} else {
    action = "wander";
}
```

This works, and for a small enemy it may be all you ever need. It's fast, it's obvious, and anyone can read it. But watch what happens as soon as you ask anything subtle of it.

**The cliffs.** At 30 health the goblin drinks. At 31 it doesn't care about potions at all, not even one right under its feet. Real urgency doesn't flip like a switch; it grows. To fake that, you add another branch, "if hp < 50 and a potion is very close", and then another, and the thresholds start multiplying.

**The order decides everything.** Drinking is checked before fleeing, so a goblin at 25 health walks *past the player* to reach a potion. Swap the two branches and a hurt goblin flees even when the potion is right beside it and the player is far away. Neither order is right in every situation, because the right choice depends on *how* hurt it is, *how* close the potion is and *how* close the player is, all at once. An if-chain can only look at them one at a time.

**Which coin?** `nearest_coin` is a decision of its own, hidden inside a helper. What if the nearest coin is next to the player? Now "which coin" needs to know about the player too, and the helper grows its own ifs.

**Every change touches everything.** Adding a new behavior, say "attack when the player is weak", means finding the right place in the chain, and every branch above it changes whether the new one is ever reached. After a few weeks the chain is a long, fragile list in which the order of lines carries meaning nobody wrote down.

None of this means if-chains are bad. It means they describe *rules*, and good behavior is mostly made of *trade-offs*.

---

## State machines

The next step most games take is a **finite state machine**. The agent is always in exactly one state, like `LOOTING`, `DRINKING`, `FLEEING` or `WANDERING`. Each state knows how to behave while it's active, and a set of **transitions** says when to switch to another state:

```gml
switch (state) {
    case "loot":
        walk_to(target_coin);
        if (hp < 30) state = "drink";
        else if (player_near()) state = "flee";
        else if (!instance_exists(target_coin)) state = "wander";
        break;

    case "drink":
        walk_to(target_potion);
        if (reached(target_potion)) state = "loot";
        else if (player_near() && hp < 15) state = "flee";
        break;

    case "flee":
        run_from(o_player);
        if (!player_near()) state = (hp < 30) ? "drink" : "loot";
        break;

    case "wander":
        // ...
        break;
}
```

State machines are everywhere in games, and for good reason. The original Pac-Man ghosts are a famous example: each ghost switches between chasing the player, scattering to its own corner of the maze, and running away when frightened, and each one picks a different square to chase, which is what gives the four of them their personalities ([Pittman, "The Pac-Man Dossier"](https://www.gamedeveloper.com/game-platforms/feature-the-i-pac-man-i-dossier)). A handful of states and simple rules, and players still talk about the ghosts as if they were plotting.

What state machines are good at:

- **It's always clear what the agent is doing.** There's exactly one state, so animation, sound and debugging have something solid to hang on.
- **Behavior stays put.** Once in `DRINKING`, the goblin keeps drinking until a transition fires, so it doesn't twitch between goals.
- **Each state is small and self-contained.** Code for fleeing lives in one place.

Where they start to hurt:

- **The transitions are where the thinking happens,** and the transitions are if-chains. Every problem from the previous section is still there, only spread across states: `hp < 30` here, `hp < 15` there, cliffs everywhere.
- **The number of transitions grows much faster than the number of states.** With four states there are up to twelve possible transitions. With ten states there are up to ninety. Adding `ATTACK` to the goblin means deciding, for every existing state, whether and when it can go to `ATTACK`, and whether `ATTACK` can go back to each of them. This is often called *state explosion*, and it's why large state machines become hard to change without breaking something.
- **States are about what, not which.** `LOOTING` says the goblin is collecting coins, but choosing *which* coin is still a separate decision that the state machine doesn't help with.

A useful way to think about it: a state machine is excellent at describing *what an agent is doing*, and much weaker at deciding *what it should be doing*. Many games keep a state machine for the first job and put something else in charge of the second. GMSmartAgent is designed to be that something else: it can decide which state to enter, and your state machine carries it out.

---

## Behavior trees

**Behavior trees** became popular in the mid 2000s, notably through Bungie's Halo games ([Bungie on eight years of Halo AI](https://gamedeveloper.com/game-platforms/in-depth-bungie-on-eight-years-of-i-halo-i-ai)), and they're now a standard tool in many engines. A behavior tree organises decisions as a tree. Its branches are checked from top to bottom, in priority order:

```
Selector (try each child until one succeeds)
├── Sequence: [hp is low] -> [potion exists] -> [go to potion] -> [drink]
├── Sequence: [player is near] -> [hp is not high] -> [flee]
├── Sequence: [coin exists] -> [go to coin] -> [pick up]
└── Wander
```

The tree is re-checked regularly. The first branch whose conditions all pass is the one that runs.

What behavior trees are good at:

- **Structure.** Complicated behavior breaks down into small reusable pieces: "go to something" is one node used by every branch.
- **Designers can work with them,** often in a visual editor, without touching code.
- **Sequences.** "Go to the potion, then drink it" is natural to express.

Where they still hurt:

- **It's still priority order.** The top branch wins whenever its conditions pass, so "drink before fleeing" or "flee before drinking" is still a fixed choice, written into the shape of the tree.
- **Conditions are still yes or no.** "hp is low" is a threshold again, and the cliffs come back.
- **Choosing among many similar options,** like which of twelve coins, is not what trees are built for.

Many teams address the last two points by putting scores inside their trees: a node that rates its children and picks the best one. That idea, rating options instead of checking them in order, is the next approach, and it's the one GMSmartAgent is built around.

---

## Utility: scoring every option

**Utility AI** starts from a different question. Instead of "which rule applies?", it asks "how good would each thing I could do be, right now?" ([Utility system](https://en.wikipedia.org/wiki/Utility_system)).

Every option the agent has gets a **score**, usually a number from 0 to 1. The score comes from the things that matter for that option: how hurt the goblin is, how far the potion is, how close the player is. The option with the highest score wins. A moment later, when the agent thinks again, every option is scored again with the new situation, and the winner may be a different one.

Here's the goblin's problem from earlier, scored. The goblin is at 35% health. There's a coin right next to it, a potion across the room, and the player nowhere near:

| Option | What matters | Score |
| --- | --- | --- |
| Loot the coin beside it | Very close | 0.48 |
| Drink the far potion | Fairly hurt, but the potion is far | 0.41 |
| Flee | Player is far away | 0.02 |
| Wander | Always a little bit worth it | 0.05 |

The numbers are made up for the example; the next chapters build real ones. The goblin grabs the coin first. Now move the potion closer, or drop the goblin to 20% health, and drinking's score climbs past looting's. Bring the player into the room and fleeing climbs past both. Nothing in the table says "check drinking before fleeing". Each option's score simply depends on everything that matters to it, all at once, and the comparison happens on its own.

Look at what that fixes:

- **No cliffs.** Urgency grows smoothly. At 35% health drinking matters somewhat, at 20% it matters a lot, at 5% it matters more than anything. You shape that growth instead of picking a threshold.
- **No hidden order.** Options don't need to know about each other. Each is rated on its own merits, so the right one wins in every situation the scores describe, including the ones you didn't think of.
- **"Which one" is the same question as "what".** Each coin is its own option, scored by its own distance. The best coin wins the same way the best action does.
- **Adding behavior is local.** A new action is a new scored option. Nothing else has to change. If it's never worth it, it never wins; if it's sometimes worth it, it wins exactly then.
- **Personality is a dial.** A greedy goblin rates coins a little higher. A cowardly one rates fleeing higher. Same logic, different numbers, visibly different characters.

Utility AI has well-known users. The Sims is the classic case: each Sim has needs like hunger, energy and fun, objects in the house advertise how much they'd satisfy each need, and the Sim walks to whatever scores best for it right now.

It's not free of problems, and it's worth knowing them up front, because a good part of this series is about handling them:

- **Scores need shaping.** How much should 40% health matter? A utility system replaces thresholds with *curves*, little shapes that say how much something matters at each value. Choosing them is a skill, and it's what Chapters 3 and 4 are about.
- **Close scores cause twitching.** Two coins at nearly the same distance can swap places in the ranking every time the agent thinks, and the agent dithers between them. The standard cure is **commitment**: a small bonus for whatever the agent is already doing. It comes up in Chapter 6.
- **Scores are invisible.** Without a way to see them, a utility agent can feel like a black box. That's why GMSmartAgent shows every score and every reason on screen, and why Chapter 9 is entirely about reading them.
- **One decision at a time.** Utility picks the best thing to do *now*. It doesn't, by itself, work out that it needs a key before it can open a chest. That's what planning is for.

---

## Planning: more than one step ahead

Some goals take several steps that depend on each other. Put a locked chest in the room and a key somewhere else. "Raid the chest" now means getting the key, walking to the chest and unlocking it, or, without a key, smashing the chest open, which is slow and loud. No single scored action captures that; the order of steps matters, and whether a step is possible depends on the steps before it.

A **planner** works this out. You describe the steps an agent can take, what each one needs and what each one changes, and the planner finds a sequence that gets from the situation now to the goal. There are two well-known styles:

- **Goal-oriented action planning (GOAP)** gives the planner a goal ("the chest is open") and a list of actions with preconditions and effects. The planner searches for a sequence on its own. It was made famous by the soldiers in F.E.A.R., who flanked, took cover and regrouped from plans nobody wrote by hand ([Orkin, "Three States and a Plan"](https://gdcvault.com/play/1013282/Three-States-and-a-Plan)).
- **Hierarchical task networks (HTN)** work from recipes. A task like "raid the chest" has several methods ("unlock it with the key", "smash it"), each a list of smaller tasks and steps. The planner picks the first method that works and breaks it down. Designers keep tight control over how things are done, and the planner fills in the details ([Kelly, Botea and Koenig, "Planning with Hierarchical Task Networks in Video Games"](https://icaps07-satellite.icaps-conference.org/workshop8/Planning%20with%20Hierarchical%20Task%20Networks%20in%20Video%20Games.pdf)).

Planning and utility fit together naturally. **Utility decides what the agent wants. Planning works out how to get it.** The goblin's scores decide that raiding the chest is the best thing to do right now. The planner works out the steps. If, halfway through, a potion becomes urgent, the scores change and the goblin drops the plan to go and drink. GMSmartAgent has both, built to work together, and you can write recipes, goals, or both in one plan.

Planning has its own costs. A planner searches, and searching takes time, so plans have to be made in small slices across frames when there are many agents. Plans also break: the key gets picked up by someone else, a door closes. A good planner notices and repairs the plan instead of walking into a wall. Both are covered later in the series.

---

## Learning: AI that changes from play

Everything so far is written by the designer and stays the same however the game is played. Some games want more: an AI that adapts to the player.

There are a few quite different ideas hiding under "learning", and it helps to separate them:

- **Copying the player.** A companion that watches what you pick up, which fights you take and which you avoid, and starts making the same kinds of choices.
- **Learning what works.** Enemies that try things, see how it went, and do more of what paid off. If one kind of coin in the room is cursed and bites whoever touches it, the goblins can learn which kind to leave alone, even though nothing in their code ever says which one it is.
- **Predicting the player.** Learning what the player tends to do next, after a dodge, or before a heavy attack, so an enemy can see it coming.
- **Adapting the game around the player.** Left 4 Dead's "AI Director" watches how the players are coping and changes the pacing, the number of enemies and where they come from, to keep tension rising and falling ([Booth, "The AI Systems of Left 4 Dead"](https://cdn.fastly.steamstatic.com/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf)).

Learning brings real risks, and they're the reason it's often avoided:

- **It can make the game worse.** An enemy that learns to exploit a weakness in the level, or that becomes unbeatable, has learned the wrong lesson as far as the player is concerned.
- **It's hard to predict and hard to test.** The designer no longer knows exactly how an agent will behave in an hour.
- **It needs data.** A model that has seen three choices knows almost nothing, and acting on it confidently looks random.

GMSmartAgent's approach is to keep the designer in charge. Models learn, but they only reorder the options your scores allow. They can't bring back an option your scoring ruled out, and they can't push something above what you said it's worth. A model with little data has little say. That way learning adds character and adaptation without taking the game away from you.

---

## Knowing the player

A last family of ideas isn't about agents choosing actions at all, but about understanding the people playing:

- **How good is this player?** A rating, learned from wins and losses, can set the difficulty, pick a fair opponent, or split a lobby into even teams.
- **How does this player play?** Some rush in, some snipe from far away, some explore every corner. Recognizing a play style lets a game respond to it: enemies that counter a rusher, a level that rewards an explorer.

Both of these turn into inputs an agent can decide with, like "the player is probably stronger than me" or "this player usually rushes". GMSmartAgent has both, and they come much later in the series, once the basics are second nature.

---

## Putting the approaches side by side

| Approach | Good at | Struggles with |
| --- | --- | --- |
| If-chains | Tiny enemies, quick prototypes, obvious rules | Trade-offs, cliffs, order hidden in the code, growth |
| State machines | Knowing what the agent is doing, stable behavior, animation | Transitions that multiply, decisions buried in the transitions |
| Behavior trees | Structure, reusable pieces, sequences, designer tools | Fixed priority order, yes-or-no conditions, choosing among many |
| Utility | Trade-offs, choosing the best of many, smooth urgency, easy to extend | Needs curves to be shaped, needs commitment, needs tools to see |
| Planning | Goals that take several dependent steps | Search cost, plans that break |
| Learning | Adapting to the player, discovering what works | Unpredictable, needs data, needs limits |

None of these replaces the others completely, and real games mix them. A common shape, and the one this series builds toward, is utility at the centre deciding what matters most right now, planning underneath it for anything that takes several steps, learning layered on top where adaptation is worth it, and the game's own state machine, animation and movement carrying out the result.

---

## Where GMSmartAgent fits

GMSmartAgent is a pure GML framework for the *think* part of sense, think, act. In terms of the map above:

- **Its heart is utility.** You describe the options an agent has and what matters to each one; it scores them all and ranks them, every time the agent thinks.
- **It shapes scores with curves,** so "how much does 40% health matter" is a shape you choose and can see.
- **It handles many agents** with a scheduler that gives all of them one shared time budget per frame, so adding agents never drops your frame rate; agents just re-think a little less often.
- **It plans** with recipes, goals or both, keeps plans working as the world changes, and spreads planning over several frames when needed.
- **It learns** from the player's choices and from outcomes, predicts sequences of actions, and always within the limits your scoring sets.
- **It knows the player,** with ratings and play styles that can feed straight back into decisions.
- **It shows its work.** Every score, every consideration and every plan can be drawn on screen, and there's a test module to lock behavior in place once it's right.
- **It only decides.** Movement, collision, animation and sensing stay in your game, written the way your game already does them.

That list is also, roughly, the order of the series. The first ten chapters are the foundation: scores, inputs, curves, targets, acting on a decision, handling the cases where nothing is worth doing, many agents, seeing what's happening, and tests. After that, each chapter stands on its own and answers one question you might actually have, from "why does my agent flicker?" to "how do I make a boss that learns my habits?".

---

## What you've learned

- Game AI is judged by the player, from the outside. The goal is behavior that is readable, consistent, responsive, stable, fair and beatable, and that fits inside a frame.
- Every agent senses, thinks and acts. GMSmartAgent only does the thinking.
- If-chains and state machines describe rules well and trade-offs badly: thresholds become cliffs, and the order of checks quietly decides behavior.
- Behavior trees add structure, but keep fixed priorities and yes-or-no conditions.
- Utility AI scores every option on everything that matters to it and picks the best, which makes trade-offs, "which one" questions and new behaviors natural. It needs curves, commitment and good tools.
- Planning handles goals with several dependent steps. Learning adapts behavior to the player and the game, and is safest when the designer keeps the final say.

## What's next

[Chapter 2](Chapter2.md) builds the goblin's first real decision with GMSmartAgent: two options, one input, and a score that tells it when to stop looting and go drink.

## Further reading

- [The Pac-Man Dossier](https://www.gamedeveloper.com/game-platforms/feature-the-i-pac-man-i-dossier), Jamey Pittman: how four ghosts with a few simple modes got their personalities.
- [In-Depth: Bungie on Eight Years of Halo AI](https://gamedeveloper.com/game-platforms/in-depth-bungie-on-eight-years-of-i-halo-i-ai): the Halo games and the rise of behavior trees.
- [Utility system](https://en.wikipedia.org/wiki/Utility_system), Wikipedia: a short overview of scoring-based decision making in games.
- [Three States and a Plan: The A.I. of F.E.A.R.](https://gdcvault.com/play/1013282/Three-States-and-a-Plan), Jeff Orkin, GDC 2006: goal-oriented action planning in a shipped game.
- [Planning with Hierarchical Task Networks in Video Games](https://icaps07-satellite.icaps-conference.org/workshop8/Planning%20with%20Hierarchical%20Task%20Networks%20in%20Video%20Games.pdf), Kelly, Botea and Koenig: HTN planning applied to games.
- [The AI Systems of Left 4 Dead](https://cdn.fastly.steamstatic.com/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf), Michael Booth, Valve: an AI that adapts the game's pacing to the players.
- [Game AI Pro](https://gameaipro.com/): three volumes of chapters by working game AI developers, free to read online, covering every approach in this chapter in depth.