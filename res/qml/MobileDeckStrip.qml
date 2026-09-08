import "Theme"
import Mixxx 1.0 as Mixxx
import QtQuick
import QtQuick.Layouts

// O transporte de um deck no layout de toque.
//
// Traz PLAY, CUE, PFL e SYNC. EQ, filtro, pads e jog ficam de fora de
// proposito - a controladora faz tudo isso melhor do que o vidro, e cada botao
// a mais aqui encolhe os que importam.
//
// O PFL entra porque nao tem substituto: e por ele que a proxima faixa toca no
// fone antes de ir para o ar, e sem ele o canal do fone recebe silencio.
//
// Titulo, andamento e tonalidade nao estao aqui: ficam no cabecalho, junto da
// forma de onda a que se referem.
Item {
    id: root

    required property string group
    required property real dp
    required property int gap

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
        id: pflControl

        group: root.group
        key: "pfl"
    }

    RowLayout {
        anchors.fill: parent
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

            // CUE responde ao apertar e ao soltar, como no hardware: segurar
            // toca a partir do ponto, soltar volta para ele.
            onPressed: cueControl.value = 1
            onReleased: cueControl.value = 0
        }
        MobileButton {
            Layout.fillHeight: true
            Layout.preferredWidth: Math.round(90 * root.dp)
            checked: pflControl.value > 0
            label: qsTr("PFL")

            onClicked: {
                pflControl.value = pflControl.value > 0 ? 0 : 1;
            }
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
