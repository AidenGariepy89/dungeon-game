- the current problem is pointers get invalidated in ECS.CompArr.components as it is a std.ArrayList.
  I either need to not use std.ArrayList, or live by the rule of no long lasting pointers to components like that.
  - Ill go with live by the rule

- consider an iterator for ECS systems?
