# Specification: deferred mutation (PAT), part D

Modules in `src/nimcs/patterns/`; tests in `tests/test_patterns_<module>.nim`. Each row is a law or an externally visible behaviour; each ID has at least one tagged test. The rows say what a plan that only reads and a pass that only writes guarantee, and what the moved-in world costs.

| ID | Concept | Statement |
|---|---|---|
| PAT-COMMANDBUFFER-01 | command_buffer | Given any world and damage, when planning, then the world is equal to before and equal worlds give equal plans |
| PAT-COMMANDBUFFER-02 | command_buffer | Given any world, when a step runs, then a unit with hp at most the damage is gone and every other unit lost exactly the damage |
| PAT-COMMANDBUFFER-03 | command_buffer | Given a despawn and a damage of the same handle in one batch, when applied, then the damage is ignored |
| PAT-COMMANDBUFFER-04 | command_buffer | Given a despawn, when it is applied twice, then the world is the same as after once, even with a spawn between |
| PAT-COMMANDBUFFER-05 | command_buffer | Given a step that spawns children, when it has run, then each child has the hp the plan gave it and was not damaged by that step |
| PAT-COMMANDBUFFER-06 | command_buffer | Given any commands, when applied together, then the world equals applying them one at a time |
| PAT-COMMANDBUFFER-07 | command_buffer | Given handles that are stale or unknown, when their damage and despawn are applied, then the world is unchanged |
| PAT-COMMANDBUFFER-08 | command_buffer | Given equal worlds and equal commands, when applied, then the results are equal |
| PAT-COMMANDBUFFER-09 | command_buffer | Given a splitting unit, when damage takes it across the threshold, then exactly one child with its new hp appears, and in no other case |
| PAT-COMMANDBUFFER-10 | command_buffer | Given a damage of zero or less, when planning or stepping, then there are no commands and the world is unchanged |
| PAT-COMMANDBUFFER-11 | command_buffer | Given single commands, when applied, then spawn adds a unit, damage lowers hp without removing it and stops at the ends of int |
| PAT-COMMANDBUFFER-12 | command_buffer | Given a world moved in at its last use, when damage or despawn commands are applied, then no allocation happens whatever the size |
