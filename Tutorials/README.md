# GMSmartAgent Tutorials

Welcome. This is a series that teaches GMSmartAgent from the ground up, starting with what AI in games is actually for and why walking through a list of if statements stops working, and going on to answer every question you might have while building agents of your own.

It comes in two parts. **Basic**, Chapters 1 to 10, builds the foundation from nothing, one idea at a time. **Advanced** is a growing collection of chapters that each answer one question, from why an agent flickers between two choices to how a plan survives a world that keeps changing.

## Who this is for

If you've never built game AI before, you're in the right place. Each chapter in the Basic part explains the underlying *concept* before showing the code: what a score is, why scores multiply, what a curve says about how much something matters, why a score you can't see can't be tuned. Not just a list of function signatures. If you already know some of this from another engine or another framework, feel free to skip ahead, but the Basic chapters build on each other and are meant to be read in order.

The Basic chapters get progressively harder. Chapter 1 assumes nothing, not even that you know what utility AI is. Chapter 10 assumes you've followed along and have the ideas from everything before it.

The Advanced part changes register. Its chapters don't depend on each other and have no reading order: each one brings its own context and stands on its own, so you can open whichever one answers what you're asking. They do assume the foundation from the Basic part, and they spend less time on what a feature is and more on the details that decide whether it works well or merely works.

## What is GMSmartAgent?

GMSmartAgent is a pure GML utility AI framework for GameMaker, no external DLLs, no extensions. Your agents score every option they have, every time they think, and pick the best one. On top of that core it plans goals that take several steps, learns from the player and from what happens, tells how good each player is and how they play, and runs any number of agents inside a fixed time budget per frame.

It's designed for games where things need to make believable choices: enemies that weigh greed against fear, companions that pick up your habits, bosses that read your play, crowds that share one AI budget without dropping a frame. It only decides. Movement, collision, animation and everything your agents sense stay in your game.

## How to use these tutorials

Every chapter is a single `.md` file, with explanations and complete code examples you can paste into a project and run.

The Basic chapters share one running example, a goblin in a room with coins and potions, and each chapter adds one idea to it, so by Chapter 10 you have a complete, tested agent and you know why every part of it is there.

The Advanced chapters have no shared example, deliberately. Each one sets up its own small situation, chosen to fit the question it answers, and by that point you have your own project to bring.

GMSmartAgent ships a debug view, and you'll meet it early. From that point on, every decision can be *seen* as well as read: every option, its score, and the value of everything that went into it, drawn on screen. Learning a decision system without seeing its decisions is unnecessarily hard, so we don't, and Chapter 9 comes back to reading it in full.

Every chapter is written for the latest release of GMSmartAgent.

---

# Basic

The foundation from nothing, one idea at a time, on one goblin.

### [Chapter 1: AI in Games](Chapter1.md)
The gentlest possible starting point. What "AI" means in a game, and why it's judged by the player rather than by how clever it is. The three things every agent does, sense, think and act, and why GMSmartAgent only does the thinking. Then if-chains, state machines, behavior trees, utility scoring, planning and learning, each tried on the same small goblin: what it's good at, where it starts to hurt, and how they fit together in GMSmartAgent.

### [Chapter 2: Thinking in Scores](Chapter2.md)
The goblin's first real decision: loot, or drink. What an option and a score are, why a score is built from considerations that multiply instead of add, and why a single zero vetoes an option. Weights, and why an action with no considerations makes a good baseline. Profiles and agents, a first push input and a first straight-line curve, reading the debug list line by line, and watching where the goblin changes its mind fall out of two numbers you chose. Ends with two goblins built from one function, a greedy one and a cautious one.

### [Chapter 3: What the Agent Knows](Chapter3.md)
Everything an agent knows reaches it as an input, so designing inputs is designing what it perceives. What normalizing does and why a range is a statement about what counts as a lot. Push inputs and pull inputs, when to use which, and the quiet failure of a function that returns nothing. Inputs that are different for every target, and the first potions to choose between. A goblin that notices the player and flees when it's hurt and the player is close, and then a fairer one that flees from what it actually saw and remembers. Bools, kinds and derived values.

### [Chapter 4: How Much It Matters](Chapter4.md)
Curves turn what an agent knows into how much it cares, and that's where an agent's judgment and personality live. How to read a curve, and a small function that draws one on screen with the current value marked. The four parameters every curve shares, then every shape: even lines, slow and fast power curves, U shapes, the S-curve of "barely, then suddenly", hard steps and your own functions or drawn animation curves. Choosing a curve by describing the behavior in words, hard curves that veto against soft ones that only weaken, curves against weights, and the goblin's thirst and fear given shapes on purpose.

### [Chapter 5: Which One](Chapter5.md)
"Loot" isn't a decision, "loot that coin" is. What a target can be, and why every option from every action is ranked together, so "what" and "which" are one choice and more targets never make an action more likely. Gathering targets with a search on the owner, one distance input for every action, and describing each target so the goblin weighs a big coin far away against a small one at its feet, and won't reach for a coin under the player's feet. Readable names in the debug list, separating "whether" from "which" when they're different questions, and keeping a room full of coins from costing a room full of time.

### [Chapter 6: From Choice to Action](Chapter6.md)
The goblin finally moves. Why thinking and acting are separate jobs at different speeds, acting on each decision exactly once, and telling the agent what it's doing. The whole think, act, carry out cycle, then each part taken apart: when to think and when to think at once, actions that finish, fail or simply continue until something better replaces them, and the check every instance target needs. Commitment, the small bonus that ends dithering between two near-equal coins, how much is enough and when it turns into stubbornness. Moments when the game decides for the agent, cooldowns and their catch, and a table of common problems with the part of the cycle each one comes from.

### [Chapter 7: When Nothing Is Worth Doing](Chapter7.md)
Why an agent stops, or worse, creeps away from a player across the room on a score of 0.000001, and why both are honest answers with the wrong look. Idle time as behavior to design, fallback actions that can never be vetoed, and why a fallback's weight is also the bar every other option has to clear. Wandering to a point, and why the point must be the same one every think. A goblin that waits for its moment by watching the player from a wary distance, guards that patrol a route and pick it up again after an interruption, idle actions that take turns, a ladder of fallbacks that never runs out, and seeing which options were vetoed and why.

### [Chapter 8: Many Agents, One Budget](Chapter8.md)
What thinking really costs, measured, and why a crowd of agents makes a game stutter. The scheduler: one slice of time per frame for every agent's thinking, so more agents means slower re-thinking and never a slower game. Setting it up without touching the acting code, intervals, deciding again at once outside the budget and when not to, and how a step runs from the first tier to the last callback. An overlay that shows the budget filling and each goblin's reaction time, sizing the budget, priority tiers so the goblins near the player think first and how a tier can starve the rest, callbacks, separate schedulers for separate kinds of agents, and repeatable decisions from a seed.

### [Chapter 9: Seeing Why](Chapter9.md)
Scores are invisible until you look, so this chapter looks. Inspecting one goblin in a crowd, every part of a debug line, and rebuilding a score by hand down to the commitment bonus that gives away the current choice. An inputs panel that separates a wrong input from a wrong curve, reading the margin between the top two options, catching dithering with a red ring, and changing a profile while the game runs. Then three real tuning problems, a potion ignored, a fear that kicks in too late and a goblin too fond of staring, each found by reading two lines and fixed with one number.

### [Chapter 10: Making It Stay Right](Chapter10.md)
Utility AI breaks in its numbers, not its code, and nothing warns you. Tests that say "given this situation, the agent should choose this": why inputs that read through the owner can be tested and inputs that reach into the room can't, a fake goblin made of a struct, and the first suite. Running tests while you develop and reading a failure, checking targets as well as actions, boundary tests that pin down where the goblin changes its mind, driving an agent across thinks to test commitment, fake clocks for the scheduler and stubs for counting calls. The habits that make tests worth having, what they can't catch, and the end of the Basic part.

---

# Advanced

One question per chapter, each with its own context, in no particular order.

---

## Where to go from here

If you're new to GMSmartAgent, start at Chapter 1 and work through in order, the Basic part is built to be read that way, with each chapter assuming the ideas from everything before it. If you're comfortable with the basics already, open any Advanced chapter that answers your question.

If you're looking for something specific, the [Full Documentation](../ApiReference.md) has every function documented directly, without the surrounding narrative, and [Getting Started](../GettingStarted.md) builds one goblin from scratch in a single guided walkthrough.

Good luck, and happy building.