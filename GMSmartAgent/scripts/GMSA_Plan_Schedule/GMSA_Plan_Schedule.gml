function gmsa_plan_schedule(_planner, _scheduler, _priority = 0) {
    __gmsa_plan_check_planner(_planner);
    if (_planner.__work != undefined) throw "GMSA: plan planner is already scheduled";
    var _work = { planner : _planner };
    _work.work = method(_work, __gmsa_plan_work_turn);
    gmsa_scheduler_add_work(_scheduler, _work, _priority);
    _planner.__work = _work;
    return _planner;
}

function gmsa_plan_unschedule(_planner) {
    __gmsa_plan_check_planner(_planner);
    var _work = _planner.__work;
    if (_work == undefined) return false;
    gmsa_scheduler_remove_work(_work.__scheduler.scheduler, _work);
    _planner.__work = undefined;
    return true;
}

function __gmsa_plan_work_turn(_budget) {
    if (planner.status != gmsa_plan_status.PLANNING) return false;
    gmsa_plan_work(planner, (planner.slice == undefined) ? _budget : min(_budget, planner.slice));
    return true;
}