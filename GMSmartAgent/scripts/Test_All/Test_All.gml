function gmsa_tests_all(_verbose = false) {
    gmsa_test_clear();
    gmsa_tests_curves();
    gmsa_tests_core();
    gmsa_tests_think();
    gmsa_tests_scheduler();
    gmsa_tests_observe();
    gmsa_tests_debug();
    gmsa_tests_features();
    gmsa_tests_evaluate();
    gmsa_tests_learn_base();
    gmsa_tests_learn_count();
    gmsa_tests_learn_linear();
    gmsa_tests_learn_rerank();
    return gmsa_test_run(_verbose);
}