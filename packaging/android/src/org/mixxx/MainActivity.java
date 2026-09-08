package org.mixxx;

import android.os.Build;
import android.os.Bundle;
import android.view.WindowManager;
import android.window.OnBackInvokedDispatcher;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.core.view.WindowInsetsControllerCompat;
import org.qtproject.qt.android.QtActivityBase;

public class MainActivity extends QtActivityBase {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Disable drawing over cutout - isn't working
        WindowManager.LayoutParams lp = this.getWindow().getAttributes();
        lp.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_NEVER;

        // Disable system and navigation bar to prevent accidental back or app switch
        WindowInsetsControllerCompat windowInsetsController =
            WindowCompat.getInsetsController(getWindow(), getWindow().getDecorView());
        windowInsetsController.setSystemBarsBehavior(
            WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
        windowInsetsController.hide(WindowInsetsCompat.Type.navigationBars());

        // From Android 13 the system asks for back through this dispatcher, and
        // from target SDK 35 it stops calling onBackPressed() altogether - this
        // project targets 36, so the override below is dead on the devices we
        // ship to. Registering here is what actually runs.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            getOnBackInvokedDispatcher().registerOnBackInvokedCallback(
                OnBackInvokedDispatcher.PRIORITY_DEFAULT,
                () -> moveTaskToBack(true));
        }
    }

    /// Kept for Android 12 and older, where the dispatcher above does not
    /// exist. The minimum supported level here is 28.
    @Override
    public void onBackPressed() {
        // Deliberately not calling super: finishing the activity destroys the
        // window, and that tears down Qt's event loop together with the
        // PlayerManager. Each deck's destructor unloads its track, so a single
        // stray press empties both decks - measured on the device, with the
        // process still alive afterwards.
        //
        // This is also why handling it in QML cannot work: there is no close
        // event to intercept, and the key never reaches QML because the
        // activity consumes it here first.
        //
        // Moving the task to the back is what a media application should do
        // anyway: it leaves the screen and keeps playing.
        moveTaskToBack(true);
    }
}
