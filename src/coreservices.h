#pragma once

#include <memory>

#include "preferences/settingsmanager.h"
#include "util/timer.h"

class QApplication;
class CmdlineArgs;
class KeyboardEventFilter;
class EffectsManager;
class EngineMixer;
class SoundManager;
class PlayerManager;
class RecordingManager;
#ifdef __BROADCAST__
class BroadcastManager;
#endif
class ControllerManager;
class VinylControlManager;
class TrackCollectionManager;
class Library;
class SkinControls;
class ControlPushButton;
struct LibraryScanResultSummary;

namespace mixxx {

class ControlIndicatorTimer;
class DbConnectionPool;
class ScreensaverManager;

class CoreServices : public QObject {
    Q_OBJECT

  public:
    CoreServices(const CmdlineArgs& args, QApplication* pApp);
    ~CoreServices();

    /// The secondary long run which should be called after displaying the start up screen
    void initialize(QApplication* pApp);

    std::shared_ptr<KeyboardEventFilter> getKeyboardEventFilter() const {
        return m_pKeyboardEventFilter;
    }

    std::shared_ptr<ConfigObject<ConfigValueKbd>> getKeyboardConfig() const;

    std::shared_ptr<mixxx::ControlIndicatorTimer> getControlIndicatorTimer() const {
        return m_pControlIndicatorTimer;
    }

    std::shared_ptr<SoundManager> getSoundManager() const {
        return m_pSoundManager;
    }

    std::shared_ptr<PlayerManager> getPlayerManager() const {
        return m_pPlayerManager;
    }

    std::shared_ptr<RecordingManager> getRecordingManager() const {
        return m_pRecordingManager;
    }

#ifdef __BROADCAST__
    std::shared_ptr<BroadcastManager> getBroadcastManager() const {
        return m_pBroadcastManager;
    }
#endif

    std::shared_ptr<ControllerManager> getControllerManager() const {
        return m_pControllerManager;
    }

    std::shared_ptr<VinylControlManager> getVinylControlManager() const {
        return m_pVCManager;
    }

    std::shared_ptr<EffectsManager> getEffectsManager() const {
        return m_pEffectsManager;
    }

    std::shared_ptr<Library> getLibrary() const {
        return m_pLibrary;
    }

    std::shared_ptr<TrackCollectionManager> getTrackCollectionManager() const {
        return m_pTrackCollectionManager;
    }

    std::shared_ptr<SettingsManager> getSettingsManager() const {
        return m_pSettingsManager;
    }

    UserSettingsPointer getSettings() const {
        return m_pSettingsManager->settings();
    }

    std::shared_ptr<ScreensaverManager> getScreensaverManager() const {
        return m_pScreensaverManager;
    }

    std::shared_ptr<QDialog> makeDlgPreferences() const;

  signals:
    void initializationProgressUpdate(int progress, const QString& serviceName);
    void libraryScanSummary(const LibraryScanResultSummary& result);

  private:
    bool initializeDatabase();
    void initializeKeyboard();
    void initializeSettings();
    void initializeScreensaverManager();
    void initializeLogging();
#ifdef MIXXX_USE_QML
    void initializeQMLSingletons();
#endif

    /// Tear down CoreServices that were previously initialized by `initialize()`.
    void finalize();

    /// Grava no banco o que so estaria gravado ao encerrar.
    ///
    /// No Android o sistema mata o processo sem encerramento limpo, entao o
    /// caminho normal - gravar a faixa quando ela sai da cache - nunca chega a
    /// correr para o que ainda estiver em uso. Medido no aparelho: das 275
    /// faixas analisadas, as 12 que a lista mantinha montadas eram reanalisadas
    /// a cada abertura porque nenhuma chegava ao banco.
    void flushPersistentState();

    std::shared_ptr<SettingsManager> m_pSettingsManager;
    std::shared_ptr<mixxx::ControlIndicatorTimer> m_pControlIndicatorTimer;
    std::shared_ptr<EffectsManager> m_pEffectsManager;
    std::shared_ptr<EngineMixer> m_pEngine;
    std::shared_ptr<SoundManager> m_pSoundManager;
    std::shared_ptr<PlayerManager> m_pPlayerManager;
    std::shared_ptr<RecordingManager> m_pRecordingManager;
#ifdef __BROADCAST__
    std::shared_ptr<BroadcastManager> m_pBroadcastManager;
#endif
    std::shared_ptr<ControllerManager> m_pControllerManager;

    std::shared_ptr<VinylControlManager> m_pVCManager;

    std::shared_ptr<DbConnectionPool> m_pDbConnectionPool;
    std::shared_ptr<TrackCollectionManager> m_pTrackCollectionManager;
    std::shared_ptr<Library> m_pLibrary;

    std::shared_ptr<KeyboardEventFilter> m_pKeyboardEventFilter;

    std::shared_ptr<mixxx::ScreensaverManager> m_pScreensaverManager;

    std::unique_ptr<SkinControls> m_pSkinControls;
    std::unique_ptr<ControlPushButton> m_pTouchShift;

    Timer m_runtime_timer;
    const CmdlineArgs& m_cmdlineArgs;
    bool m_isInitialized;
    /// Guardada para ser cortada no inicio de finalize(). As conexoes de um
    /// QObject so caem no destrutor, que roda depois - sem cortar aqui, um
    /// sinal de mudanca de estado chegando durante o encerramento entraria num
    /// flush com os gerenciadores ja destruidos.
    QMetaObject::Connection m_appStateConnection;
    /// Serve para gravar uma vez so por ida a segundo plano: a mudanca de
    /// estado chega mais de uma vez seguida, e o segundo flush percorreria a
    /// cache inteira sem nada para gravar.
    bool m_appWasActive;
};

} // namespace mixxx
