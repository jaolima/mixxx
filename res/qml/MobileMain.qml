import "." as Skin
import "Theme"
import Mixxx 1.0 as Mixxx
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Layout de toque, para celular com a controladora ligada.
//
// A premissa que define tudo aqui: a controladora faz o trabalho fino - jog,
// EQ, filtro, pads. A tela cuida do que ela nao tem, e precisa ser operavel em
// pe, no escuro, com uma mao so. Por isso nao e a interface de desktop
// reduzida: e outro conjunto, com menos coisas e alvos grandes.
//
// A referencia de tamanho e o minimo de 48dp da propria Google para alvo de
// toque, convertido pela densidade real da tela.
Item {
    id: root

    // Densidade da tela: o Qt entrega pixels, e o que importa para o dedo e o
    // tamanho fisico. Sem isto os botoes encolhem em telas mais densas.
    readonly property real dp: Math.max(1, Screen.pixelDensity * 25.4 / 160)
    // 48dp e o minimo da Google para alvo de toque. Ficamos nele: em paisagem a
    // tela tem pouca ALTURA, e cada pixel gasto em botao sai da forma de onda,
    // que e o que se olha o tempo todo enquanto mixa.
    readonly property int touchTarget: Math.round(48 * dp)
    readonly property int gap: Math.round(6 * dp)
    // A faixa de transporte tem altura fixa e modesta; o resto da tela sobra
    // para as ondas.
    readonly property int deckStripHeight: Math.round(88 * dp)

    property bool libraryOpen: false

    Rectangle {
        anchors.fill: parent
        color: Theme.backgroundColor
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.gap
        spacing: root.gap

        // ---- barra superior --------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: root.touchTarget
            spacing: root.gap

            MobileButton {
                Layout.preferredHeight: root.touchTarget
                Layout.preferredWidth: Math.round(130 * root.dp)
                checked: root.libraryOpen
                label: qsTr("BIBLIOTECA")
                onClicked: root.libraryOpen = !root.libraryOpen
            }
            Item {
                Layout.fillWidth: true
            }
            Text {
                color: Theme.deckTextColor
                font.pixelSize: Math.round(15 * root.dp)
                text: "MIXXX"
            }
        }

        // ---- formas de onda, uma por deck ------------------------------
        // Ficam no topo porque sao o que se olha durante a mixagem; os botoes
        // ficam embaixo, onde o polegar alcanca com o aparelho na mao.
        ColumnLayout {
            Layout.fillHeight: true
            Layout.fillWidth: true
            // Sem um minimo explicito o layout espreme as ondas ate viraem um
            // risco: elas nao tem altura propria a exigir, e todo o resto tem.
            Layout.minimumHeight: Math.round(150 * root.dp)
            spacing: root.gap
            visible: !root.libraryOpen

            Repeater {
                model: ["[Channel1]", "[Channel2]"]

                Rectangle {
                    required property string modelData

                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    Layout.minimumHeight: Math.round(70 * root.dp)
                    border.color: Theme.deckBackgroundColor
                    border.width: 1
                    color: "#0a0a0a"

                    Skin.WaveformDisplay {
                        anchors.fill: parent
                        anchors.margins: 1
                        group: parent.modelData
                    }
                }
            }
        }

        // ---- biblioteca, quando aberta ---------------------------------
        // Ocupa o lugar das formas de onda em vez de flutuar por cima: numa
        // tela desse tamanho, um painel sobreposto esconde justamente o que se
        // quer conferir antes de carregar a faixa.
        Skin.Library {
            Layout.fillHeight: true
            Layout.fillWidth: true
            visible: root.libraryOpen
        }

        // ---- transporte, um bloco por deck -----------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: root.deckStripHeight
            spacing: root.gap

            Repeater {
                model: ["[Channel1]", "[Channel2]"]

                MobileDeckStrip {
                    required property string modelData

                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    dp: root.dp
                    gap: root.gap
                    group: modelData
                }
            }
        }

        // ---- crossfader ------------------------------------------------
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.touchTarget

            Mixxx.ControlProxy {
                id: crossfaderControl

                group: "[Master]"
                key: "crossfader"
            }

            Rectangle {
                anchors.centerIn: parent
                color: Theme.deckBackgroundColor
                height: Math.round(10 * root.dp)
                radius: height / 2
                width: parent.width
            }
            // Alca larga: no escuro, com o aparelho na mao, uma alca fina de
            // desktop e impossivel de pegar sem olhar.
            Rectangle {
                id: xfaderHandle

                color: Theme.white
                height: root.touchTarget
                radius: Math.round(6 * root.dp)
                width: Math.round(64 * root.dp)
                x: (parent.width - width) * (crossfaderControl.value + 1) / 2
                y: (parent.height - height) / 2

                MouseArea {
                    anchors.fill: parent
                    drag.axis: Drag.XAxis
                    drag.maximumX: xfaderHandle.parent.width - xfaderHandle.width
                    drag.minimumX: 0
                    drag.target: xfaderHandle

                    onPositionChanged: {
                        if (drag.active) {
                            const range = xfaderHandle.parent.width - xfaderHandle.width;
                            crossfaderControl.value = range > 0
                                ? (xfaderHandle.x / range) * 2 - 1
                                : 0;
                        }
                    }
                    onDoubleClicked: {
                        crossfaderControl.value = 0;
                    }
                }
            }
        }
    }
}
