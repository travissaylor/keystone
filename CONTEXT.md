# Keystone

A one-user app that keeps a Monday-to-Thursday gym habit going and makes the restart after a gap easy. It counts attendance, never workouts.

## Days and weeks

**Planned session**:
A day the user is expected at the gym: a Monday to Thursday outside any break, not rested, in a week whose target is not yet met, plus Friday when it is the flex day.
_Avoid_: Workout day, scheduled day

**Flex day**:
Friday, when it becomes the week's planned session because a Monday-to-Thursday session was missed or rested and the week is not yet done. One per week. Break days never turn it on.
_Avoid_: Make-up day, bonus day

**Week**:
Monday to Sunday, with a target of 4 that can be lowered for that week alone.

**Week target**:
How many visits make a week hit. Default 4.

**Hit**:
A week whose visits reached its target.

**Slots**:
The most visits a week can be asked for: its target, capped by the planned sessions it can actually offer once breaks and rests are taken out.
_Avoid_: Denominator (in user-facing copy)

**Last 4 weeks**:
The current week and the three before it, each counting at most its slots.
_Avoid_: Rolling 28 days

**Rollover**:
4:00 am the next calendar day, the moment an open day can become missed.

## Evidence

**Visit**:
A calendar day with a qualifying Watch workout or a manual "went". At most one per day, on any day of the week.
_Avoid_: Check-in, session (when meaning attendance)

**Evidence**:
What is known about one day: unknown, candidate (sensor only), confirmed (manual went) or rejected (manual didn't go). Manual beats sensor.

**Miss**:
A planned session that reached rollover with no visit and no declaration. Never inferred while the day is open.
_Avoid_: Skip, failure

**Missed in a row**:
Consecutive misses among planned sessions, counted back from the latest closed day. Shown only above zero.
_Avoid_: Streak, days since

## Declarations

**Rest**:
A single day declared off. Not a miss; turns on the flex day.

**Later today**:
A declaration that keeps today open and cancels the 10:00 nudge.

**Break**:
A declared run of days that leaves every denominator. A **travel break** has a last day; a **recovery break** ends on a **review date**, where the user answers "back" or "one more week".
_Avoid_: Pause, vacation mode

**Re-entry plan**:
The user's own sentence for the first session after a break, written when the break starts and quoted on the return morning.

**Comeback**:
The first visit after one or more misses or a break. The app's warmest moment.

## Trip

**Door time**:
7:45, the cue. Leaving the house is the commitment, not arriving at the gym.

**Latest gym exit**:
The home deadline minus the outbound baseline. Always shown on a gym morning.
_Avoid_: Wrap-up time

**Gym minutes**:
Latest gym exit minus gym arrival, warm-up included. Decides the session template.

**Session template**:
Full, short, show-up or light. Every template counts as a full visit.
