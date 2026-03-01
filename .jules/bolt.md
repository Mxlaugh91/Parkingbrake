## 2024-05-18 - FiveM State Bag wrapper GC pressure
**Learning:** In FiveM Lua, evaluating `Entity(id).state` inside tight loops causes significant garbage collection pressure due to StateBagInterface wrapper creation.
**Action:** To optimize performance, the state object should be hoisted outside the loop (e.g., `local state = Entity(id).state`) and evaluated inside.
