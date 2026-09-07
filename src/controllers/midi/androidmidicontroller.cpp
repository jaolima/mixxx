#include "controllers/midi/androidmidicontroller.h"

#include <android/log.h>

#include <QtJniTypes>

#include "moc_androidmidicontroller.cpp"
#include "util/time.h"

namespace {
// Kept in step with packaging/android/src/org/mixxx/MidiBridge.java.
constexpr const char* kBridgeClass = "org/mixxx/MidiBridge";
} // namespace

AndroidMidiController::AndroidMidiController(const QString& deviceName, int deviceIndex)
        : MidiController(deviceName),
          m_deviceIndex(deviceIndex) {
    setInputDevice(true);
    setOutputDevice(true);

    // Queued by necessity, not by preference: handleIncoming() runs on the
    // Android MIDI thread, while mapping and script code must run on the
    // controller's own thread.
    connect(this,
            &AndroidMidiController::incomingData,
            this,
            &AndroidMidiController::handleIncomingOnControllerThread,
            Qt::QueuedConnection);
}

AndroidMidiController::~AndroidMidiController() {
    if (isOpen()) {
        close();
    }
}

int AndroidMidiController::open(const QString& resourcePath) {
    if (isOpen()) {
        qWarning() << "Android MIDI device" << getName() << "already open";
        return -1;
    }

    QJniObject context = QNativeInterface::QAndroidApplication::context();
    if (!context.isValid()) {
        qWarning() << "No Android context; cannot open MIDI device";
        return -1;
    }

    // The handle is this object's address, handed back with every callback so
    // the native side knows which controller the bytes belong to.
    m_bridge = QJniObject::callStaticObjectMethod(kBridgeClass,
            "openDevice",
            "(Landroid/content/Context;IJ)Lorg/mixxx/MidiBridge;",
            context.object(),
            static_cast<jint>(m_deviceIndex),
            static_cast<jlong>(reinterpret_cast<quintptr>(this)));
    if (!m_bridge.isValid()) {
        qWarning() << "Failed to open Android MIDI device" << getName();
        return -1;
    }

    // Marked open before the asynchronous open reports back. Android answers on
    // its own thread and Mixxx wants a verdict here and now; blocking for it
    // would stall the controller thread for a device that usually opens without
    // trouble. handleOpened() closes up if it turns out otherwise.
    setOpen(true);
    startEngine();
    applyMapping(resourcePath);
    return 0;
}

int AndroidMidiController::close() {
    if (!isOpen()) {
        return -1;
    }
    if (m_bridge.isValid()) {
        m_bridge.callMethod<void>("close");
        m_bridge = QJniObject();
    }
    // MidiController::close() stops the engine and clears the mapping.
    return MidiController::close();
}

void AndroidMidiController::handleOpened(bool success) {
    if (success) {
        return;
    }
    qWarning() << "Android MIDI device" << getName()
               << "failed to open its ports";
}

void AndroidMidiController::handleIncoming(const QByteArray& data) {
    // Stamped here, on arrival, rather than after the queue: the delay from the
    // hand-off would otherwise be charged to the controller and skew anything
    // that measures timing, such as a jog wheel.
    emit incomingData(data, mixxx::Time::elapsed());
}

void AndroidMidiController::handleIncomingOnControllerThread(
        QByteArray data, mixxx::Duration timestamp) {
    // Android delivers whole MIDI messages, which may be several in one
    // callback. Anything starting with SysEx goes through the byte path; the
    // rest are status/data triples.
    int i = 0;
    while (i < data.size()) {
        const unsigned char status = static_cast<unsigned char>(data.at(i));
        if (status == 0xF0) {
            // Take the SysEx through to its terminator, or to the end of what
            // we were given.
            int end = i;
            while (end < data.size() &&
                    static_cast<unsigned char>(data.at(end)) != 0xF7) {
                ++end;
            }
            if (end < data.size()) {
                ++end; // include the 0xF7
            }
            receive(data.mid(i, end - i), timestamp);
            i = end;
            continue;
        }
        if (status < 0x80) {
            // Running status is not expected from the Android API, and without
            // a status byte there is nothing to dispatch on.
            ++i;
            continue;
        }
        const unsigned char byte1 = (i + 1 < data.size())
                ? static_cast<unsigned char>(data.at(i + 1))
                : 0;
        const unsigned char byte2 = (i + 2 < data.size())
                ? static_cast<unsigned char>(data.at(i + 2))
                : 0;
        receivedShortMessage(status, byte1, byte2, timestamp);
        // Program change and channel pressure carry a single data byte.
        const unsigned char type = status & 0xF0;
        i += (type == 0xC0 || type == 0xD0) ? 2 : 3;
    }
}

void AndroidMidiController::sendShortMsg(unsigned char status,
        unsigned char byte1,
        unsigned char byte2) {
    QByteArray data;
    data.append(static_cast<char>(status));
    data.append(static_cast<char>(byte1));
    data.append(static_cast<char>(byte2));
    sendBytes(data);
}

bool AndroidMidiController::sendBytes(const QByteArray& data) {
    if (!m_bridge.isValid()) {
        return false;
    }
    QJniEnvironment env;
    jbyteArray array = env->NewByteArray(data.size());
    if (array == nullptr) {
        return false;
    }
    env->SetByteArrayRegion(array,
            0,
            data.size(),
            reinterpret_cast<const jbyte*>(data.constData()));
    m_bridge.callMethod<void>("send", "([B)V", array);
    env->DeleteLocalRef(array);
    return true;
}
