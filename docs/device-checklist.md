# Device checklist (phase 1)

HabitCore's tests cover the counting contract, the budget, export, and the notification queue. They can't cover what the phone itself does, so run this list by hand on the iPhone and Watch once, before the data matters. Plan reference: issue #1, section 5.

## One-time setup

1. Open `Keystone.xcodeproj` in Xcode, select the `Keystone` scheme and your iPhone, and build. With automatic signing on, Xcode registers the App Group, the iCloud container, HealthKit and push for `com.travissaylor.keystone`.
2. Replace the placeholder `Schedule.reasonLine` in `HabitCore/Sources/HabitCore/Schedule.swift` with your own line.
3. In Calendar, add a recurring Mon–Thu 7:45–9:30 "Gym" event with travel time. This step needs no code.
4. On first launch, allow notifications and Health (workouts, read only). The app has no onboarding, so these system prompts are the only setup screens.

## The normal day

- [ ] The night before a planned day, "Tomorrow 7:45" arrives at 8:00 pm.
- [ ] At 7:40 the go alert arrives as time-sensitive. It reads "Out the door 7:45. Drive 32, gym 8:23. Leave the gym by 9:05. Full session."
- [ ] Ending a Watch workout of 10 minutes or more marks the day done with no tap. The 10:00 "Did you go?" nudge does not arrive.
- [ ] The home screen shows the next session with "Leave the gym by 9:05", this week "n of 4", and last 4 weeks "n of m".

## Evidence edge cases

- [ ] **Locked phone:** lock the phone before ending the workout. The visit appears after unlocking or on the next app open.
- [ ] **Terminated app:** force-quit the app, then end a workout. Background delivery should still log it; opening the app also logs it.
- [ ] **Health denied:** turn off Health access in Settings. Nothing becomes a miss while the day is open. The 10:00 nudge arrives, and "Went" logs the day.
- [ ] **Late sync:** the Watch syncs the workout hours later. The day still counts, even if it read as missed the next morning.
- [ ] **15-minute visit:** a 15-minute workout counts in full.
- [ ] **Afternoon visit:** tap "Later today" on the nudge, then work out in the afternoon. The day counts, and no 10:00 nudge arrives that day.
- [ ] **Control and widget:** the "Log gym visit" control and the widget's "Went" button log today. Today's nudge is removed. Check this one: an extension removing the app's pending notification hasn't been verified on a device.

## Declarations

- [ ] **Rest:** "Rest tomorrow" on the 8:00 pm reminder removes the next morning's alerts. Friday's requests appear in their place.
- [ ] **Travel break:** declare a break for next week. Then check that no pending request exists for those dates, using the Xcode console or by waiting.
- [ ] **Return morning:** the go alert on the return morning quotes the re-entry plan.
- [ ] **Recovery break:** the review question arrives at 8:00 pm on the review date. "One more week" moves the date by 7 days.
- [ ] **Miss:** on the morning after a missed planned day, the morning-after card shows. On Wednesday, a missed Tuesday puts "Friday's open" on the card.

## Durability

- [ ] **iCloud off:** sign out of iCloud, or turn off iCloud for Keystone. The app still opens, logs and counts.
- [ ] **Restore drill:** export data from the menu, delete the app, reinstall, then import the file. The counts and history come back unchanged.
- [ ] **Offline:** in airplane mode, log a visit, then go back online. It syncs to iCloud. On a second device, if you have one, check that the record appears there once.
