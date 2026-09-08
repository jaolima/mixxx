import "Theme"
import Mixxx 1.0 as Mixxx
import QtQuick
import QtQuick.Layouts

// Cabecalho de um deck: capa, faixa, tempo que falta, andamento e tonalidade.
//
// A controladora ja resolve o toque - jog, pads, faders. O que ela nao tem e
// tela, e e por isso que estes quatro numeros ficam aqui: sao os que se olham
// para decidir a proxima mixagem. O tempo restante diz quando agir, o andamento
// e a tonalidade dizem com o que.
//
// Tonalidade em destaque, como na etiqueta de uma loja de discos, porque mixar
// em harmonia comeca por ela.
Item {
    id: root

    required property string group
    required property real dp

    readonly property var deckPlayer: Mixxx.PlayerManager.getPlayer(group)
    readonly property var deckTrack: deckPlayer ? deckPlayer.currentTrack : null

    Mixxx.ControlProxy {
        id: bpmControl

        group: root.group
        key: "bpm"
    }
    Mixxx.ControlProxy {
        id: positionControl

        group: root.group
        key: "playposition"
    }

    // Quanto falta, nao quanto ja passou: e o numero que decide a hora de
    // encostar a proxima faixa.
    readonly property real remainingSeconds: {
        if (!deckTrack || deckTrack.duration <= 0) {
            return 0;
        }
        const left = deckTrack.duration * (1 - positionControl.value);
        return left > 0 ? left : 0;
    }

    function formatTime(seconds) {
        const total = Math.floor(seconds);
        const mins = Math.floor(total / 60);
        const secs = total % 60;
        return "-" + mins + ":" + (secs < 10 ? "0" : "") + secs;
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.deckBackgroundColor
        radius: Math.round(4 * root.dp)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Math.round(8 * root.dp)
        anchors.rightMargin: Math.round(8 * root.dp)
        spacing: Math.round(10 * root.dp)

        Rectangle {
            Layout.preferredHeight: parent.height - Math.round(10 * root.dp)
            Layout.preferredWidth: Layout.preferredHeight
            color: "#0a0a0a"
            radius: Math.round(3 * root.dp)

            Image {
                anchors.fill: parent
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                source: root.deckTrack ? root.deckTrack.coverArtUrl : ""
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                color: Theme.white
                elide: Text.ElideRight
                font.pixelSize: Math.round(15 * root.dp)
                text: root.deckTrack && root.deckTrack.title
                    ? root.deckTrack.title
                    : qsTr("no track")
            }
            Text {
                Layout.fillWidth: true
                color: Theme.deckTextColor
                elide: Text.ElideRight
                font.pixelSize: Math.round(12 * root.dp)
                text: root.deckTrack && root.deckTrack.artist ? root.deckTrack.artist : ""
            }
        }

        // Fonte de largura fixa nos numeros: eles mudam o tempo todo e nao
        // podem dancar na tela enquanto se olha para eles.
        Text {
            color: root.remainingSeconds > 0 && root.remainingSeconds < 30
                ? Theme.accentColor
                : Theme.deckTextColor
            font.family: "monospace"
            font.pixelSize: Math.round(20 * root.dp)
            text: root.deckTrack ? root.formatTime(root.remainingSeconds) : "-0:00"
        }

        Text {
            color: Theme.white
            font.bold: true
            font.family: "monospace"
            font.pixelSize: Math.round(24 * root.dp)
            text: bpmControl.value > 0 ? bpmControl.value.toFixed(1) : "--"
        }

        Rectangle {
            Layout.preferredHeight: Math.round(30 * root.dp)
            Layout.preferredWidth: Math.round(52 * root.dp)
            color: root.deckTrack && root.deckTrack.keyText ? Theme.accentColor : "transparent"
            radius: Math.round(3 * root.dp)

            Text {
                anchors.centerIn: parent
                color: Theme.white
                font.bold: true
                font.pixelSize: Math.round(14 * root.dp)
                text: root.deckTrack && root.deckTrack.keyText ? root.deckTrack.keyText : ""
            }
        }
    }
}
