package org.mixxx;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.os.Build;
import android.os.IBinder;
import android.util.Log;

/**
 * Keeps Mixxx alive while it is not on screen.
 *
 * Without this the process is merely "cached" the moment the activity leaves
 * the foreground, and Android kills it within seconds - measured on the device:
 * "Process org.mixxx has died: cch CRE". Everything loaded goes with it, which
 * during a set means the music stops.
 *
 * A foreground service with an ongoing notification is what tells the system
 * this process is doing something the user can hear. It is also the contract
 * Android expects from any app that plays audio.
 */
public class PlaybackService extends Service {
    private static final String TAG = "MixxxService";
    private static final String CHANNEL_ID = "mixxx_playback";
    private static final int NOTIFICATION_ID = 1;

    public static void start(Context context) {
        Intent intent = new Intent(context, PlaybackService.class);
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent);
            } else {
                context.startService(intent);
            }
        } catch (Exception e) {
            // Never take the application down over this: without the service
            // Mixxx still runs, it just becomes killable in the background.
            Log.w(TAG, "Could not start playback service: " + e.toString());
        }
    }

    public static void stop(Context context) {
        try {
            context.stopService(new Intent(context, PlaybackService.class));
        } catch (Exception e) {
            Log.w(TAG, "Could not stop playback service: " + e.toString());
        }
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        try {
            startForeground(NOTIFICATION_ID, buildNotification());
        } catch (Exception e) {
            Log.w(TAG, "Could not enter foreground: " + e.toString());
            stopSelf();
            return START_NOT_STICKY;
        }
        // Not sticky: if the system does tear us down, restarting an empty
        // Mixxx behind the user's back would be worse than staying gone.
        return START_NOT_STICKY;
    }

    private Notification buildNotification() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                    CHANNEL_ID, "Playback", NotificationManager.IMPORTANCE_LOW);
            channel.setDescription("Keeps Mixxx running while it is not on screen");
            channel.setShowBadge(false);
            NotificationManager manager = getSystemService(NotificationManager.class);
            if (manager != null) {
                manager.createNotificationChannel(channel);
            }
        }

        // Tapping the notification returns to the mixer rather than starting a
        // second copy of it.
        Intent open = new Intent(this, MainActivity.class);
        open.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags |= PendingIntent.FLAG_IMMUTABLE;
        }
        PendingIntent contentIntent = PendingIntent.getActivity(this, 0, open, flags);

        Notification.Builder builder = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                ? new Notification.Builder(this, CHANNEL_ID)
                : new Notification.Builder(this);
        return builder
                .setContentTitle("Mixxx")
                .setContentText("Session running")
                .setSmallIcon(android.R.drawable.ic_media_play)
                .setContentIntent(contentIntent)
                .setOngoing(true)
                .build();
    }

    @Override
    public void onDestroy() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(Service.STOP_FOREGROUND_REMOVE);
        } else {
            stopForeground(true);
        }
        super.onDestroy();
    }
}
