// FastWisper status in the Omarchy bar.
//
// Reads `fastwisper status --follow --bar --localized` (one JSON object per
// state change, never the dictated text). The sound-wave icon uses the bar
// colour while idle, maximum contrast with animated bars while recording,
// the urgent colour on errors, and is dimmed while the daemon is stopped or
// loading. Left-click toggles hands-free dictation; right-click opens the hub.
//
// The FastWisper CLI is looked up at runtime, without any install-time
// placeholder: the `cliPath` setting if set, then `fastwisper` on PATH, then
// ~/.local/bin/fastwisper. Without it the widget shows a dimmed
// "FastWisper app not installed" state and checks again every 30 seconds.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.s3xz.fastwisper"

  readonly property string installUrl: "https://github.com/s3xz/FastWisper#quick-start"
  readonly property string missingTip: "FastWisper app not installed. Click for install instructions."

  // Resolved CLI: empty while resolving or when the app is missing.
  property string cli: ""
  property var candidates: []
  property int candidateIndex: 0
  property bool missing: false

  property string fwState: "offline"
  property string tip: "FastWisper"

  readonly property bool busy: fwState === "recording" || fwState === "transcribing"
  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property color iconColor: fwState === "error"
    ? (bar ? bar.urgent : Color.urgent)
    : busy ? (foreground.hslLightness >= 0.5 ? "#ffffff" : "#000000") : foreground

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function candidateList() {
    var list = []
    var custom = String(root.setting("cliPath", "") || "").trim()
    if (custom !== "") list.push(custom)
    list.push("fastwisper")
    var home = Quickshell.env("HOME")
    if (home) list.push(home + "/.local/bin/fastwisper")
    return list
  }

  // Probe each candidate with `env <candidate> --version`: env exits 126/127
  // when the command is missing or not executable, so a failed lookup always
  // ends with a normal exit code.
  function resolve() {
    if (probe.running || follow.running) return
    root.cli = ""
    root.candidates = candidateList()
    root.candidateIndex = 0
    probeNext()
  }

  function probeNext() {
    if (root.candidateIndex >= root.candidates.length) {
      root.missing = true
      root.fwState = "offline"
      root.tip = root.missingTip
      retry.start()
      return
    }
    probe.command = ["env", root.candidates[root.candidateIndex], "--version"]
    probe.running = true
  }

  function found(path) {
    root.cli = path
    root.missing = false
    root.tip = "FastWisper"
    follow.running = true
  }

  function update(line) {
    var data
    try { data = JSON.parse(line) } catch (e) { return }
    root.fwState = String(data.class || "idle")
    root.tip = String(data.tooltip || "FastWisper")
  }

  function notify(message) {
    Quickshell.execDetached(["notify-send", "-a", "FastWisper", "FastWisper", message])
  }

  Component.onCompleted: resolve()
  onSettingsChanged: {
    if (follow.running) follow.running = false
    else if (!probe.running) resolve()
  }

  Process {
    id: probe
    onExited: function(exitCode) {
      if (exitCode === 0) root.found(root.candidates[root.candidateIndex])
      else {
        root.candidateIndex += 1
        root.probeNext()
      }
    }
  }

  // Direct child of the shell with pdeathsig: it goes away with the shell.
  // When it exits (daemon restart, app removed), the CLI is resolved again.
  Process {
    id: follow
    command: ["setpriv", "--pdeathsig", "TERM", root.cli, "status", "--follow", "--bar", "--localized"]
    stdout: SplitParser {
      onRead: function(data) { root.update(data) }
    }
    onExited: {
      root.fwState = "offline"
      restart.start()
    }
  }

  Timer {
    id: restart
    interval: 3000
    onTriggered: root.resolve()
  }

  Timer {
    id: retry
    interval: 30000
    onTriggered: root.resolve()
  }

  // argv directly, no shell: the CLI path may contain spaces or quotes.
  Process {
    id: toggle
    command: [root.cli, "ctl", "toggle"]
  }

  // `fastwisper hub` without the hub installed exits with an error and
  // explains why on stderr: show it as a notification instead of silence.
  // Exit and end of stderr arrive in any order; notify once both are in.
  property int hubExit: -1
  property string hubMessage: ""
  property bool hubMessageDone: false

  function openHubNow() {
    if (openHub.running) return
    root.hubExit = -1
    root.hubMessage = ""
    root.hubMessageDone = false
    openHub.running = true
  }

  function hubFinished() {
    if (root.hubExit < 0 || !root.hubMessageDone) return
    if (root.hubExit !== 0) {
      var message = root.hubMessage.trim().replace(/^fastwisper: /, "")
      root.notify(message || "fastwisper hub")
    }
    root.hubExit = -1
  }

  Process {
    id: openHub
    command: [root.cli, "hub"]
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.hubMessage = text
        root.hubMessageDone = true
        root.hubFinished()
      }
    }
    onExited: function(exitCode) {
      root.hubExit = exitCode
      root.hubFinished()
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    slotSize: Style.bar.statusSlot
    tooltipText: root.tip
    dimmed: root.missing || root.fwState === "offline" || root.fwState === "loading"
    iconComponent: Component {
      Item {
        id: wave
        // Heights of the five bars, left to right.
        readonly property var heights: [0.4, 0.75, 1.0, 0.62, 0.4]
        readonly property real barWidth: Math.max(2, Math.round(width / 8))

        Row {
          anchors.centerIn: parent
          spacing: wave.barWidth

          Repeater {
            model: wave.heights.length

            Rectangle {
              id: stick
              required property int index
              property real level: 1

              anchors.verticalCenter: parent.verticalCenter
              width: wave.barWidth
              height: Math.max(width, Math.round(wave.height * 0.85 * wave.heights[index] * level))
              radius: width / 2
              color: root.iconColor

              Behavior on color { ColorAnimation { duration: 140 } }

              // Recording: each bar oscillates at its own pace.
              SequentialAnimation on level {
                running: root.fwState === "recording"
                loops: Animation.Infinite
                NumberAnimation { to: 0.45; duration: 260 + stick.index * 70; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 260 + stick.index * 70; easing.type: Easing.InOutSine }
                onStopped: stick.level = 1
              }
            }
          }
        }
      }
    }
    onPressed: function(mouseButton) {
      if (root.missing || root.cli === "") {
        if (root.missing) root.notify("FastWisper app not installed. Install it from " + root.installUrl)
        return
      }
      if (mouseButton === Qt.RightButton) root.openHubNow()
      else if (mouseButton === Qt.LeftButton) toggle.running = true
    }
  }
}
