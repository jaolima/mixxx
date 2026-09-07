#include "controllers/midi/androidmidienumerator.h"

#include <QJniObject>
#include <QtJniTypes>

#include "controllers/midi/androidmidicontroller.h"
#include "moc_androidmidienumerator.cpp"

namespace {
constexpr const char* kBridgeClass = "org/mixxx/MidiBridge";
} // namespace

AndroidMidiEnumerator::AndroidMidiEnumerator() = default;

AndroidMidiEnumerator::~AndroidMidiEnumerator() {
    qDeleteAll(m_devices);
    m_devices.clear();
}

QList<Controller*> AndroidMidiEnumerator::queryDevices() {
    qDebug() << "Scanning Android MIDI devices:";

    QJniObject context = QNativeInterface::QAndroidApplication::context();
    if (!context.isValid()) {
        qWarning() << "No Android context; cannot list MIDI devices";
        return m_devices;
    }

    QJniObject names = QJniObject::callStaticObjectMethod(kBridgeClass,
            "listDevices",
            "(Landroid/content/Context;)[Ljava/lang/String;",
            context.object());
    if (!names.isValid()) {
        qWarning() << "Could not list Android MIDI devices";
        return m_devices;
    }

    QJniEnvironment env;
    jobjectArray array = names.object<jobjectArray>();
    const jsize count = env->GetArrayLength(array);
    for (jsize i = 0; i < count; ++i) {
        QJniObject name = env->GetObjectArrayElement(array, i);
        const QString deviceName = name.toString();
        // The name is what a MIDI mapping is matched against, so it is worth
        // seeing in the log when a mapping is not picked up.
        qDebug() << " Found MIDI device:" << deviceName;
        m_devices.append(new AndroidMidiController(deviceName, static_cast<int>(i)));
    }
    return m_devices;
}
