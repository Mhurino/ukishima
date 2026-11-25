# Media and Beats

This fork has two distinct music-related surfaces: **Media** is the now-playing controller for MPRIS players, while **Beats** is a separate local/online music interface backed by a user-provided helper script.

## Media player

The Media surface reads player state through Quickshell's MPRIS service. A compatible player must publish an MPRIS session for its metadata and controls to appear.

It can display:

- Album art (when the player provides a readable art URL), title, artist, album, and track number.
- Playback state: idle, playing, paused, or stopped.
- Playback controls exposed by the player, including transport controls where supported.
- A seek bar when the player supports seeking, position reporting, and a known duration. Live streams do not expose the ordinary seek interaction.
- Repeat mode when supported: Off → Track → Playlist → Off.
- A source picker when more than one MPRIS player is available.
- A pin control that keeps the pill expanded after the Media card closes.

The right-hand information rail also shows live network throughput and the first connected Bluetooth device that can be identified, including its battery percentage when BlueZ reports one.

### Media layouts

Choose **Default**, **Matrix**, or **Musicassetta** under **Settings → Appearance → Surface Styles → Media Player**. The style changes the card presentation, not the MPRIS player or its playback state.

## Beats

Beats is a separate interface with four main workflows:

- **Online Stations** — list and play configured station entries.
- **Local Music** — browse and search the local library, then play a selected track.
- **Shuffle** and **Stop** — invoke the matching helper actions.
- **Manage Music** — add a station with a name and URL, view the configured stations, and remove one.

The Local Music page can add a folder by entering its path. The local list is filtered by a case-insensitive substring search against the displayed label.

### External helper requirement

The Beats QML surface calls this user-level script:

```text
~/.config/hypr/UserScripts/UkishimaBeats.sh
```

That script is **not part of this repository**. It must be installed separately and must implement the command interface used by the UI:

```text
list-online
list-local
play-online NAME
play-local PATH
shuffle
stop
add NAME URL
remove NAME
add-dir PATH
```

The list commands return tab-separated rows: a display label, then a value/path. Beats invokes the script directly with positional arguments. Because the helper is external, its supported streaming services, local-library scanner, player backend, and additional dependencies are determined by that script rather than by the QML surface.

If Beats opens but the lists do not populate or playback actions do nothing, first check that the helper exists at the expected path, is executable, and supports the commands above.

## Which surface should I use?

Use **Media** to control a player that is already running and exposes MPRIS. Use **Beats** to browse the local music library or the online stations configured through the helper script. They are complementary and are not the same playback backend.
