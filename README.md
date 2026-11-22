# Gilla Remake - rebuilt

## 1. Build the APK (GitHub, no PC tools needed)
1. Create a new GitHub repo and upload everything in this folder **plus your `GillaRemake__1_.apk`** (same folder as `map/`, `game/`).
2. (Multiplayer) Settings > Secrets and variables > Actions > **Variables** > New: `SERVER_URL` = your server address (step 2 below, looks like `wss://something.onrender.com`).
3. Actions tab > "Build Gilla Remake APK" > Run workflow. Download `GillaRemake-rebuilt` from Artifacts, unzip, install with SideQuest.

## 2. Host the multiplayer server (pick one)
The server is `server/server.py` - a tiny relay, nothing else. Players enter the same room code (the ROOM pad in the lobby) and see each other.

**A. Free, easiest: Render.com**
New > Web Service > connect your repo > Root directory `server` > Runtime Docker > Free plan. When it's live, your address is `wss://<name>.onrender.com`. (Free plan sleeps after idle; the game reconnects automatically, first connect can take ~1 minute.)

**B. Your own PC, free, no account hosting: Cloudflare quick tunnel**
```
pip install websockets==12.0
python server/server.py
cloudflared tunnel --url http://localhost:8765
```
Use the `https://xxxx.trycloudflare.com` address it prints, but as `wss://xxxx.trycloudflare.com`. The address changes each time you start it, so re-run the workflow with the new `SERVER_URL`.

## 3. Mod rights (real kicks)
Set a repo **secret** `MOD_TOKEN` and the same value as the `MOD_TOKEN` environment variable on the server. Run the workflow with "include_mod_token" ticked ONLY for your private build. Everyone else's build (token not included) can only "yeet" players (knock them up), not kick them.

## 4. Make the mod room only yours
The Mod Room pad is locked for everyone except builds that carry your secret token and connect to your server:
1. Pick a secret word. Add it as a repo **secret** named `MOD_TOKEN`, and as an environment variable `MOD_TOKEN` (same value) on your Render service.
2. Run the workflow with **include_mod_token** ticked and keep that APK for yourself only.
3. Run it again with the box unticked for the APK you share. Their pad shows "MODS ONLY (locked)".

## What's in the game
- Lobby: concrete bunker, pads for the Lethal Ape map, Mod Room, fur shop, room selector, punch menu; friends list wall; GillaCAM screen; GillaOS desk.
- Lethal Ape map: your map, with loot (gold bars), a recycler near spawn, an exit portal far away, weapons near spawn, 2 white monsters and 1 gold-suit monster, scattered props.
- Mod room: mod menu (speed, super jump, low gravity, fly with trigger, platforms with A/X, noclip), kick hammer, axe, pickaxe, chainsaw (trigger to run), 2 training dummies, player list with yeet/kick.
- Controls: hands push off surfaces to move, GRIP picks up / holds tools (release to drop), right stick snap-turns, trigger runs the chainsaw / flies.
