
# Nuclear Option Pelican Egg

> [!NOTE]
> Dedicated server egg for Nuclear Option installing via SteamCMD on [Pelican Panel](https://pelican.dev/).
>
> **What is Pelican?** Pelican is a modern game server management panel forked from Pterodactyl, featuring improved performance, better UI/UX, and active development. This egg is designed specifically for Pelican and is **not compatible** with [Pterodactyl Panel](https://pterodactyl.io/) due to differences in egg format and features.

___

### Game Description

Nuclear Option is a multiplayer air-combat sandbox with strike aircraft, VTOLs, and dynamic mission objectives.

Fly near-future aircraft with immersive physics on intense battlefields, facing land, air and sea threats. Wage war against AI or other players with an array of potent weapons. Wield tactical and strategic nuclear weapons, capable of annihilating anything in their path.

___

### Egg Capabilities
> This egg installs the headless dedicated server so you can host custom missions and rotations.

- Installs the dedicated server through SteamCMD with optional beta branch, password, and extra install flags.
- Fetches the default DedicatedServerConfig.json and start.sh from this repository on install.
- Uses a custom `start.sh` wrapper script that handles both server updates and workshop content.
- Server auto-update on boot (`STEAM_AUTO_UPDATE=1`, enabled by default) runs SteamCMD validation of game files.
- Workshop auto-update on boot (`WORKSHOP_AUTO_UPDATE=1`, enabled by default) downloads/syncs workshop items when `WORKSHOP_COLLECTION_ID` and Steam credentials are provided.
    - Workshop requires authenticated Steam login to download items.
    - Workshop items automatically copy into mission directory with sanitized folder names.
    - Set `WORKSHOP_AUTO_UPDATE=0` if you've already downloaded content and just want to run/restart without re-downloading.
- Mission content lives under `MISSION_DIR` (default: `/home/container/missions/` as defined in start.sh).
- Server launches via `./start.sh` which invokes `NuclearOptionServer.x86_64` with `-limitframerate ${FRAMERATE}` and `-DedicatedServer DedicatedServerConfig.json`.

___

### Server Ports


| Port | Default | Protocol | Required | Notes |
|---------|---------|---------|---------|---------|
| Game | 7777 | UDP | **Yes** | Required gameserver port. |
| Query | 7778 | UDP | No | This shows your server in the listing. |

___

### Installation

> [!IMPORTANT]
> A Steam account is only required if you enable Workshop downloads (`WORKSHOP_AUTO_UPDATE=1` and `WORKSHOP_COLLECTION_ID` is set). Anonymous install works for the base server and game file updates.

> [!WARNING]
> Steam Guard can block workshop downloads. Disable it for the install account (Not recommended) or be ready to supply fresh codes and/or approve the login via Steam Mobile App. The server will prompt during startup if authentication is needed.

#### Steps to Install

1. **Import the Egg into Pelican**
   - Log into your Pelican Panel as an administrator
   - Navigate to the Admin panel → Eggs
   - Click "Import Egg" button
   - Choose one of these import methods:
     - **Via URL** (recommended): Paste this URL into the import field:
       ```
       https://raw.githubusercontent.com/GetParanoid/NuclearOption-Pelican/refs/heads/main/egg-nuclearoption.json
       ```
     - **Via File**: Upload the `egg-nuclearoption.json` file from your local system
   - Click "Import" to add the egg to your panel

2. **Create a New Server**
   - Navigate to Servers → Create New
   - Select the Nuclear Option egg
   - Configure allocations (minimum 1 UDP port, default 7777)
   - Set memory/CPU limits based on your requirements (recommended: 4GB+ RAM)
   - Complete the server creation process

3. **Configure Server Settings** (Optional)
   - Open the server's management panel
   - Go to the Startup tab
   - Add Steam credentials (`STEAM_USER` and `STEAM_PASS`) if you need workshop content
   - Set `WORKSHOP_COLLECTION_ID` if using a specific workshop collection
   - Adjust `FRAMERATE` limit if needed (default: 30)

4. **Launch and Enjoy**
   - Start the server from the console tab
   - Monitor the installation process and first boot
   - If using workshop content, watch for Steam login prompts
   - Once you see "DedicatedServerKeyValues" in the console, the server is running!

___

### Recommended Egg Modifications

- Pre-fill `STEAM_USER` / `STEAM_PASS` with a host-owned account if you plan to support Workshop sync at scale.
- Pre-set `WORKSHOP_COLLECTION_ID` if you ship a curated mission pack.
    - Create your own workshop collection and add all the missions you want to it.
- If you do not want server file auto-updates, set `STEAM_AUTO_UPDATE` to `0` in the Startup tab.
- If you do not want workshop auto-updates (but still want server updates), set `WORKSHOP_AUTO_UPDATE` to `0` in the Startup tab.

___

### Running With Steam Guard Enabled

1. Enter a fresh Steam Guard code in the server's `Startup` section (`STEAM_AUTH` variable, NOT RECOMMENDED) OR be ready to approve the login via the Steam Mobile App (Recommeneded).
2. Launch the server and watch the console for successful login messages from SteamCMD.
3. After workshop content downloads successfully, consider setting `WORKSHOP_AUTO_UPDATE` to `0` to skip workshop sync on subsequent boots and avoid repeated auth prompts.

> [!CAUTION]
### Known Issues
- Sometimes the initial install fails, simply initiate a reinstall from either the admin panel, or the game-server's panel.