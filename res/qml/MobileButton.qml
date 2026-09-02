import "Theme"
import QtQuick

// Botao de toque: retangulo grande, texto legivel e retorno visual imediato.
//
// Nao reusa o Button.qml do desktop porque aquele nasce dimensionado por
// pixels de mouse - o alvo fica pequeno demais para o dedo, e o estado
// pressionado e sutil demais para se notar num set, no escuro.
Rectangle {
    id: root

    property bool checked: false
    property color activeColor: Theme.accentColor
    property string label: ""

    signal clicked

    color: mouseArea.pressed ? root.activeColor
                             : (root.checked ? root.activeColor : Theme.deckBackgroundColor)
    radius: Math.round(height * 0.14)

    // A borda so aparece quando o botao esta ativo: num painel escuro, contorno
    // permanente em tudo vira ruido e nada se destaca.
    border.color: root.checked ? root.activeColor : Theme.deckLineColor
    border.width: root.checked ? 0 : 1

    Behavior on color {
        ColorAnimation {
            duration: 60
        }
    }

    Text {
        anchors.centerIn: parent
        color: (mouseArea.pressed || root.checked) ? Theme.white : Theme.deckTextColor
        font.bold: true
        font.pixelSize: Math.round(Math.min(parent.height * 0.30, parent.width * 0.24))
        text: root.label
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent

        onClicked: root.clicked()
    }
}
