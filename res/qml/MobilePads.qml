import "Theme"
import Mixxx 1.0 as Mixxx
import QtQuick
import QtQuick.Layouts

// Pads de um deck: pontos de entrada e loops.
//
// Quatro por deck, e nao oito. A controladora tem oito, mas ali eles sao
// fisicos e se acham no escuro pelo tato; no vidro, oito pads nesta largura
// ficam menores que a ponta do dedo e cada erro custa uma faixa fora de hora.
//
// Marcar e apagar no mesmo toque: um pad vazio guarda a posicao atual, um pad
// marcado salta para ela, e o toque longo apaga. E o gesto que a propria
// controladora usa, sem modo separado para gravar.
Item {
    id: root

    required property string group
    required property real dp
    /// "cue" salta para pontos guardados, "loop" liga loops de compasso.
    property string mode: "cue"

    readonly property var loopSizes: [1, 2, 4, 8]

    RowLayout {
        anchors.fill: parent
        spacing: Math.round(4 * root.dp)

        Repeater {
            model: 4

            Rectangle {
                id: pad

                required property int index

                readonly property int number: index + 1
                readonly property bool isCue: root.mode === "cue"
                // A cor vem do proprio ponto guardado, como no computador: e
                // assim que se reconhece um cue de relance, sem ler rotulo.
                readonly property color cueColor: hotcueColor.value >= 0
                    ? Qt.rgba(((hotcueColor.value >> 16) & 0xFF) / 255,
                              ((hotcueColor.value >> 8) & 0xFF) / 255,
                              (hotcueColor.value & 0xFF) / 255,
                              1)
                    : Theme.accentColor
                readonly property bool active: isCue
                    ? hotcueStatus.value > 0
                    : loopEnabled.value > 0

                Layout.fillHeight: true
                Layout.fillWidth: true
                border.color: active ? cueColor : Theme.deckLineColor
                border.width: active ? 0 : 1
                color: {
                    if (mouseArea.pressed) {
                        return isCue ? cueColor : Theme.accentColor;
                    }
                    if (!active) {
                        return Theme.deckBackgroundColor;
                    }
                    return isCue ? cueColor : Theme.accentColor;
                }
                radius: Math.round(6 * root.dp)

                Mixxx.ControlProxy {
                    id: hotcueStatus

                    group: root.group
                    key: "hotcue_" + pad.number + "_status"
                }
                Mixxx.ControlProxy {
                    id: hotcueColor

                    group: root.group
                    key: "hotcue_" + pad.number + "_color"
                }
                Mixxx.ControlProxy {
                    id: hotcueActivate

                    group: root.group
                    key: "hotcue_" + pad.number + "_activate"
                }
                Mixxx.ControlProxy {
                    id: hotcueClear

                    group: root.group
                    key: "hotcue_" + pad.number + "_clear"
                }
                Mixxx.ControlProxy {
                    id: loopActivate

                    group: root.group
                    key: "beatloop_" + root.loopSizes[pad.index] + "_activate"
                }
                Mixxx.ControlProxy {
                    id: loopEnabled

                    group: root.group
                    key: "loop_enabled"
                }

                Text {
                    anchors.centerIn: parent
                    color: pad.active || mouseArea.pressed ? Theme.white : Theme.deckTextColor
                    font.bold: true
                    font.pixelSize: Math.round(Math.min(parent.height * 0.42, parent.width * 0.38))
                    text: pad.isCue ? pad.number : root.loopSizes[pad.index]
                }

                MouseArea {
                    id: mouseArea

                    anchors.fill: parent

                    onPressed: {
                        if (pad.isCue) {
                            hotcueActivate.value = 1;
                        } else {
                            loopActivate.value = 1;
                        }
                    }
                    onReleased: {
                        if (pad.isCue) {
                            hotcueActivate.value = 0;
                        } else {
                            loopActivate.value = 0;
                        }
                    }
                    // Apagar exige segurar, nunca um toque: perder um ponto de
                    // entrada no meio da musica nao pode ser o resultado de
                    // encostar no lugar errado.
                    onPressAndHold: {
                        if (pad.isCue) {
                            hotcueActivate.value = 0;
                            hotcueClear.value = 1;
                            hotcueClear.value = 0;
                        }
                    }
                }
            }
        }
    }
}
