import "Theme"
import QtQuick

// Slider horizontal para o dedo.
//
// Nao usa o Slider do QtQuick.Controls porque a alca dele nasce do tamanho de
// mouse: no vidro, no escuro, com o aparelho na mao, ela e pequena demais para
// pegar sem olhar. Aqui a alca tem largura de alvo de toque e a trilha mostra
// o percurso preenchido, que e o que se le de relance.
Item {
    id: root

    required property real dp
    property real from: 0
    property real to: 1
    property real value: 0

    // Emitido durante o arrasto, com o valor ja convertido para a faixa real.
    // Quem usa escreve no controle; o valor de volta chega pela ligacao normal.
    signal moved(real value)

    readonly property real span: to - from
    readonly property real ratio: span !== 0
        ? Math.max(0, Math.min(1, (value - from) / span))
        : 0

    implicitHeight: Math.round(48 * dp)
    implicitWidth: Math.round(150 * dp)

    Rectangle {
        id: track

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.deckBackgroundColor
        height: Math.round(8 * root.dp)
        radius: height / 2

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.accentColor
            height: parent.height
            radius: height / 2
            width: parent.width * root.ratio
        }
    }

    Rectangle {
        id: handle

        color: Theme.white
        height: Math.round(34 * root.dp)
        radius: Math.round(5 * root.dp)
        width: Math.round(22 * root.dp)
        x: (root.width - width) * root.ratio
        y: (root.height - height) / 2
    }

    MouseArea {
        anchors.fill: parent

        function valueAt(mouseX) {
            const usable = root.width - handle.width;
            if (usable <= 0) {
                return root.from;
            }
            const pos = Math.max(0, Math.min(usable, mouseX - handle.width / 2));
            return root.from + (pos / usable) * root.span;
        }

        // Tocar em qualquer ponto ja leva a alca ate ali, em vez de exigir que
        // o dedo a encontre primeiro.
        onPositionChanged: (mouse) => {
            root.moved(valueAt(mouse.x));
        }
        onPressed: (mouse) => {
            root.moved(valueAt(mouse.x));
        }
    }
}
