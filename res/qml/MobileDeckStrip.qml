import "Theme"
import Mixxx 1.0 as Mixxx
import QtQuick
import QtQuick.Layouts

// Um deck no layout de toque: identificacao da faixa em cima, transporte
// embaixo.
//
// Traz so PLAY, CUE e SYNC. EQ, filtro, pads e jog ficam de fora de proposito -
// a controladora faz tudo isso melhor do que o vidro, e cada botao a mais aqui
// encolhe os que importam.
Item {
    id: root

    required property string group
    required property real dp
    required property int gap

    readonly property var deckPlayer: Mixxx.PlayerManager.getPlayer(group)
    // O player nao expoe titulo nem artista direto: so currentTrack, que muda a
    // cada carga. Ler atraves dele e o que faz o nome aparecer.
    readonly property var deckTrack: deckPlayer ? deckPlayer.currentTrack : null

    Mixxx.ControlProxy {
        id: playControl

        group: root.group
        key: "play"
    }
    Mixxx.ControlProxy {
        id: cueControl

        group: root.group
        key: "cue_default"
    }
    Mixxx.ControlProxy {
        id: syncControl

        group: root.group
        key: "sync_enabled"
    }
    Mixxx.ControlProxy {
        id: bpmControl

        group: root.group
        key: "bpm"
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: root.gap

        // ---- identificacao da faixa ----
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(34 * root.dp)
            color: Theme.deckBackgroundColor
            radius: Math.round(4 * root.dp)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Math.round(10 * root.dp)
                anchors.rightMargin: Math.round(10 * root.dp)
                spacing: Math.round(10 * root.dp)

                Text {
                    Layout.fillWidth: true
                    color: Theme.deckTextColor
                    elide: Text.ElideRight
                    font.pixelSize: Math.round(14 * root.dp)
                    text: root.deckTrack && root.deckTrack.title
                        ? root.deckTrack.title
                        : qsTr("no track")
                }
                Text {
                    color: Theme.deckTextColor
                    font.family: "monospace"
                    font.pixelSize: Math.round(14 * root.dp)
                    // BPM alinhado a direita e em fonte de largura fixa: o
                    // numero muda o tempo todo e nao pode dancar na tela.
                    text: bpmControl.value > 0 ? bpmControl.value.toFixed(1) : "--"
                }
            }
        }

        // ---- transporte ----
        RowLayout {
            Layout.fillHeight: true
            Layout.fillWidth: true
            spacing: root.gap

            MobileButton {
                Layout.fillHeight: true
                Layout.fillWidth: true
                checked: playControl.value > 0
                label: playControl.value > 0 ? qsTr("PAUSE") : qsTr("PLAY")

                onClicked: {
                    playControl.value = playControl.value > 0 ? 0 : 1;
                }
            }
            MobileButton {
                Layout.fillHeight: true
                Layout.fillWidth: true
                checked: cueControl.value > 0
                label: qsTr("CUE")

                // CUE responde ao apertar e ao soltar, como no hardware:
                // segurar toca a partir do ponto, soltar volta para ele.
                onPressed: cueControl.value = 1
                onReleased: cueControl.value = 0
            }
            MobileButton {
                Layout.fillHeight: true
                Layout.preferredWidth: Math.round(110 * root.dp)
                checked: syncControl.value > 0
                label: qsTr("SYNC")

                onClicked: {
                    syncControl.value = syncControl.value > 0 ? 0 : 1;
                }
            }
        }
    }
}
