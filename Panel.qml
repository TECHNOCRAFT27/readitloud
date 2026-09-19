import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// readitloud — read clipboard text aloud. A bar icon that toggles speech:
// left-click or ALT+S (keybinding → omarchy-shell shell toggle readitloud.tts)
// starts/stops. Right-click opens a small status/control popup.
Panel {
  id: root
  moduleName: "readitloud.tts"
  ipcTarget: "readitloud.tts"
  manageIpc: false

  readonly property string helperPath: Qt.resolvedUrl("speak.sh").toString().replace("file://", "")

  readonly property string engine: setting("engine", "edge-tts")
  readonly property string voice: setting("voice", "en-IN-NeerjaExpressiveNeural")
  readonly property string rate: setting("rate", "-20%")
  readonly property string pitch: setting("pitch", "+0Hz")
  readonly property string volume: setting("volume", "+0%")

  readonly property string icon: "󰗊"
  property bool speaking: false
  property bool synthesizing: false
  property real progressFraction: 0
  property real positionSec: 0
  property real durationSec: 0
  property real synthShimmer: 0

  readonly property string statusText:
    root.speaking ? (root.synthesizing ? "Synthesizing" : "Playing") : "Ready"
  readonly property string timeText:
    root.durationSec > 0
      ? root.formatTime(Math.round(root.positionSec)) + " / " + root.formatTime(Math.round(root.durationSec))
      : ""

  function formatTime(totalSeconds) {
    if (isNaN(totalSeconds) || totalSeconds < 0) totalSeconds = 0
    var m = Math.floor(totalSeconds / 60)
    var s = totalSeconds % 60
    return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
  }

  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(fg, 1.4)
  readonly property string ff: bar ? bar.fontFamily : Style.font.family

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // ----- speak.sh plumbing -----
  Process {
    id: ttsProcess
    command: ["bash", root.helperPath, "start"]
    onExited: function(exitCode) {
      root.speaking = false
      root.synthesizing = false
      root.progressFraction = 0
      root.positionSec = 0
      root.durationSec = 0
    }
  }

  Process {
    id: progressProcess
    command: ["bash", root.helperPath, "progress"]
    stdout: StdioCollector {
      id: progressOut
      waitForEnd: true
    }
    onExited: function() {
      var fields = String(progressOut.text).trim().split(" ")
      if (fields.length < 4) return
      if (fields[0] === "1") {
        root.progressFraction = parseFloat(fields[1]) || 0
        root.positionSec = parseFloat(fields[2]) || 0
        root.durationSec = parseFloat(fields[3]) || 0
        root.synthesizing = root.durationSec <= 0
      } else if (ttsProcess.running) {
        root.synthesizing = true
      }
    }
  }

  Timer {
    interval: 1000
    repeat: true
    running: true
    triggeredOnStart: false
    onTriggered: progressProcess.running = true
  }

  function startSpeech() {
    if (ttsProcess.running) return
    ttsProcess.command = ["bash", root.helperPath, "start",
      "--engine", root.engine, "--voice", root.voice,
      "--rate", root.rate, "--pitch", root.pitch, "--volume", root.volume]
    ttsProcess.running = true
    root.speaking = true
    root.synthesizing = true
    root.progressFraction = 0
    root.positionSec = 0
    root.durationSec = 0
  }

  function stopSpeech() {
    ttsProcess.running = false  // kills an in-flight speak.sh start (mid-synthesis)
    root.speaking = false
    root.synthesizing = false
    root.progressFraction = 0
    root.positionSec = 0
    root.durationSec = 0
    stopProcess.command = ["bash", root.helperPath, "stop"]
    stopProcess.running = true
  }

  Process {
    id: stopProcess
  }

  function toggleSpeech() {
    root.speaking ? stopSpeech() : startSpeech()
  }

  // The shell toggles bar widgets through open()/close() (see shell.qml
  // summonBarWidget/hideBarWidget). Tie them to speech so ALT+S (the
  // `omarchy-shell shell toggle readitloud.tts` hotkey) starts and stops
  // reading while the popup doubles as a live status panel.
  function open() {
    root.controller.show()
    if (!root.speaking) startSpeech()
  }

  function close() {
    root.controller.hide()
    if (root.speaking) stopSpeech()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.icon
    active: root.speaking
    tooltipText: root.speaking
      ? "Speaking — " + Math.round(root.progressFraction * 100) + "%" + (root.durationSec > 0 ? " (" + root.timeText + ")" : "")
      : "readitloud — click to read clipboard aloud"
    onPressed: function(b) {
      if (b === Qt.RightButton) root.controller.show()
      else if (b === Qt.MiddleButton) root.stopSpeech()
      else root.toggleSpeech()
    }
  }

  // Live status strip across the bottom of the bar slot: a filled progress
  // bar while playing, an indeterminate sweep while synthesizing.
  Rectangle {
    id: barTrack
    visible: root.speaking
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: 2
    color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.15)

    Rectangle {
      id: barFill
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      height: parent.height
      radius: parent.height / 2
      color: root.fg
      visible: root.speaking && !root.synthesizing
      width: Math.max(parent.height, parent.width * root.progressFraction)
      Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

      SequentialAnimation on opacity {
        running: root.speaking && !root.synthesizing
        loops: Animation.Infinite
        NumberAnimation { to: 0.45; duration: 700; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
      }
    }

    Rectangle {
      id: barShimmer
      width: 26
      height: parent.height
      radius: parent.height / 2
      color: root.fg
      visible: root.speaking && root.synthesizing
      x: -width + root.synthShimmer * (barTrack.width + width)
    }
  }

  NumberAnimation on synthShimmer {
    from: 0
    to: 1
    duration: 1200
    easing.type: Easing.InOutCubic
    loops: Animation.Infinite
    running: root.synthesizing
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(260))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onActivateRequested: root.toggleSpeech()

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(10)

        Row {
          width: parent.width
          spacing: Style.space(8)

          Rectangle {
            width: Style.space(36)
            height: Style.space(36)
            radius: Style.cornerRadius
            color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12)
            Text {
              anchors.centerIn: parent
              text: root.icon
              color: root.fg
              font.family: root.ff
              font.pixelSize: Style.font.title
            }
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: root.statusText
              color: root.fg
              font.family: root.ff
              font.pixelSize: Style.font.title
              font.bold: true
            }

            Text {
              text: root.speaking ? "Click to stop" : "ALT+S or click to read"
              color: Qt.darker(root.fg, 1.4)
              font.family: root.ff
              font.pixelSize: Style.font.caption
            }
          }

          Text {
            id: timeLabel
            visible: root.speaking && root.durationSec > 0
            text: root.timeText
            color: root.fg
            font.family: root.ff
            font.pixelSize: Style.font.caption
            font.bold: true
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        Item {
          width: parent.width
          implicitHeight: Style.space(8)
          visible: root.speaking

          Rectangle {
            id: progTrack
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12)
          }

          Rectangle {
            id: progFill
            anchors.left: progTrack.left
            anchors.verticalCenter: progTrack.verticalCenter
            height: progTrack.height
            radius: progTrack.radius
            color: root.fg
            visible: !root.synthesizing
            width: Math.max(progTrack.height, progTrack.width * root.progressFraction)
            Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
          }

          Rectangle {
            id: progShimmer
            width: Style.space(28)
            height: progTrack.height
            radius: progTrack.radius
            color: root.fg
            visible: root.synthesizing
            x: -width + root.synthShimmer * (progTrack.width + width)
          }
        }

        PanelSeparator {
          foreground: root.fg
        }

        Column {
          width: parent.width
          spacing: Style.space(4)

          Text {
            width: parent.width
            text: "Settings"
            color: Qt.darker(root.fg, 1.4)
            font.family: root.ff
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1.1
          }

          LabelRow { label: "Voice";    value: root.voice }
          LabelRow { label: "Rate";     value: root.rate }
          LabelRow { label: "Pitch";    value: root.pitch }
          LabelRow { label: "Volume";   value: root.volume }
          LabelRow { label: "Engine";   value: root.engine }
        }

        PanelSeparator {
          foreground: root.fg
        }

        Row {
          width: parent.width
          spacing: Style.space(6)

          Button {
            width: (parent.width - parent.spacing) / 2
            text: root.speaking ? "Stop" : "Read aloud"
            active: root.speaking
            foreground: root.fg
            fontFamily: root.ff
            horizontalPadding: Style.spacing.controlPaddingX
            verticalPadding: Style.spacing.controlPaddingY
            bordered: true
            onClicked: root.toggleSpeech()
          }

          Button {
            width: (parent.width - parent.spacing) / 2
            text: "Settings…"
            foreground: root.fg
            fontFamily: root.ff
            horizontalPadding: Style.spacing.controlPaddingX
            verticalPadding: Style.spacing.controlPaddingY
            bordered: true
            onClicked: Quickshell.execDetached(["omarchy-launch-terminal", "ttsctl"])
          }
        }
      }
    }
  }

  component LabelRow: Item {
    id: labelRow
    property string label: ""
    property string value: ""
    width: parent.width
    implicitHeight: Math.max(valueText.implicitHeight, Style.space(16))

    Text {
      text: labelRow.label
      color: root.fg
      font.family: root.ff
      font.pixelSize: Style.font.bodySmall
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      id: valueText
      text: labelRow.value
      color: Qt.darker(root.fg, 1.4)
      font.family: root.ff
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
      anchors.right: parent.right
      anchors.leftMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
    }
  }
}