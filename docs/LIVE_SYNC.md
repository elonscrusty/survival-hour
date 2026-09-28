# Test new versions without re-downloading the place file

Set this up once. After that, getting Claude's latest changes is one click and Studio updates by itself.

## One-time setup (about 10 minutes)
1. **GitHub Desktop:** install it from desktop.github.com and sign in.
   File → Clone repository → `elonscrusty/survival-hour` → Clone.
   Then at the top, **Current branch** → `claude/roblox-publishing-readiness-k9txa5`.
2. **Rojo:** download `rojo-7.7.0-windows-x86_64.zip` from
   https://github.com/rojo-rbx/rojo/releases/tag/v7.7.0, unzip it, and put `rojo.exe` in the
   `survival-hour` folder (next to `serve.bat`).
3. **Rojo plugin in Studio:** Toolbox → Plugins → search "Rojo" (by rojo-rbx / Lpghatguy) → Install.
   Or run `rojo.exe plugin install` once.

## Every time you test
1. In GitHub Desktop, click **Fetch origin**, then **Pull origin**. That gets Claude's newest changes.
2. Double-click `serve.bat` in the `survival-hour` folder and leave the black window open.
3. Open your place in Studio (the `SurvivalHour.rbxlx` you already have is fine), then
   **Plugins → Rojo → Connect**. The scripts update to the newest version in a couple of seconds.
4. Press **Play**.

While Rojo is connected, pulling again in GitHub Desktop updates Studio straight away, so there's no
need to reopen anything. Save the place (Ctrl+S) if you want to keep the synced version.

Notes:
- Rojo syncs the scripts and settings in `src/`. Uploaded 3D models come from Roblox by their IDs,
  so they appear once they're uploaded, however you test.
- If Rojo says the versions don't match, update the plugin, or download the matching `rojo.exe`.
