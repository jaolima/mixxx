import "Theme"
import Mixxx 1.0 as Mixxx
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Shapes

// Prato de um deck: a capa girando dentro de um anel que mostra a volta.
//
// Nao serve para arrastar a musica - a controladora tem o prato de verdade, com
// peso e superficie, e nenhum vidro compete com isso. Serve para ver: a capa
// girando diz num relance se o deck anda e a que velocidade, e o anel diz onde
// a faixa esta dentro da volta atual.
//
// Por isso divide lugar com a forma de onda em vez de somar-se a ela: quem esta
// encaixando dois tempos olha a onda, quem so acompanha olha o prato.
Item {
    id: root

    required property string group
    required property real dp

    readonly property var deckPlayer: Mixxx.PlayerManager.getPlayer(group)
    readonly property var deckTrack: deckPlayer ? deckPlayer.currentTrack : null
    readonly property real diameter: Math.min(width, height)

    Mixxx.ControlProxy {
        id: positionControl

        group: root.group
        key: "playposition"
    }
    Mixxx.ControlProxy {
        id: playControl

        group: root.group
        key: "play"
    }

    readonly property real elapsedSeconds: deckTrack && deckTrack.duration > 0
        ? deckTrack.duration * positionControl.value
        : 0
    // Uma volta a cada 1,8 s, o giro de um disco a 33 1/3 RPM. O numero nao e
    // decorativo: e ele que faz o movimento ser lido como um toca-discos em vez
    // de uma animacao qualquer.
    readonly property real spin: (elapsedSeconds / 1.8) * 360

    Rectangle {
        id: platter

        anchors.centerIn: parent
        border.color: Theme.deckLineColor
        border.width: Math.max(1, Math.round(2 * root.dp))
        color: "#101010"
        height: root.diameter
        radius: height / 2
        width: root.diameter

        Item {
            id: spinning

            anchors.centerIn: parent
            height: parent.height - Math.round(20 * root.dp)
            rotation: root.spin
            width: height

            Rectangle {
                anchors.fill: parent
                color: "#181818"
                radius: width / 2
            }

            Rectangle {
                id: coverMask

                anchors.fill: parent
                color: "black"
                radius: width / 2
                visible: false
            }
            // A capa e quadrada, e um canto girando entrega que aquilo nao e um
            // disco - por isso o recorte redondo. O recorte vai como camada da
            // propria imagem: a mascara aplicada de fora, num item separado,
            // carregava sem erro e nao desenhava nada.
            Image {
                id: cover

                anchors.fill: parent
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                source: root.deckTrack ? root.deckTrack.coverArtUrl : ""

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: coverMask
                }
            }

            // Marca de referencia, como o ponto de um disco: sem ela a rotacao
            // de uma capa quase uniforme nao se percebe.
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                color: Theme.white
                height: parent.height * 0.14
                radius: width / 2
                width: Math.max(2, Math.round(4 * root.dp))
                y: Math.round(4 * root.dp)
            }
        }

        // Anel: quanto falta para fechar a volta.
        Shape {
            anchors.fill: parent
            antialiasing: true

            ShapePath {
                capStyle: ShapePath.RoundCap
                fillColor: "transparent"
                strokeColor: playControl.value > 0 ? Theme.accentColor : Theme.deckTextColor
                strokeWidth: Math.max(2, Math.round(5 * root.dp))

                PathAngleArc {
                    centerX: platter.width / 2
                    centerY: platter.height / 2
                    radiusX: platter.width / 2 - Math.round(6 * root.dp)
                    radiusY: platter.height / 2 - Math.round(6 * root.dp)
                    startAngle: -90
                    sweepAngle: root.spin % 360
                }
            }
        }
    }
}
