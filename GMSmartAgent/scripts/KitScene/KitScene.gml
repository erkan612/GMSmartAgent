function kit_scene_goblin_profile() {
    return gmsa_kit_profile("kit scene goblin", {
        inputs : {
            hp       : gmsa_kit_input_var("hp", 0, 100),
            distance : gmsa_kit_input_distance(400),
            //free     : gmsa_kit_input_read(function(_goblin, _thing) { return (instance_exists(_thing.claimed) && _thing.claimed != _goblin) ? 0 : 1; }, 0, 1, true),
            free     : gmsa_kit_input_read(function(_goblin, _thing) { // now the closer one should go for it
                var _c = _thing.claimed;
                if (!instance_exists(_c) || _c == _goblin) return 1;
                return (point_distance(_goblin.x, _goblin.y, _thing.x, _thing.y) < point_distance(_c.x, _c.y, _thing.x, _thing.y) * 0.7) ? 1 : 0;  // a lot closer takes it over
            }, 0, 1, true),
        },
        actions : {
            drink : {
                targets  : gmsa_kit_targets_near(o_kit_potion, 400),
                consider : { hp : gmsa_kit_curve_low(0.4), distance : gmsa_kit_curve_near(), free : gmsa_kit_curve_at_least() },
                start    : kit_scene_claim,
                stop     : kit_scene_release,
                step     : function(_goblin, _potion) {
                    var _r = kit_scene_walk_to(_goblin, _potion);
                    if (_r == true) {
                        _goblin.hp = min(100, _goblin.hp + 40);
                        instance_destroy(_potion);
                    }
                    return _r;
                },
            },
            loot : {
                weight   : 0.5,
                targets  : gmsa_kit_targets_near(o_kit_coin, 400),
                consider : { distance : gmsa_kit_curve_near(), free : gmsa_kit_curve_at_least() },
                start    : kit_scene_claim,
                stop     : kit_scene_release,
                step     : function(_goblin, _coin) {
                    var _r = kit_scene_walk_to(_goblin, _coin);
                    if (_r == true) {
                        _goblin.gold++;
                        instance_destroy(_coin);
                    }
                    return _r;
                },
            },
            wander : {
                weight : 0.05,
                start  : function(_goblin) { _goblin.spot = { x : random(room_width), y : random(room_height) }; },
                step   : function(_goblin) { return kit_scene_walk_to(_goblin, _goblin.spot); },
            },
        },
    });
}

function kit_scene_claim(_goblin, _thing) { // mine while I'm on my way
    _thing.claimed = _goblin;
}

function kit_scene_release(_goblin, _thing) { // stop runs on every way an action ends: done, gone, or something better
    if (instance_exists(_thing) && _thing.claimed == _goblin) _thing.claimed = noone;
}

function kit_scene_walk_to(_inst, _target, _spd = 2) { // moves by position, so nothing keeps sliding when the action changes
    if (!is_struct(_target) && !instance_exists(_target)) return gmsa_kit_step.FAILED;
    var _dist = point_distance(_inst.x, _inst.y, _target.x, _target.y);
    if (_dist <= _spd) {
        _inst.x = _target.x;
        _inst.y = _target.y;
        return true;
    }
    var _dir = point_direction(_inst.x, _inst.y, _target.x, _target.y);
    _inst.x += lengthdir_x(_spd, _dir);
    _inst.y += lengthdir_y(_spd, _dir);
    return false;
}