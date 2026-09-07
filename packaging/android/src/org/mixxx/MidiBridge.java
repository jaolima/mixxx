package org.mixxx;

import android.content.Context;
import android.media.midi.MidiDevice;
import android.media.midi.MidiDeviceInfo;
import android.media.midi.MidiInputPort;
import android.media.midi.MidiManager;
import android.media.midi.MidiOutputPort;
import android.media.midi.MidiReceiver;
import android.os.Bundle;
import android.os.Handler;
import android.os.HandlerThread;
import android.util.Log;

import java.io.IOException;

/**
 * Bridges Android's MidiManager to Mixxx's MIDI stack.
 *
 * Mixxx already contains the whole MIDI layer - message parsing, mapping,
 * scripting, output handlers. What Android lacks is a transport: PortMidi has
 * no Android backend, so nothing ever delivers bytes. This class is that
 * transport, and nothing more.
 *
 * Talking to the USB device directly with libusb was the alternative. It is not
 * possible without a fight: the kernel's snd-usbmidi driver already owns the
 * MIDI interface, and taking it away would both break MIDI for every other app
 * and put the device's audio interfaces - which Mixxx uses for master and
 * headphones - at risk on the same connection.
 */
public class MidiBridge {
    private static final String TAG = "MixxxMidi";

    /** Called from the MIDI thread with the raw bytes as they arrive. */
    private static native void onMidiReceived(long handle, byte[] data, int offset, int count);

    /** Called once the asynchronous open finishes, successfully or not. */
    private static native void onDeviceOpened(long handle, boolean success);

    // Every callback from Android runs on this thread, never on the UI thread.
    //
    // Handing MidiManager the main looper is the obvious thing to do and it
    // deadlocks: the caller blocks waiting for the open to finish while the
    // callback that would finish it is queued behind that very block. A private
    // thread keeps the two apart.
    private static HandlerThread sThread;
    private static Handler sHandler;

    private final long mHandle;
    private MidiDevice mDevice;
    private MidiOutputPort mOutputPort;
    private MidiInputPort mInputPort;

    private MidiBridge(long handle) {
        mHandle = handle;
    }

    private static synchronized Handler handler() {
        if (sHandler == null) {
            sThread = new HandlerThread("MixxxMidi");
            sThread.start();
            sHandler = new Handler(sThread.getLooper());
        }
        return sHandler;
    }

    private static MidiManager midiManager(Context context) {
        return (MidiManager) context.getSystemService(Context.MIDI_SERVICE);
    }

    /**
     * Names of the attached MIDI devices, in the order openDevice() expects.
     *
     * Mixxx matches a mapping file by the controller name, so this string is
     * what decides whether the DDJ-FLX4 mapping is found.
     */
    public static String[] listDevices(Context context) {
        MidiManager manager = midiManager(context);
        if (manager == null) {
            Log.w(TAG, "No MIDI service on this device");
            return new String[0];
        }
        MidiDeviceInfo[] infos = manager.getDevices();
        String[] names = new String[infos.length];
        for (int i = 0; i < infos.length; i++) {
            names[i] = displayName(infos[i]);
        }
        return names;
    }

    private static String displayName(MidiDeviceInfo info) {
        Bundle properties = info.getProperties();
        String name = properties.getString(MidiDeviceInfo.PROPERTY_NAME);
        if (name != null && !name.isEmpty()) {
            return name;
        }
        // Fall back to manufacturer + product, which is what the USB descriptor
        // carries when the driver did not compose a name for us.
        String manufacturer = properties.getString(MidiDeviceInfo.PROPERTY_MANUFACTURER);
        String product = properties.getString(MidiDeviceInfo.PROPERTY_PRODUCT);
        if (manufacturer != null && product != null) {
            return manufacturer + " " + product;
        }
        return product != null ? product : "MIDI device";
    }

    /**
     * Starts opening device {@code index}. Returns null when the index is gone,
     * otherwise a bridge whose onDeviceOpened() fires later on the MIDI thread.
     */
    public static MidiBridge openDevice(Context context, int index, long handle) {
        MidiManager manager = midiManager(context);
        if (manager == null) {
            return null;
        }
        MidiDeviceInfo[] infos = manager.getDevices();
        if (index < 0 || index >= infos.length) {
            Log.w(TAG, "No MIDI device at index " + index);
            return null;
        }

        final MidiBridge bridge = new MidiBridge(handle);
        manager.openDevice(infos[index], new MidiManager.OnDeviceOpenedListener() {
            @Override
            public void onDeviceOpened(MidiDevice device) {
                bridge.finishOpen(device);
            }
        }, handler());
        return bridge;
    }

    private void finishOpen(MidiDevice device) {
        if (device == null) {
            Log.e(TAG, "Failed to open MIDI device");
            onDeviceOpened(mHandle, false);
            return;
        }
        mDevice = device;
        try {
            MidiDeviceInfo info = device.getInfo();
            if (info.getOutputPortCount() > 0) {
                mOutputPort = device.openOutputPort(0);
                if (mOutputPort != null) {
                    mOutputPort.connect(mReceiver);
                }
            }
            if (info.getInputPortCount() > 0) {
                mInputPort = device.openInputPort(0);
            }
        } catch (Exception e) {
            Log.e(TAG, "Error opening MIDI ports: " + e.toString());
            onDeviceOpened(mHandle, false);
            return;
        }
        // The output port is the one Mixxx reads from; without it there is
        // nothing to listen to and the controller is useless.
        onDeviceOpened(mHandle, mOutputPort != null);
    }

    private final MidiReceiver mReceiver = new MidiReceiver() {
        @Override
        public void onSend(byte[] data, int offset, int count, long timestamp) {
            onMidiReceived(mHandle, data, offset, count);
        }
    };

    /** Sends bytes to the controller, for LEDs and displays. */
    public void send(byte[] data) {
        MidiInputPort port = mInputPort;
        if (port == null) {
            return;
        }
        try {
            port.send(data, 0, data.length);
        } catch (IOException e) {
            Log.w(TAG, "Failed to send MIDI: " + e.toString());
        }
    }

    public void close() {
        try {
            if (mOutputPort != null) {
                mOutputPort.disconnect(mReceiver);
                mOutputPort.close();
                mOutputPort = null;
            }
            if (mInputPort != null) {
                mInputPort.close();
                mInputPort = null;
            }
            if (mDevice != null) {
                mDevice.close();
                mDevice = null;
            }
        } catch (IOException e) {
            Log.w(TAG, "Error closing MIDI device: " + e.toString());
        }
    }
}
