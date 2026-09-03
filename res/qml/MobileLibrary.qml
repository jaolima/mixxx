import "." as Skin
import "Library" as LibraryComponent
import "Theme"
import Mixxx 1.0 as Mixxx
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Lista de faixas para toque.
//
// A tabela do desktop tem doze colunas de largura fixa e linhas de 30 px - boa
// para o mouse e ilegivel na mao. Aqui cada faixa e uma linha alta, com o que
// se decide na hora de escolher a proxima musica: titulo, artista, andamento e
// tonalidade. O resto sai.
//
// Carregar e por toque direto no deck: dois botoes por linha, em vez de
// arrastar - arrastar exige precisao que nao se tem em pe, no escuro.
Item {
    id: root

    required property real dp
    // 52dp por linha: cabe a capa e as duas linhas de texto, e em paisagem
    // ainda mostra meia duzia de faixas. A 64dp apareciam duas - uma lista que
    // so mostra duas faixas nao e uma lista, e um visor.
    property int rowHeight: Math.round(52 * dp)

    // allTracks() entrega o modelo direto. A alternativa, sidebar().tracklist,
    // depende de haver uma fonte selecionada na arvore lateral - que aqui nem
    // existe, entao vinha nula e a lista ficava vazia.
    readonly property var tracklist: sources.allTracks()

    function search(text) {
        if (root.tracklist) {
            root.tracklist.search(text);
        }
    }

    LibraryComponent.SourceTree {
        id: sources
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Math.round(6 * root.dp)

        // ---- busca ----
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(48 * root.dp)
            color: Theme.deckBackgroundColor
            radius: Math.round(8 * root.dp)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Math.round(14 * root.dp)
                anchors.rightMargin: Math.round(14 * root.dp)
                spacing: Math.round(10 * root.dp)

                // Lupa desenhada, nao um caractere: a fonte do Android nao
                // tras U+2315 e o simbolo saia como quadrado vazio.
                Item {
                    Layout.preferredHeight: Math.round(18 * root.dp)
                    Layout.preferredWidth: Math.round(18 * root.dp)

                    Rectangle {
                        border.color: Theme.deckTextColor
                        border.width: Math.max(1, Math.round(1.5 * root.dp))
                        color: "transparent"
                        height: Math.round(13 * root.dp)
                        radius: height / 2
                        width: height
                    }
                    Rectangle {
                        color: Theme.deckTextColor
                        height: Math.max(1, Math.round(1.5 * root.dp))
                        radius: height / 2
                        rotation: 45
                        width: Math.round(7 * root.dp)
                        x: Math.round(11 * root.dp)
                        y: Math.round(13 * root.dp)
                    }
                }
                TextField {
                    id: searchField

                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    background: null
                    color: Theme.white
                    font.pixelSize: Math.round(15 * root.dp)
                    placeholderText: qsTr("Search collection")
                    verticalAlignment: TextInput.AlignVCenter

                    onTextChanged: root.search(text)
                }
                Text {
                    color: Theme.deckTextColor
                    font.pixelSize: Math.round(13 * root.dp)
                    text: qsTr("%1 tracks").arg(trackListView.count)
                }
                // Analise da colecao. Sem ela as faixas ficam sem andamento nem
                // tonalidade - as duas informacoes que fazem a lista servir para
                // escolher a proxima musica.
                MobileButton {
                    Layout.preferredHeight: Math.round(36 * root.dp)
                    Layout.preferredWidth: Math.round(130 * root.dp)
                    checked: Mixxx.Library.analysisActive
                    label: Mixxx.Library.analysisActive
                        ? qsTr("ANALYZING") : qsTr("ANALYZE")

                    onClicked: {
                        if (!Mixxx.Library.analysisActive && root.tracklist) {
                            root.tracklist.analyzeAll();
                        }
                    }
                }
            }
        }

        // ---- lista ----
        ListView {
            id: trackListView

            Layout.fillHeight: true
            Layout.fillWidth: true
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            model: root.tracklist
            // Rolagem com inercia: numa lista de centenas de faixas, arrastar
            // linha a linha e inviavel.
            flickDeceleration: 2000

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: Math.round(6 * root.dp)
            }

            delegate: Rectangle {
                id: row

                required property int index
                required property var track
                required property url cover_art

                color: index % 2 === 0 ? Theme.deckBackgroundColor : "#151515"
                height: root.rowHeight
                width: ListView.view.width

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Math.round(8 * root.dp)
                    anchors.rightMargin: Math.round(8 * root.dp)
                    spacing: Math.round(10 * root.dp)

                    // capa
                    Rectangle {
                        Layout.preferredHeight: root.rowHeight - Math.round(12 * root.dp)
                        Layout.preferredWidth: Layout.preferredHeight
                        color: "#0a0a0a"
                        radius: Math.round(3 * root.dp)

                        Image {
                            anchors.fill: parent
                            asynchronous: true
                            fillMode: Image.PreserveAspectCrop
                            source: row.cover_art
                        }
                    }

                    // titulo e artista
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            color: Theme.white
                            elide: Text.ElideRight
                            font.pixelSize: Math.round(15 * root.dp)
                            text: row.track && row.track.title ? row.track.title : qsTr("(untitled)")
                        }
                        Text {
                            Layout.fillWidth: true
                            color: Theme.deckTextColor
                            elide: Text.ElideRight
                            font.pixelSize: Math.round(12 * root.dp)
                            text: row.track && row.track.artist ? row.track.artist : ""
                        }
                    }

                    // andamento
                    Text {
                        Layout.preferredWidth: Math.round(56 * root.dp)
                        color: Theme.deckTextColor
                        font.family: "monospace"
                        font.pixelSize: Math.round(14 * root.dp)
                        horizontalAlignment: Text.AlignRight
                        text: row.track && row.track.bpm > 0 ? row.track.bpm.toFixed(0) : "--"
                    }

                    // tonalidade, destacada como na etiqueta de uma loja de
                    // discos: e o que se procura primeiro ao mixar em harmonia
                    Rectangle {
                        Layout.preferredHeight: Math.round(26 * root.dp)
                        Layout.preferredWidth: Math.round(44 * root.dp)
                        color: row.track && row.track.keyText ? Theme.accentColor : "transparent"
                        radius: Math.round(3 * root.dp)
                        visible: row.track && row.track.keyText

                        Text {
                            anchors.centerIn: parent
                            color: Theme.white
                            font.bold: true
                            font.pixelSize: Math.round(12 * root.dp)
                            text: row.track ? row.track.keyText : ""
                        }
                    }

                    // carregar direto no deck
                    Repeater {
                        model: [
                            {"deck": "[Channel1]", "label": "1"},
                            {"deck": "[Channel2]", "label": "2"}
                        ]

                        MobileButton {
                            required property var modelData

                            Layout.preferredHeight: Math.round(40 * root.dp)
                            Layout.preferredWidth: Math.round(40 * root.dp)
                            label: modelData.label

                            onClicked: {
                                const player = Mixxx.PlayerManager.getPlayer(modelData.deck);
                                if (player && row.track) {
                                    player.loadTrack(row.track);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
