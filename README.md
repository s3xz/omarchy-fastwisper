# FastWisper for the Omarchy bar

An [Omarchy](https://omarchy.org) bar widget for [FastWisper](https://github.com/s3xz/FastWisper), private voice dictation for Omarchy and Hyprland where speech recognition and text cleanup run on your own machine.

The widget shows what FastWisper is doing right now:

| State | Icon |
| --- | --- |
| Idle | sound wave in the bar colour |
| Recording | animated sound wave, high contrast |
| Transcribing | sound wave, high contrast |
| Error | sound wave in the theme's urgent colour |
| Daemon stopped or loading, or app not installed | dimmed sound wave |

Hover it for a tooltip with the current state.

> This repository contains only the bar widget. Dictation itself, the background service, the hotkeys and the recording pill come from the FastWisper app: <https://github.com/s3xz/FastWisper>.

## Requirements

- Omarchy with the Quickshell-based Omarchy shell (plugin manifest schema 1)
- **The FastWisper app**, with the `fastwisper` command on your `PATH` or in `~/.local/bin`, and its `fastwisperd` user service running. Follow the [FastWisper quick start](https://github.com/s3xz/FastWisper#quick-start).
- `env` and `setpriv` (coreutils and util-linux) and `notify-send` (libnotify). All of them ship with Omarchy.

Without the FastWisper app the widget still loads, stays dimmed with the tooltip "FastWisper app not installed", and checks again every 30 seconds. Clicking it shows a notification with the install link.

## Install

```sh
omarchy plugin add https://github.com/s3xz/omarchy-fastwisper.git --enable
```

This clones the repository into `~/.config/omarchy/plugins/io.github.s3xz.fastwisper` and adds the widget to the right side of the bar. The FastWisper installer can also do this for you with `packaging/omarchy/install.sh --bar-plugin`.

If you used an older FastWisper release, its installer placed a bar widget called `fastwisper.dictation`. After adding this plugin, remove the old one so you don't get two icons:

```sh
omarchy plugin remove fastwisper.dictation
```

## Usage

- **Left-click:** toggle hands-free dictation (`fastwisper ctl toggle`).
- **Right-click:** open the FastWisper hub (`fastwisper hub`). If the hub isn't installed, a notification explains why.
- Push-to-talk and the other hotkeys are configured in FastWisper itself, not in this widget.

## Configure

Edit the widget's entry in the bar layout in `~/.config/omarchy/shell.json`:

| Setting | Default | Description |
| --- | --- | --- |
| `cliPath` | `""` | Absolute path to the `fastwisper` command. Leave empty to use `fastwisper` from `PATH`, then `~/.local/bin/fastwisper`. |

Example:

```json
{ "id": "io.github.s3xz.fastwisper", "cliPath": "/opt/fastwisper/bin/fastwisper" }
```

To move the widget, use the bar layout editor or `omarchy plugin enable io.github.s3xz.fastwisper --section left` (or `center`).

## Remove

```sh
omarchy plugin remove io.github.s3xz.fastwisper
```

To keep the files but hide the widget, use `omarchy plugin disable io.github.s3xz.fastwisper`. Removing the widget doesn't touch the FastWisper app; see [Uninstall and roll back](https://github.com/s3xz/FastWisper#uninstall-and-roll-back) in its README.

## What it runs

The widget is QML only. It never uses sudo, downloads nothing, stores nothing and doesn't edit your configuration. These are the only commands it starts, always as your user and without a shell:

| Command | When |
| --- | --- |
| `env <cli> --version` | at startup, to find the FastWisper CLI (and every 30 s while it's missing) |
| `setpriv --pdeathsig TERM <cli> status --follow --bar --localized` | all the time, to follow the dictation state; it reports state only, never the dictated text, and stops with the shell |
| `<cli> ctl toggle` | on left-click |
| `<cli> hub` | on right-click |
| `notify-send -a FastWisper ...` | when the hub can't open or the app is missing |

`<cli>` is the `cliPath` setting, `fastwisper` from `PATH` or `~/.local/bin/fastwisper`.

## License

[MIT](LICENSE) © 2026 s3xz
