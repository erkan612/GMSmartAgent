function gmsa_learn_schedule(_model, _scheduler, _priority = 0) {
    __gmsa_learn_check_model(_model);
    if (_model.__work != undefined) throw "GMSA: learn model is already scheduled";
    if (_model.train != undefined && _model.waiting == undefined) {
        throw "GMSA: learn schedule needs the model's waiting method, returning true when train has work";
    }
    var _work = { model : _model };
    _work.work = method(_work, __gmsa_learn_work_turn);
    gmsa_scheduler_add_work(_scheduler, _work, _priority);
    _model.__work = _work;
    return _model;
}

function gmsa_learn_unschedule(_model) {
    __gmsa_learn_check_model(_model);
    var _work = _model.__work;
    if (_work == undefined) return false;
    gmsa_scheduler_remove_work(_work.__scheduler.scheduler, _work);
    _model.__work = undefined;
    return true;
}

function __gmsa_learn_work_turn(_budget) {
    if (model.frozen || model.train == undefined || !model.waiting()) return false;
    gmsa_learn_train(model, _budget);
    return true;
}