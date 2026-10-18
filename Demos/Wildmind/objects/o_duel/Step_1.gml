if (demo_paused()) exit;
gmnav_scheduler_update(nav_sched); // before Varn steers
gmsa_scheduler_step(ai);           // and before he acts on what he decided