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

    // Ao fechar a biblioteca, forcar a coleta de lixo do QML.
    //
    // Cada linha da lista cria um objeto de faixa do lado do JavaScript, e esse
    // objeto segura a faixa viva na cache do Mixxx. E ao sair da cache que a
    // faixa e gravada no banco - entao, enquanto o coletor nao passa, o que a
    // analise descobriu fica so na memoria. Como o coletor roda quando quer, as
    // primeiras faixas da lista podiam nunca ser gravadas: no aparelho, as de
    // identificador 1 a 12 eram analisadas em toda execucao e nenhuma chegava
    // ao banco.
    // Depois da destruicao, e nao junto com ela: o Loader ainda esta desmontando
    // as linhas quando este sinal chega, e um gc() aqui passa cedo demais - a
    // primeira tentativa nao gravou nada por isso.
    onLibraryOpenChanged: {
        if (!libraryOpen) {
            Qt.callLater(gc);
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.backgroundColor
    }

    Component {
        id: libraryComponent

        MobileLibrary {
            dp: root.dp
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.gap
        spacing: root.gap

        // ---- barra superior --------------------------------------------
        RowLayout {
            // fillHeight explicito: num ColumnLayout, um layout aninhado assume
            // fillHeight true por padrao (um Item comum assume false). Sem isto
            // a barra superior e a de transporte disputam a altura com o miolo
            // e o esmagam - foi o que espremeu as ondas e a biblioteca.
            Layout.fillHeight: false
            Layout.fillWidth: true
            Layout.preferredHeight: root.touchTarget
            spacing: root.gap

            MobileButton {
                Layout.preferredHeight: root.touchTarget
                Layout.preferredWidth: Math.round(130 * root.dp)
                checked: root.libraryOpen
                label: qsTr("LIBRARY")
                onClicked: root.libraryOpen = !root.libraryOpen
            }
            Item {
                Layout.fillWidth: true
            }

            // Barramento do fone. Sem estes dois o fone e uma caixa preta: nao
            // da para saber se o silencio vem do volume, da mistura ou de nao
            // haver deck em monitoracao. Sao os controles que uma controladora
            // traz em botao fisico e que a tela precisa ter quando ela nao
            // esta ligada.
            Mixxx.ControlProxy {
                id: headGainControl

                group: "[Master]"
                key: "headGain"
            }
            Mixxx.ControlProxy {
                id: headMixControl

                group: "[Master]"
                key: "headMix"
            }

            Text {
                color: Theme.deckTextColor
                font.pixelSize: Math.round(12 * root.dp)
                text: qsTr("CUE")
            }
            Skin.MobileSlider {
                Layout.preferredHeight: root.touchTarget
                Layout.preferredWidth: Math.round(150 * root.dp)
                dp: root.dp
                from: -1
                to: 1
                value: headMixControl.value

                onMoved: (v) => {
                    headMixControl.value = v;
                }
            }
            Text {
                color: Theme.deckTextColor
                font.pixelSize: Math.round(12 * root.dp)
                text: qsTr("MAIN")
            }
            Skin.MobileSlider {
                Layout.preferredHeight: root.touchTarget
                Layout.preferredWidth: Math.round(150 * root.dp)
                dp: root.dp
                from: 0
                to: 4
                value: headGainControl.value

                onMoved: (v) => {
                    headGainControl.value = v;
                }
            }
            Text {
                color: Theme.deckTextColor
                font.pixelSize: Math.round(12 * root.dp)
                text: qsTr("VOL")
            }

            Item {
                Layout.preferredWidth: Math.round(10 * root.dp)
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
        //
        // Lista propria, nao a tabela do desktop: aquela tem doze colunas e
        // linhas de 30 px, boas para o mouse e ilegiveis na mao.
        //
        // Carregada sob demanda, e nao apenas escondida: cada linha instancia
        // uma capa e segura a faixa que mostra, e num aparelho isso nao deve
        // ficar de pe enquanto se olha para as formas de onda.
        Loader {
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.minimumHeight: Math.round(150 * root.dp)
            active: root.libraryOpen
            sourceComponent: libraryComponent
            visible: root.libraryOpen
        }

        // ---- transporte, um bloco por deck -----------------------------
        RowLayout {
            Layout.fillHeight: false
            Layout.fillWidth: true
            Layout.preferredHeight: root.deckStripHeight
            spacing: root.gap
            // Some junto com as ondas: escolher a proxima faixa e uma tarefa de
            // tela cheia, e PLAY, CUE, SYNC e o crossfader existem em hardware
            // logo abaixo do celular. Ceder esses 88dp a lista vale mais.
            visible: !root.libraryOpen

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
            visible: !root.libraryOpen

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
