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
    // para as ondas. Encolheu de 88dp quando o titulo saiu dela para o
    // cabecalho: a altura tinha sido dimensionada para duas linhas e, com uma
    // so, os botoes cresciam e comiam a forma de onda.
    readonly property int deckStripHeight: Math.round(56 * dp)

    property bool libraryOpen: false
    // Duas visoes para o mesmo miolo, porque servem a momentos diferentes:
    // encaixar dois tempos se faz olhando a onda, acompanhar o que ja esta
    // tocando se faz olhando o prato. Nao cabem juntas nesta tela sem que as
    // duas fiquem pequenas demais para o que servem.
    property bool jogView: false
    // Os pads entram e saem sob demanda: eles disputam altura com a forma de
    // onda, e quem esta encaixando dois tempos precisa da onda inteira.
    property bool padsOpen: false
    property string padMode: "cue"

    /// Pedido de abrir a configuracao. Quem trata e o main.qml, que e dono do
    /// popup; daqui so parte o pedido.
    signal settingsRequested

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

    // Um proxy por deck e por direcao, em vez de trocar a chave de um so: mudar
    // a chave em tempo de execucao obriga o proxy a reconectar, e o valor
    // escrito em seguida cairia no controle antigo.
    Mixxx.ControlProxy {
        id: zoomInDeck1

        group: "[Channel1]"
        key: "waveform_zoom_down"
    }
    Mixxx.ControlProxy {
        id: zoomInDeck2

        group: "[Channel2]"
        key: "waveform_zoom_down"
    }
    Mixxx.ControlProxy {
        id: zoomOutDeck1

        group: "[Channel1]"
        key: "waveform_zoom_up"
    }
    Mixxx.ControlProxy {
        id: zoomOutDeck2

        group: "[Channel2]"
        key: "waveform_zoom_up"
    }

    // O botao BROWSE da controladora.
    //
    // Girar ja e o gesto de procurar a proxima faixa, entao ele abre a
    // biblioteca por conta propria e, com ela aberta, percorre a lista. Sem
    // isso era preciso largar a controladora e tocar na tela so para comecar a
    // procurar.
    //
    // O controle e um encoder criado com bIgnoreNops falso (librarycontrol.cpp),
    // por isso avisa a cada giro mesmo repetindo o valor - um encoder girado
    // sempre para o mesmo lado manda sempre o mesmo delta. E na interface QML o
    // Mixxx nao liga este controle a nada, entao ele esta livre.
    Mixxx.ControlProxy {
        id: browseKnob

        group: "[Library]"
        key: "MoveVertical"

        onValueChanged: {
            if (!root.libraryOpen) {
                root.libraryOpen = true;
                return;
            }
            if (libraryLoader.item) {
                libraryLoader.item.moveSelection(value > 0 ? 1 : -1);
            }
        }
    }

    // Os botoes LOAD da controladora.
    //
    // No Mixxx eles chamam slotLoadSelectedTrackToGroup, que pede a faixa
    // selecionada ao widget de biblioteca do computador. Na interface QML esse
    // widget nao existe, a funcao desiste na primeira linha e o botao nao fazia
    // nada - por isso apertar LOAD no aparelho nao carregava.
    //
    // Aqui a selecao e a da propria lista, a mesma que o BROWSE percorre.
    // Um por deck, declarados a mao: um Repeater so aceita Item como delegate,
    // e um ControlProxy nao e - com ele, os dois nunca chegavam a existir e o
    // botao nao fazia nada. O aviso estava no registro:
    // "QML Component: Delegate must be of Item type".
    Mixxx.ControlProxy {
        group: "[Channel1]"
        key: "LoadSelectedTrack"

        onValueChanged: {
            if (value > 0 && libraryLoader.item) {
                libraryLoader.item.loadSelectedInto("[Channel1]");
            }
        }
    }
    Mixxx.ControlProxy {
        group: "[Channel2]"
        key: "LoadSelectedTrack"

        onValueChanged: {
            if (value > 0 && libraryLoader.item) {
                libraryLoader.item.loadSelectedInto("[Channel2]");
            }
        }
    }

    // Botao de acao: o controle e do tipo que age na subida, entao o valor sobe
    // e volta.
    function pressZoom(proxyA, proxyB) {
        proxyA.value = 1;
        proxyB.value = 1;
        proxyA.value = 0;
        proxyB.value = 0;
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
                Layout.preferredWidth: Math.round(96 * root.dp)
                checked: root.libraryOpen
                label: qsTr("LIB")
                onClicked: root.libraryOpen = !root.libraryOpen
            }
            MobileButton {
                Layout.preferredHeight: root.touchTarget
                Layout.preferredWidth: Math.round(86 * root.dp)
                label: qsTr("SET")
                onClicked: root.settingsRequested()
            }
            MobileButton {
                Layout.preferredHeight: root.touchTarget
                Layout.preferredWidth: Math.round(92 * root.dp)
                checked: root.jogView
                label: root.jogView ? qsTr("JOG") : qsTr("WAVE")
                onClicked: root.jogView = !root.jogView
            }

            // Aproximar e afastar a onda. No computador isso e a roda do mouse,
            // que no aparelho nao existe - e sem isso a vista fica presa num
            // zoom so, servindo ou para procurar o trecho ou para encaixar o
            // tempo, nunca para os dois.
            //
            // Os dois decks recebem o comando: com a sincronizacao de zoom
            // ligada o segundo e redundante, e sem ela seria justamente o que
            // faltava para as duas ondas continuarem comparaveis.
            MobileButton {
                Layout.preferredHeight: root.touchTarget
                Layout.preferredWidth: Math.round(88 * root.dp)
                checked: root.padsOpen
                label: root.padsOpen && root.padMode === "loop" ? qsTr("LOOP") : qsTr("PADS")
                // Um toque abre nos pontos de entrada; com os pads ja abertos,
                // alterna para os loops e depois fecha. Um botao so, porque a
                // barra nao tem largura para tres.
                onClicked: {
                    if (!root.padsOpen) {
                        root.padsOpen = true;
                        root.padMode = "cue";
                    } else if (root.padMode === "cue") {
                        root.padMode = "loop";
                    } else {
                        root.padsOpen = false;
                    }
                }
            }
            MobileButton {
                Layout.preferredHeight: root.touchTarget
                Layout.preferredWidth: Math.round(54 * root.dp)
                label: "−"
                visible: !root.jogView
                onClicked: root.pressZoom(zoomOutDeck1, zoomOutDeck2)
            }
            MobileButton {
                Layout.preferredHeight: root.touchTarget
                Layout.preferredWidth: Math.round(54 * root.dp)
                label: "+"
                visible: !root.jogView
                onClicked: root.pressZoom(zoomInDeck1, zoomInDeck2)
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
                Layout.fillWidth: true
                Layout.maximumWidth: Math.round(150 * root.dp)
                Layout.minimumWidth: Math.round(70 * root.dp)
                Layout.preferredHeight: root.touchTarget
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
                Layout.fillWidth: true
                Layout.maximumWidth: Math.round(150 * root.dp)
                Layout.minimumWidth: Math.round(70 * root.dp)
                Layout.preferredHeight: root.touchTarget
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
            visible: !root.libraryOpen && !root.jogView

            Repeater {
                model: ["[Channel1]", "[Channel2]"]

                // Cabecalho e onda como um bloco so: o que se le sobre a faixa
                // fica junto do desenho dela, e nao numa fileira separada onde
                // seria preciso conferir de qual deck e cada coisa.
                ColumnLayout {
                    required property string modelData

                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    Layout.minimumHeight: Math.round(70 * root.dp)
                    spacing: Math.round(3 * root.dp)

                    Skin.MobileDeckHeader {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.round(46 * root.dp)
                        dp: root.dp
                        group: parent.modelData
                    }

                    Rectangle {
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        Layout.minimumHeight: Math.round(50 * root.dp)
                        border.color: Theme.deckBackgroundColor
                        border.width: 1
                        color: "#0a0a0a"
                        visible: !root.jogView

                        Skin.WaveformDisplay {
                            anchors.fill: parent
                            anchors.margins: 1
                            group: parent.parent.modelData
                        }
                    }
                }
            }
        }

        // ---- pratos, quando escolhidos ---------------------------------
        RowLayout {
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.minimumHeight: Math.round(120 * root.dp)
            spacing: root.gap
            visible: root.jogView && !root.libraryOpen

            Repeater {
                model: ["[Channel1]", "[Channel2]"]

                // Cabecalho junto do prato pelo mesmo motivo de estar junto da
                // onda: o que se le sobre a faixa fica ao lado do desenho dela,
                // sem ter de conferir de qual deck e cada coisa.
                ColumnLayout {
                    required property string modelData

                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    spacing: Math.round(3 * root.dp)

                    Skin.MobileDeckHeader {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.round(46 * root.dp)
                        dp: root.dp
                        group: parent.modelData
                    }
                    Skin.MobileJog {
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        dp: root.dp
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
            id: libraryLoader

            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.minimumHeight: Math.round(150 * root.dp)
            active: root.libraryOpen
            sourceComponent: libraryComponent
            visible: root.libraryOpen
        }

        // ---- pads, quando abertos --------------------------------------
        // Acima do transporte porque a mao ja esta ali; e um por deck, lado a
        // lado, na mesma ordem dos decks acima.
        RowLayout {
            Layout.fillHeight: false
            Layout.fillWidth: true
            Layout.preferredHeight: root.deckStripHeight
            spacing: root.gap
            visible: root.padsOpen && !root.libraryOpen

            Repeater {
                model: ["[Channel1]", "[Channel2]"]

                Skin.MobilePads {
                    required property string modelData

                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    dp: root.dp
                    group: modelData
                    mode: root.padMode
                }
            }
        }

        // ---- transporte, um bloco por deck -----------------------------
        RowLayout {
            Layout.fillHeight: false
            Layout.fillWidth: true
            Layout.preferredHeight: root.deckStripHeight
            spacing: root.gap
            // Some junto com as ondas: escolher a proxima faixa e uma tarefa de
            // tela cheia, e PLAY, CUE, SYNC e o crossfader existem em hardware
            // logo abaixo do celular. Ceder essa altura a lista vale mais.
            //
            // Da lugar aos pads pelo mesmo motivo: somados, os dois espremiam a
            // forma de onda ate virar um risco, e a onda e o que se olha para
            // encaixar o tempo. Com a controladora ligada o transporte esta na
            // mao de qualquer modo.
            visible: !root.libraryOpen && !root.padsOpen

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
