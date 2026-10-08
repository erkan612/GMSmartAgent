gmsa_tests_all(true);
//gmsa_bench_all();

/*
* Most of these have spikes that won't be seen in an isolation.
* This happens due to garbage collector gettingg overloaded 
* quickly because of benching the whole framework all at once.
*/

/* VM
[GMSA Test] 416 passed, 0 failed, 0 errors
[GMSA Bench] running on VM
[GMSA Bench] curve linear: 1.136 us per eval
[GMSA Bench] curve power: 1.380 us per eval
[GMSA Bench] curve logistic: 1.347 us per eval
[GMSA Bench] curve step: 1.181 us per eval
[GMSA Bench] targets 10: 82.0 us per think, 8.21 us per option
[GMSA Bench] targets 50: 405.3 us per think, 8.11 us per option
[GMSA Bench] targets 100: 829.8 us per think, 8.30 us per option
[GMSA Bench] targets 200: 1677.5 us per think, 8.39 us per option
[GMSA Bench] targets 500: 4458.9 us per think, 8.92 us per option
[GMSA Bench] considerations 1: 11.0 us per think, 10.97 us per consideration
[GMSA Bench] considerations 4: 17.5 us per think, 4.37 us per consideration
[GMSA Bench] considerations 8: 25.9 us per think, 3.23 us per consideration
[GMSA Bench] considerations 16: 42.4 us per think, 2.65 us per consideration
[GMSA Bench] actions 5: 38.5 us per think, 7.69 us per option
[GMSA Bench] actions 20: 154.7 us per think, 7.74 us per option
[GMSA Bench] actions 50: 387.4 us per think, 7.75 us per option
[GMSA Bench] actions 100: 816.7 us per think, 8.17 us per option
[GMSA Bench] agents 100, budget 2000 us:
[GMSA Bench]    create 3.2 ms
[GMSA Bench]    cold lap 2 steps, worst step 2017 us (overshoot 17 us)
[GMSA Bench]    warm 87.7 thinks per step, each agent re-thinks every 1.1 steps, worst step 2022 us (overshoot 22 us)
[GMSA Bench] agents 1000, budget 2000 us:
[GMSA Bench]    create 22.5 ms
[GMSA Bench]    cold lap 13 steps, worst step 2024 us (overshoot 24 us)
[GMSA Bench]    warm 79.7 thinks per step, each agent re-thinks every 12.5 steps, worst step 2041 us (overshoot 41 us)
[GMSA Bench] agents 5000, budget 2000 us:
[GMSA Bench]    create 113.8 ms
[GMSA Bench]    cold lap 62 steps, worst step 2039 us (overshoot 39 us)
[GMSA Bench]    warm 80.3 thinks per step, each agent re-thinks every 62.2 steps, worst step 2025 us (overshoot 25 us)
[GMSA Bench] agents 10000, budget 2000 us:
[GMSA Bench]    create 229.8 ms
[GMSA Bench]    cold lap 121 steps, worst step 2032 us (overshoot 32 us)
[GMSA Bench]    warm 81.2 thinks per step, each agent re-thinks every 123.1 steps, worst step 2040 us (overshoot 40 us)
[GMSA Bench] net 6 in, [8, 1]: forward 30.0 us, train step 155.3 us
[GMSA Bench] net 12 in, [16, 1]: forward 86.2 us, train step 484.1 us
[GMSA Bench] net 12 in, [16, 8, 1]: forward 135.3 us, train step 768.6 us
[GMSA Bench] learn count, 3 options: observe 33.0 us, predict 35.2 us, re-ranked think +45.0 us (base 32.9 us)
[GMSA Bench] learn linear, 3 options: observe 40.2 us, predict 32.6 us, re-ranked think +42.3 us (base 32.9 us)
[GMSA Bench] learn ranknet, 3 options: observe 423.5 us, predict 131.9 us, re-ranked think +111.8 us (base 32.9 us)
[GMSA Bench] learn lambdamart, 3 options: observe 25.1 us, predict 523.5 us, re-ranked think +542.7 us (base 32.9 us), train 1668.8 ms
[GMSA Bench] learn count, 10 options: observe 49.4 us, predict 71.4 us, re-ranked think +92.1 us (base 104.4 us)
[GMSA Bench] learn linear, 10 options: observe 104.0 us, predict 78.5 us, re-ranked think +107.0 us (base 104.4 us)
[GMSA Bench] learn ranknet, 10 options: observe 1253.8 us, predict 412.2 us, re-ranked think +358.3 us (base 104.4 us)
[GMSA Bench] learn lambdamart, 10 options: observe 54.2 us, predict 1710.1 us, re-ranked think +1754.7 us (base 104.4 us), train 5878.2 ms
[GMSA Bench] learn count, 30 options: observe 106.2 us, predict 168.2 us, re-ranked think +266.4 us (base 301.9 us)
[GMSA Bench] learn linear, 30 options: observe 287.9 us, predict 222.5 us, re-ranked think +318.0 us (base 301.9 us)
[GMSA Bench] learn ranknet, 30 options: observe 4036.7 us, predict 1414.5 us, re-ranked think +1243.9 us (base 301.9 us)
[GMSA Bench] learn lambdamart, 30 options: observe 138.5 us, predict 5082.5 us, re-ranked think +5246.1 us (base 301.9 us), train 22361.3 ms
[GMSA Bench] lambdamart train, 100 choices (500 rows), 100 trees:
[GMSA Bench]    unbudgeted 1431.2 ms
[GMSA Bench]    budget 2000 us: 720 calls, worst call 2089 us (overshoot 89 us)
[GMSA Bench] lambdamart train, 500 choices (2500 rows), 100 trees:
[GMSA Bench]    unbudgeted 6857.7 ms
[GMSA Bench]    budget 2000 us: 3414 calls, worst call 2959 us (overshoot 959 us)
[GMSA Bench] track, 3 options: a switch adds 9.8 us (untracked 3.0 us)
[GMSA Bench] outcome count, 3 options: outcome 30.5 us, reward over 8 decisions 234.0 us
[GMSA Bench] outcome linear, 3 options: outcome 23.4 us, reward over 8 decisions 178.9 us
[GMSA Bench] outcome ranknet, 3 options: outcome 178.0 us, reward over 8 decisions 1401.8 us
[GMSA Bench] outcome lambdamart, 3 options: outcome 22.0 us, reward over 8 decisions 174.1 us, train 503.1 ms (500 outcomes)
[GMSA Bench] track, 10 options: a switch adds 20.9 us (untracked 3.0 us)
[GMSA Bench] outcome count, 10 options: outcome 47.8 us, reward over 8 decisions 380.9 us
[GMSA Bench] outcome linear, 10 options: outcome 44.1 us, reward over 8 decisions 344.6 us
[GMSA Bench] outcome ranknet, 10 options: outcome 275.1 us, reward over 8 decisions 2139.8 us
[GMSA Bench] outcome lambdamart, 10 options: outcome 41.4 us, reward over 8 decisions 318.4 us, train 511.3 ms (500 outcomes)
[GMSA Bench] plan, 11 steps: make 332.5 us (23 nodes, 14.46 us each), step_done 34.1 us
[GMSA Bench] plan, 101 steps: make 2919.4 us (203 nodes, 14.38 us each), step_done 257.5 us
[GMSA Bench] plan, backtracking through 19 wrong methods: make 934.6 us (98 nodes)
[GMSA Bench] plan, refresh: repairing a broken task 105.3 us, nothing broken 16.1 us, explain 73.0 us
[GMSA Bench] plan, 12 idle scheduled planners: 12.1 us per scheduler step
[GMSA Bench] plan, 100 idle scheduled planners: 75.9 us per scheduler step
[GMSA Bench] plan, 101 steps: one call 2900.7 us, in 200 us slices 3569.6 us over 14.2 calls, worst call 1094 us
[GMSA Bench] plan, 12 planners at once, budget 100 us: ready after 122 steps, worst step 148 us (over by 48 us)
[GMSA Bench] plan, 12 planners at once, budget 200 us: ready after 60 steps, worst step 235 us (over by 35 us)
[GMSA Bench] plan, 12 planners at once, budget 500 us: ready after 25 steps, worst step 536 us (over by 36 us)
[GMSA Bench] plan, 12 planners at once, budget 1000 us: ready after 13 steps, worst step 1040 us (over by 40 us)
[GMSA Bench] plan, 12 planners at once, budget 2000 us: ready after 7 steps, worst step 2033 us (over by 33 us)
Plan learn benchmarks, 1000 runs each, average per call
designer: make 93.3 us, raid 185.9 us, raid with a failed entrance 282.9 us
step reliability: make 131.5 us, raid 318.8 us, raid with a failed entrance 460.9 us
learned methods: make 158.2 us, raid 407.2 us, raid with a failed entrance 626.4 us
both: make 191.1 us, raid 481.1 us, raid with a failed entrance 729.0 us
player fact read: first in a frame 67.1 us, cached 2.7 us
make, plain facts: 51.5 us
make, player facts, first in a frame: 144.5 us
make, player facts, cached: 75.3 us
[GMSA Bench] goap, the camp (5 actions): 358.4 us, 25 nodes
[GMSA Bench] goap, chain 5 with 2 distractions (7 actions), pruned: 329.8 us, 25 nodes, 13.19 us per node
[GMSA Bench] goap, chain 5 with 2 distractions (7 actions), no pruning: 973.3 us, 91 nodes, 10.70 us per node
[GMSA Bench] goap, chain 5 with 2 distractions (7 actions), no pruning, cost functions: 1213.6 us, 112 nodes, 10.84 us per node
[GMSA Bench] goap, chain 5 with 2 distractions (7 actions), no pruning, variety 0.3: 1141.6 us, 98 nodes, 11.65 us per node
[GMSA Bench] goap, chain 9 with 4 distractions (13 actions), pruned: 896.2 us, 81 nodes, 11.06 us per node
[GMSA Bench] goap, chain 9 with 4 distractions (13 actions), no pruning: 12202.0 us, 1261 nodes, 9.68 us per node
[GMSA Bench] goap, chain 9 with 4 distractions (13 actions), no pruning, cost functions: 14913.7 us, 1456 nodes, 10.24 us per node
[GMSA Bench] goap, chain 9 with 4 distractions (13 actions), no pruning, variety 0.3: 13620.1 us, 1456 nodes, 9.35 us per node
[GMSA Bench] goap, chain 11 with 6 distractions (17 actions), pruned: 1385.8 us, 121 nodes, 11.45 us per node
[GMSA Bench] goap, chain 11 with 6 distractions (17 actions), no pruning: 81782.4 us, 7633 nodes, 10.71 us per node
[GMSA Bench] goap, chain 11 with 6 distractions (17 actions), no pruning, cost functions: 98308.8 us, 8704 nodes, 11.29 us per node
[GMSA Bench] goap, chain 11 with 6 distractions (17 actions), no pruning, variety 0.3: 90652.8 us, 8704 nodes, 10.42 us per node
[GMSA Bench] goap, the biggest unpruned in 1000 us slices: 123284 us over 119 calls, worst call 1205 us
[GMSA Bench] goap, dinner (a recipe with a goal inside): 346.0 us, 23 nodes
Learn sequence benchmarks, 300 choices each after 500 to warm up, average per call
n-gram length 1, 1 input, 4 actions: predict 127.3 us, observe 153.6 us (slowest 284 us), 79 contexts
n-gram length 3, 1 input, 4 actions: predict 214.5 us, observe 284.7 us (slowest 526 us), 820 contexts
n-gram length 8, 1 input, 4 actions: predict 396.7 us, observe 706.4 us (slowest 6890 us), 3982 contexts
n-gram length 3, 4 inputs, 4 actions: predict 212.0 us, observe 386.2 us (slowest 7915 us), 3886 contexts
n-gram length 3, 1 input, 12 actions: predict 378.1 us, observe 469.4 us (slowest 924 us), 2408 contexts
n-gram length 8, 4 inputs, 12 actions: predict 504.6 us, observe 1293.4 us (slowest 10245 us), 3888 contexts
TDNN length 3, 1 input, 4 actions, replay 0, layers [16]: predict 331.6 us, observe 1261.0 us (slowest 2345 us), replays 2.9 us (slowest 6 us)
TDNN length 3, 1 input, 4 actions, replay 4, layers [16]: predict 335.1 us, observe 1261.0 us (slowest 2047 us), replays 4740.1 us (slowest 7188 us)
TDNN length 3, 1 input, 4 actions, replay 8, layers [16]: predict 337.9 us, observe 1267.3 us (slowest 2417 us), replays 9439.9 us (slowest 12182 us)
TDNN length 8, 1 input, 4 actions, replay 4, layers [16]: predict 536.3 us, observe 2212.3 us (slowest 3732 us), replays 8360.1 us (slowest 10906 us)
TDNN length 3, 4 inputs, 4 actions, replay 4, layers [16]: predict 439.4 us, observe 1577.7 us (slowest 2900 us), replays 5865.0 us (slowest 8348 us)
TDNN length 3, 1 input, 12 actions, replay 4, layers [16]: predict 1153.9 us, observe 3936.8 us (slowest 6428 us), replays 14749.1 us (slowest 22079 us)
TDNN length 3, 1 input, 4 actions, replay 4, layers [32,16]: predict 1211.9 us, observe 5411.1 us (slowest 7684 us), replays 21289.5 us (slowest 23916 us)
Learn Naive Bayes and nearest neighbor benchmarks, 300 choices each after warming up (500, or until the memory is full), average per call
count, 4 inputs, 4 actions: predict 55.9 us, observe 45.4 us (slowest 70 us)
count, 1 input, 8 targets: predict 55.3 us, observe 37.4 us (slowest 54 us)
bayes, 4 inputs, 4 actions: predict 179.1 us, observe 263.8 us (slowest 415 us)
bayes, 12 inputs, 4 actions: predict 429.4 us, observe 660.1 us (slowest 1309 us)
bayes, 4 inputs, 12 actions: predict 476.5 us, observe 718.0 us (slowest 925 us)
bayes, 4 inputs, 4 actions, bins 64: predict 229.3 us, observe 352.6 us (slowest 552 us)
bayes, 4 inputs, 4 actions, outcomes: predict 180.4 us, outcome 194.2 us (slowest 271 us)
bayes, 1 input, 8 targets: predict 145.4 us, observe 205.2 us (slowest 297 us)
neighbor capacity 64, 4 inputs, 4 actions: predict 313.6 us, observe 362.9 us (slowest 502 us), 64 moments
neighbor capacity 256, 4 inputs, 4 actions: predict 607.8 us, observe 738.9 us (slowest 1373 us), 256 moments
neighbor capacity 1024, 4 inputs, 4 actions: predict 1530.5 us, observe 2029.2 us (slowest 3722 us), 1024 moments
neighbor capacity 2048, 4 inputs, 4 actions: predict 2634.2 us, observe 3596.0 us (slowest 5981 us), 2048 moments
neighbor capacity 256, 12 inputs, 4 actions: predict 1104.3 us, observe 1266.6 us (slowest 5100 us), 256 moments
neighbor capacity 256, 4 inputs, 12 actions: predict 972.9 us, observe 1098.7 us (slowest 2004 us), 256 moments
neighbor capacity 256, 4 inputs, 4 actions, outcomes: predict 1359.3 us, outcome 1500.8 us (slowest 2925 us), 256 moments
neighbor capacity 1024, 4 inputs, 4 actions, outcomes: predict 4186.6 us, outcome 4687.2 us (slowest 7480 us), 1024 moments
neighbor capacity 256, 1 input, 8 targets: predict 4559.4 us, observe 4700.4 us (slowest 7038 us), 256 moments
neighbor capacity 1024, 1 input, 8 targets: predict 10721.1 us, observe 11267.5 us (slowest 18285 us), 1024 moments
[GMSA Bench] rating match, 1 v 1: 45.574 us per match  (2000 runs, 91.1 ms total)
[GMSA Bench] rating match, free for all of 8: 318.736 us per match  (2000 runs, 637.5 ms total)
[GMSA Bench] rating match, 5 v 5: 103.004 us per match  (2000 runs, 206.0 ms total)
[GMSA Bench] rating match, 4 teams of 4: 172.965 us per match  (2000 runs, 345.9 ms total)
[GMSA Bench] rating chance: 8.214 us per call  (10000 runs, 82.1 ms total)
[GMSA Bench] rating pick, 10 candidates: 84.872 us per call  (5000 runs, 424.4 ms total)
[GMSA Bench] rating explain: 7.037 us per call  (2000 runs, 14.1 ms total)
[GMSA Bench] rating balance, 8 players into 2 teams: quick 144 us (gap 2.7), searched 229 us, worst 337 us (gap 2.6)
[GMSA Bench] rating balance, 10 players into 2 teams: quick 164 us (gap 0.5), searched 519 us, worst 852 us (gap 0.3)
[GMSA Bench] rating balance, 12 players into 3 teams: quick 256 us (gap 1.8), searched 1938 us, worst 5166 us (gap 1.2)
[GMSA Bench] rating balance, 16 players into 4 teams: quick 620 us (gap 0.9), searched 13717 us, worst 16111 us (gap 0.7)
[GMSA Bench] rating balance, 20 players into 4 teams: quick 881 us (gap 0.6), searched 15994 us, worst 17400 us (gap 0.6)
[GMSA Bench] rating balance, 30 players into 5 teams: quick 2489 us (gap 0.3), searched 22264 us, worst 26294 us (gap 0.3)
[GMSA Bench]    gap: strongest team's average rating minus the weakest's, in rating points
[GMSA Bench] style count: 2.297 us per call  (10000 runs, 23.0 ms total)
[GMSA Bench] style sample: 2.421 us per call  (10000 runs, 24.2 ms total)
[GMSA Bench] style tick, 4 measures: 3.512 us per call  (10000 runs, 35.1 ms total)
[GMSA Bench] style match, 3 styles: 30.077 us per call  (2000 runs, 60.2 ms total)
[GMSA Bench] style explain, 3 styles: 72.801 us per call  (2000 runs, 145.6 ms total)
[GMSA Bench] style match, 8 styles: 57.498 us per call  (2000 runs, 115.0 ms total)
[GMSA Bench] style explain, 8 styles: 117.100 us per call  (2000 runs, 234.2 ms total)
[GMSA Bench] style fit, 200 sessions of 4 true styles, defaults (up to 8 styles, 20 restarts): found 4
[GMSA Bench]    setup 1.9 ms (not sliced), work 15465.6 ms in 7022 calls of 2000 us, worst call 2660 us (overshoot 660 us)
[GMSA Bench] style fit, 1000 sessions of 4 true styles, defaults (up to 8 styles, 20 restarts): found 4
[GMSA Bench]    setup 9.8 ms (not sliced), work 21454.3 ms in 9846 calls of 2000 us, worst call 2796 us (overshoot 796 us)
elapsed time 00:04:46.1163546s
SUCCESS: Run Program Complete
*/

/* YYC
[GMSA Test] 416 passed, 0 failed, 0 errors
[GMSA Bench] running on YYC
[GMSA Bench] curve linear: 0.284 us per eval
[GMSA Bench] curve power: 0.374 us per eval
[GMSA Bench] curve logistic: 0.342 us per eval
[GMSA Bench] curve step: 0.283 us per eval
[GMSA Bench] targets 10: 21.1 us per think, 2.11 us per option
[GMSA Bench] targets 50: 101.6 us per think, 2.03 us per option
[GMSA Bench] targets 100: 205.0 us per think, 2.05 us per option
[GMSA Bench] targets 200: 418.1 us per think, 2.09 us per option
[GMSA Bench] targets 500: 1130.4 us per think, 2.26 us per option
[GMSA Bench] considerations 1: 3.3 us per think, 3.30 us per consideration
[GMSA Bench] considerations 4: 5.0 us per think, 1.24 us per consideration
[GMSA Bench] considerations 8: 7.0 us per think, 0.87 us per consideration
[GMSA Bench] considerations 16: 11.1 us per think, 0.69 us per consideration
[GMSA Bench] actions 5: 9.6 us per think, 1.92 us per option
[GMSA Bench] actions 20: 38.2 us per think, 1.91 us per option
[GMSA Bench] actions 50: 101.0 us per think, 2.02 us per option
[GMSA Bench] actions 100: 192.8 us per think, 1.93 us per option
[GMSA Bench] agents 100, budget 2000 us:
[GMSA Bench]    create 1.7 ms
[GMSA Bench]    cold lap 1 steps, worst step 601 us (overshoot 0 us)
[GMSA Bench]    warm 100.0 thinks per step, each agent re-thinks every 1.0 steps, worst step 644 us (overshoot 0 us)
[GMSA Bench] agents 1000, budget 2000 us:
[GMSA Bench]    create 15.3 ms
[GMSA Bench]    cold lap 4 steps, worst step 2006 us (overshoot 6 us)
[GMSA Bench]    warm 332.8 thinks per step, each agent re-thinks every 3.0 steps, worst step 2006 us (overshoot 6 us)
[GMSA Bench] agents 5000, budget 2000 us:
[GMSA Bench]    create 73.4 ms
[GMSA Bench]    cold lap 20 steps, worst step 2013 us (overshoot 13 us)
[GMSA Bench]    warm 274.5 thinks per step, each agent re-thinks every 18.2 steps, worst step 2007 us (overshoot 7 us)
[GMSA Bench] agents 10000, budget 2000 us:
[GMSA Bench]    create 155.0 ms
[GMSA Bench]    cold lap 36 steps, worst step 2007 us (overshoot 7 us)
[GMSA Bench]    warm 280.0 thinks per step, each agent re-thinks every 35.7 steps, worst step 2007 us (overshoot 7 us)
[GMSA Bench] net 6 in, [8, 1]: forward 3.5 us, train step 29.9 us
[GMSA Bench] net 12 in, [16, 1]: forward 8.6 us, train step 92.1 us
[GMSA Bench] net 12 in, [16, 8, 1]: forward 13.0 us, train step 150.8 us
[GMSA Bench] learn count, 3 options: observe 10.3 us, predict 10.3 us, re-ranked think +12.7 us (base 8.3 us)
[GMSA Bench] learn linear, 3 options: observe 9.2 us, predict 7.1 us, re-ranked think +9.2 us (base 8.3 us)
[GMSA Bench] learn ranknet, 3 options: observe 71.2 us, predict 19.9 us, re-ranked think +19.7 us (base 8.3 us)
[GMSA Bench] learn lambdamart, 3 options: observe 6.6 us, predict 67.8 us, re-ranked think +70.0 us (base 8.3 us), train 360.7 ms
[GMSA Bench] learn count, 10 options: observe 14.3 us, predict 17.3 us, re-ranked think +23.3 us (base 25.8 us)
[GMSA Bench] learn linear, 10 options: observe 23.6 us, predict 17.7 us, re-ranked think +24.1 us (base 25.8 us)
[GMSA Bench] learn ranknet, 10 options: observe 209.1 us, predict 63.2 us, re-ranked think +64.6 us (base 25.8 us)
[GMSA Bench] learn lambdamart, 10 options: observe 14.2 us, predict 212.2 us, re-ranked think +219.4 us (base 25.8 us), train 1238.9 ms
[GMSA Bench] learn count, 30 options: observe 26.4 us, predict 37.3 us, re-ranked think +61.5 us (base 75.1 us)
[GMSA Bench] learn linear, 30 options: observe 63.7 us, predict 47.4 us, re-ranked think +73.2 us (base 75.1 us)
[GMSA Bench] learn ranknet, 30 options: observe 665.3 us, predict 224.7 us, re-ranked think +222.9 us (base 75.1 us)
[GMSA Bench] learn lambdamart, 30 options: observe 32.0 us, predict 593.4 us, re-ranked think +653.3 us (base 75.1 us), train 4282.5 ms
[GMSA Bench] lambdamart train, 100 choices (500 rows), 100 trees:
[GMSA Bench]    unbudgeted 311.2 ms
[GMSA Bench]    budget 2000 us: 153 calls, worst call 2012 us (overshoot 12 us)
[GMSA Bench] lambdamart train, 500 choices (2500 rows), 100 trees:
[GMSA Bench]    unbudgeted 1465.9 ms
[GMSA Bench]    budget 2000 us: 737 calls, worst call 2042 us (overshoot 42 us)
[GMSA Bench] track, 3 options: a switch adds 5.4 us (untracked 0.9 us)
[GMSA Bench] outcome count, 3 options: outcome 10.4 us, reward over 8 decisions 78.0 us
[GMSA Bench] outcome linear, 3 options: outcome 6.0 us, reward over 8 decisions 44.0 us
[GMSA Bench] outcome ranknet, 3 options: outcome 36.2 us, reward over 8 decisions 283.4 us
[GMSA Bench] outcome lambdamart, 3 options: outcome 6.3 us, reward over 8 decisions 52.2 us, train 115.5 ms (500 outcomes)
[GMSA Bench] track, 10 options: a switch adds 13.0 us (untracked 0.9 us)
[GMSA Bench] outcome count, 10 options: outcome 14.1 us, reward over 8 decisions 107.8 us
[GMSA Bench] outcome linear, 10 options: outcome 10.4 us, reward over 8 decisions 77.9 us
[GMSA Bench] outcome ranknet, 10 options: outcome 56.7 us, reward over 8 decisions 445.6 us
[GMSA Bench] outcome lambdamart, 10 options: outcome 9.9 us, reward over 8 decisions 83.8 us, train 116.1 ms (500 outcomes)
[GMSA Bench] plan, 11 steps: make 80.0 us (23 nodes, 3.48 us each), step_done 8.1 us
[GMSA Bench] plan, 101 steps: make 685.6 us (203 nodes, 3.38 us each), step_done 52.7 us
[GMSA Bench] plan, backtracking through 19 wrong methods: make 203.8 us (98 nodes)
[GMSA Bench] plan, refresh: repairing a broken task 24.7 us, nothing broken 3.8 us, explain 29.3 us
[GMSA Bench] plan, 12 idle scheduled planners: 3.8 us per scheduler step
[GMSA Bench] plan, 100 idle scheduled planners: 24.9 us per scheduler step
[GMSA Bench] plan, 101 steps: one call 709.7 us, in 200 us slices 931.1 us over 4.2 calls, worst call 502 us
[GMSA Bench] plan, 12 planners at once, budget 100 us: ready after 30 steps, worst step 114 us (over by 14 us)
[GMSA Bench] plan, 12 planners at once, budget 200 us: ready after 16 steps, worst step 205 us (over by 5 us)
[GMSA Bench] plan, 12 planners at once, budget 500 us: ready after 7 steps, worst step 505 us (over by 5 us)
[GMSA Bench] plan, 12 planners at once, budget 1000 us: ready after 4 steps, worst step 1008 us (over by 8 us)
[GMSA Bench] plan, 12 planners at once, budget 2000 us: ready after 2 steps, worst step 2005 us (over by 5 us)
Plan learn benchmarks, 1000 runs each, average per call
designer: make 23.5 us, raid 46.0 us, raid with a failed entrance 69.4 us
step reliability: make 32.1 us, raid 81.0 us, raid with a failed entrance 116.7 us
learned methods: make 41.1 us, raid 115.7 us, raid with a failed entrance 179.2 us
both: make 50.4 us, raid 137.9 us, raid with a failed entrance 208.9 us
player fact read: first in a frame 16.9 us, cached 0.8 us
make, plain facts: 12.7 us
make, player facts, first in a frame: 37.3 us
make, player facts, cached: 18.8 us
[GMSA Bench] goap, the camp (5 actions): 79.5 us, 25 nodes
[GMSA Bench] goap, chain 5 with 2 distractions (7 actions), pruned: 68.8 us, 25 nodes, 2.75 us per node
[GMSA Bench] goap, chain 5 with 2 distractions (7 actions), no pruning: 196.8 us, 91 nodes, 2.16 us per node
[GMSA Bench] goap, chain 5 with 2 distractions (7 actions), no pruning, cost functions: 247.6 us, 112 nodes, 2.21 us per node
[GMSA Bench] goap, chain 5 with 2 distractions (7 actions), no pruning, variety 0.3: 234.3 us, 98 nodes, 2.39 us per node
[GMSA Bench] goap, chain 9 with 4 distractions (13 actions), pruned: 176.2 us, 81 nodes, 2.18 us per node
[GMSA Bench] goap, chain 9 with 4 distractions (13 actions), no pruning: 2481.2 us, 1261 nodes, 1.97 us per node
[GMSA Bench] goap, chain 9 with 4 distractions (13 actions), no pruning, cost functions: 2894.2 us, 1456 nodes, 1.99 us per node
[GMSA Bench] goap, chain 9 with 4 distractions (13 actions), no pruning, variety 0.3: 2650.8 us, 1456 nodes, 1.82 us per node
[GMSA Bench] goap, chain 11 with 6 distractions (17 actions), pruned: 266.4 us, 121 nodes, 2.20 us per node
[GMSA Bench] goap, chain 11 with 6 distractions (17 actions), no pruning: 15647.1 us, 7633 nodes, 2.05 us per node
[GMSA Bench] goap, chain 11 with 6 distractions (17 actions), no pruning, cost functions: 19331.0 us, 8704 nodes, 2.22 us per node
[GMSA Bench] goap, chain 11 with 6 distractions (17 actions), no pruning, variety 0.3: 17323.1 us, 8704 nodes, 1.99 us per node
[GMSA Bench] goap, the biggest unpruned in 1000 us slices: 46939 us over 46 calls, worst call 1151 us
[GMSA Bench] goap, dinner (a recipe with a goal inside): 74.0 us, 23 nodes
Learn sequence benchmarks, 300 choices each after 500 to warm up, average per call
n-gram length 1, 1 input, 4 actions: predict 33.1 us, observe 41.0 us (slowest 66 us), 79 contexts
n-gram length 3, 1 input, 4 actions: predict 53.8 us, observe 73.8 us (slowest 349 us), 820 contexts
n-gram length 8, 1 input, 4 actions: predict 104.7 us, observe 219.1 us (slowest 2764 us), 3982 contexts
n-gram length 3, 4 inputs, 4 actions: predict 63.6 us, observe 128.9 us (slowest 2387 us), 3886 contexts
n-gram length 3, 1 input, 12 actions: predict 82.2 us, observe 124.0 us (slowest 3923 us), 2408 contexts
n-gram length 8, 4 inputs, 12 actions: predict 126.8 us, observe 533.6 us (slowest 4358 us), 3888 contexts
TDNN length 3, 1 input, 4 actions, replay 0, layers [16]: predict 52.1 us, observe 234.4 us (slowest 461 us), replays 0.8 us (slowest 6 us)
TDNN length 3, 1 input, 4 actions, replay 4, layers [16]: predict 53.4 us, observe 233.0 us (slowest 436 us), replays 832.7 us (slowest 1551 us)
TDNN length 3, 1 input, 4 actions, replay 8, layers [16]: predict 55.0 us, observe 232.4 us (slowest 368 us), replays 1651.1 us (slowest 2137 us)
TDNN length 8, 1 input, 4 actions, replay 4, layers [16]: predict 78.8 us, observe 412.5 us (slowest 766 us), replays 1517.4 us (slowest 2820 us)
TDNN length 3, 4 inputs, 4 actions, replay 4, layers [16]: predict 64.9 us, observe 275.2 us (slowest 520 us), replays 986.3 us (slowest 1872 us)
TDNN length 3, 1 input, 12 actions, replay 4, layers [16]: predict 160.9 us, observe 659.2 us (slowest 886 us), replays 2446.2 us (slowest 4547 us)
TDNN length 3, 1 input, 4 actions, replay 4, layers [32,16]: predict 128.4 us, observe 919.2 us (slowest 1655 us), replays 3551.8 us (slowest 6100 us)
Learn Naive Bayes and nearest neighbor benchmarks, 300 choices each after warming up (500, or until the memory is full), average per call
count, 4 inputs, 4 actions: predict 16.6 us, observe 14.9 us (slowest 34 us)
count, 1 input, 8 targets: predict 13.8 us, observe 10.5 us (slowest 19 us)
bayes, 4 inputs, 4 actions: predict 41.9 us, observe 61.6 us (slowest 102 us)
bayes, 12 inputs, 4 actions: predict 97.3 us, observe 148.3 us (slowest 275 us)
bayes, 4 inputs, 12 actions: predict 107.6 us, observe 161.2 us (slowest 202 us)
bayes, 4 inputs, 4 actions, bins 64: predict 50.0 us, observe 77.6 us (slowest 126 us)
bayes, 4 inputs, 4 actions, outcomes: predict 40.3 us, outcome 44.7 us (slowest 66 us)
bayes, 1 input, 8 targets: predict 34.0 us, observe 47.7 us (slowest 56 us)
neighbor capacity 64, 4 inputs, 4 actions: predict 57.0 us, observe 72.0 us (slowest 341 us), 64 moments
neighbor capacity 256, 4 inputs, 4 actions: predict 106.3 us, observe 142.7 us (slowest 449 us), 256 moments
neighbor capacity 1024, 4 inputs, 4 actions: predict 269.6 us, observe 403.2 us (slowest 655 us), 1024 moments
neighbor capacity 2048, 4 inputs, 4 actions: predict 467.3 us, observe 727.4 us (slowest 1270 us), 2048 moments
neighbor capacity 256, 12 inputs, 4 actions: predict 161.0 us, observe 217.7 us (slowest 281 us), 256 moments
neighbor capacity 256, 4 inputs, 12 actions: predict 144.0 us, observe 180.3 us (slowest 464 us), 256 moments
neighbor capacity 256, 4 inputs, 4 actions, outcomes: predict 237.3 us, outcome 273.5 us (slowest 521 us), 256 moments
neighbor capacity 1024, 4 inputs, 4 actions, outcomes: predict 660.2 us, outcome 787.0 us (slowest 1032 us), 1024 moments
neighbor capacity 256, 1 input, 8 targets: predict 690.2 us, observe 774.2 us (slowest 1356 us), 256 moments
neighbor capacity 1024, 1 input, 8 targets: predict 1589.4 us, observe 1887.0 us (slowest 3398 us), 1024 moments
[GMSA Bench] rating match, 1 v 1: 17.439 us per match  (2000 runs, 34.9 ms total)
[GMSA Bench] rating match, free for all of 8: 79.839 us per match  (2000 runs, 159.7 ms total)
[GMSA Bench] rating match, 5 v 5: 34.650 us per match  (2000 runs, 69.3 ms total)
[GMSA Bench] rating match, 4 teams of 4: 57.076 us per match  (2000 runs, 114.2 ms total)
[GMSA Bench] rating chance: 2.977 us per call  (10000 runs, 29.8 ms total)
[GMSA Bench] rating pick, 10 candidates: 30.325 us per call  (5000 runs, 151.6 ms total)
[GMSA Bench] rating explain: 3.709 us per call  (2000 runs, 7.4 ms total)
[GMSA Bench] rating balance, 8 players into 2 teams: quick 47 us (gap 2.7), searched 61 us, worst 83 us (gap 2.6)
[GMSA Bench] rating balance, 10 players into 2 teams: quick 69 us (gap 0.5), searched 117 us, worst 184 us (gap 0.3)
[GMSA Bench] rating balance, 12 players into 3 teams: quick 83 us (gap 1.8), searched 420 us, worst 947 us (gap 1.2)
[GMSA Bench] rating balance, 16 players into 4 teams: quick 139 us (gap 0.9), searched 2781 us, worst 3288 us (gap 0.7)
[GMSA Bench] rating balance, 20 players into 4 teams: quick 207 us (gap 0.6), searched 3221 us, worst 3697 us (gap 0.6)
[GMSA Bench] rating balance, 30 players into 5 teams: quick 485 us (gap 0.3), searched 4328 us, worst 4982 us (gap 0.3)
[GMSA Bench]    gap: strongest team's average rating minus the weakest's, in rating points
[GMSA Bench] style count: 0.687 us per call  (10000 runs, 6.9 ms total)
[GMSA Bench] style sample: 0.649 us per call  (10000 runs, 6.5 ms total)
[GMSA Bench] style tick, 4 measures: 0.989 us per call  (10000 runs, 9.9 ms total)
[GMSA Bench] style match, 3 styles: 7.906 us per call  (2000 runs, 15.8 ms total)
[GMSA Bench] style explain, 3 styles: 26.919 us per call  (2000 runs, 53.8 ms total)
[GMSA Bench] style match, 8 styles: 14.254 us per call  (2000 runs, 28.5 ms total)
[GMSA Bench] style explain, 8 styles: 35.839 us per call  (2000 runs, 71.7 ms total)
[GMSA Bench] style fit, 200 sessions of 4 true styles, defaults (up to 8 styles, 20 restarts): found 4
[GMSA Bench]    setup 0.4 ms (not sliced), work 2543.8 ms in 1253 calls of 2000 us, worst call 3781 us (overshoot 1781 us)
[GMSA Bench] style fit, 1000 sessions of 4 true styles, defaults (up to 8 styles, 20 restarts): found 4
[GMSA Bench]    setup 2.2 ms (not sliced), work 3494.9 ms in 1724 calls of 2000 us, worst call 2257 us (overshoot 257 us)
elapsed time 00:01:46.5831089s
SUCCESS: Run Program Complete
*/