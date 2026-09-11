#pragma once

#include <QByteArray>
#include <QJniObject>
#include <QString>
#include <cstdint>
#include <optional>

#include "controllers/midi/midicontroller.h"

/// A MIDI controller reached through Android's MidiManager.
///
/// Mixxx's MIDI stack already builds on Android - message parsing, mapping,
/// scripting and output handlers are all in the unconditional source list. Only
/// the transport was missing, because PortMidi has no Android backend and
/// nothing ever delivered bytes. This class is that transport.
///
/// It is event driven rather than polled: Android hands over bytes on its own
/// thread. Hss1394Controller is the in-tree precedent for that shape.
///
/// Talking to the device with libusb was the alternative, and it is blocked:
/// the kernel's snd-usbmidi driver already owns the MIDI interface, and taking
/// it away would break MIDI for every other application while risking the
/// device's audio interfaces, which Mixxx uses for main and headphones over the
/// very same connection.
class AndroidMidiController : public MidiController {
    Q_OBJECT
  public:
    AndroidMidiController(const QString& deviceName, int deviceIndex);
    ~AndroidMidiController() override;

    /// Called from the Android MIDI thread as bytes arrive.
    void handleIncoming(const QByteArray& data);
    /// Called from the Android MIDI thread once the asynchronous open settles.
    void handleOpened(bool success);

    PhysicalTransportProtocol getPhysicalTransportProtocol() const override {
        return PhysicalTransportProtocol::USB;
    }
    QString getVendorString() const override {
        return QString();
    }
    QString getProductString() const override {
        return getName();
    }
    QString getSerialNumber() const override {
        return QString();
    }
    // Android's MIDI API does not hand out the USB identifiers, and Mixxx only
    // uses them to match HID and Bulk devices, so leaving them empty costs
    // nothing here: MIDI mappings are matched by device name.
    std::optional<uint16_t> getVendorId() const override {
        return std::nullopt;
    }
    std::optional<uint16_t> getProductId() const override {
        return std::nullopt;
    }
    std::optional<uint8_t> getUsbInterfaceNumber() const override {
        return std::nullopt;
    }

  signals:
    /// Bridges the Android thread to this object's own thread. Emitting a
    /// signal is what makes the hand-off safe: a direct call would run mapping
    /// and script code on a thread that owns neither.
    void incomingData(QByteArray data, mixxx::Duration timestamp);

  private slots:
    void handleIncomingOnControllerThread(QByteArray data, mixxx::Duration timestamp);

  private:
    int open(const QString& resourcePath) override;
    int close() override;
    void sendShortMsg(unsigned char status,
            unsigned char byte1,
            unsigned char byte2) override;
    bool sendBytes(const QByteArray& data) override;

    int m_deviceIndex;
    QJniObject m_bridge;
    /// Bytes left over from the previous callback.
    ///
    /// Android hands over whatever arrived, and a message may be split across
    /// two calls - the API promises nothing about boundaries. Dispatching an
    /// incomplete message reads zeros for the missing bytes and, worse, leaves
    /// the rest of the buffer misaligned.
    QByteArray m_pending;
};
