# Owner physical review checklist (Edmund)

Do not auto-answer. Play on PIXEL_USB_DEVICE_1 with the installed PR #27 build.

[ ] Launcher icon looks right
[ ] Splash looks right
[ ] Main menu feels polished
[ ] Touch controls are comfortable
[ ] Runner selection is clear
[ ] Footwear selection is clear
[ ] Tutorial does not block play
[ ] Race HUD is readable while moving
[ ] Drift / boost feedback feels clear
[ ] Pause / resume works
[ ] High contrast feels coherent
[ ] Larger UI is usable
[ ] Results / podium feel rewarding
[ ] Background / resume feels normal
[ ] No obvious stutter or overheating during normal play
[ ] I want to race again

Engineering notes for owner (not PASS claims):
- Install/update succeeded without data wipe (debug signer match).
- Main menu + race start (GO! / Verdant Cascade) physically captured.
- Pause overlay was NOT proven by automation — please verify Pause (Ⅱ) top-right during race.
- High contrast / Larger UI not proven by automation — please toggle on menu and confirm.
- Keyboard-style control prompts appeared on race HUD; confirm whether on-screen touch chrome feels correct.
- Another Godot app on the device occasionally stole focus during automation; for play, keep Pedestrian Pursuit in foreground.
