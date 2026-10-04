if (!variable_instance_exists(id, "kind")) kind = demo5_loot.COIN;
value = (kind == demo5_loot.GEM) ? random_range(0.8, 1) : random_range(0.1, 0.3);