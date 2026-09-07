#pragma once

#include <QList>

#include "controllers/midi/midienumerator.h"

class Controller;

/// Lists the MIDI devices Android reports, so Mixxx can offer them.
///
/// Enumeration happens once at startup, like every other enumerator here, so a
/// controller has to be plugged in before Mixxx is launched to be seen.
class AndroidMidiEnumerator : public MidiEnumerator {
    Q_OBJECT
  public:
    AndroidMidiEnumerator();
    ~AndroidMidiEnumerator() override;

    QList<Controller*> queryDevices() override;

  private:
    QList<Controller*> m_devices;
};
