if (mouse_check_button_pressed(mb_left)) pick_at(mouse_x, mouse_y);

if (keyboard_check_pressed(ord("1"))) view = 0;
if (keyboard_check_pressed(ord("2"))) view = 1;
if (keyboard_check_pressed(ord("3"))) view = 2;

// LambdaMART trains 2 ms per step until done, its old trees keep their opinion meanwhile
if (training) {
    train_frames++;
    if (gmsa_learn_train(lambdamart, 2000)) {
        training = false;
        if (train_again) { train_again = false; training = true; train_frames = 0; }
        refresh();
    }
}

if (keyboard_check_pressed(ord("R"))) {
    for (var _m = 0; _m < array_length(models); _m++) {
        gmsa_learn_reset(models[_m].model);
        models[_m].ranks = [];
    }
    picks = 0;
    training = false;
    train_again = false;
    refresh();
}