#include "preferences/dialog/dlgprefquick.h"

#include <QCheckBox>
#include <QFrame>
#include <QGroupBox>
#include <QHBoxLayout>
#include <QPushButton>
#include <QLabel>
#include <QScrollArea>

#include "moc_dlgprefquick.cpp"

namespace {

/// Catalogo de ajustes.
///
/// Escolhidos por mudarem a forma de tocar. O arquivo de configuracao tem mais
/// de seiscentas chaves, e a maioria e estado interno - tamanho de janela,
/// ultima pasta aberta - que nao faz sentido editar aqui.
QList<QuickSetting> buildCatalog() {
    QList<QuickSetting> s;

    // --- Decks ---------------------------------------------------------------
    s.append({QObject::tr("Decks"),
            QObject::tr("Pitch range"),
            QObject::tr("How far the pitch fader can stretch the track. Going "
                        "from 85 to 100 BPM needs about 16%; in house a smaller "
                        "range gives finer steps and makes beatmatching easier."),
            QStringLiteral("bpm tempo speed"),
            QStringLiteral("[Controls]"), QStringLiteral("RateRangePercent"),
            QStringLiteral("8"), false,
            {{QStringLiteral("4"), QObject::tr("±4%  (fine)")},
                    {QStringLiteral("8"), QObject::tr("±8%  (CDJ standard)")},
                    {QStringLiteral("16"), QObject::tr("±16%  (hip hop)")},
                    {QStringLiteral("50"), QObject::tr("±50%")},
                    {QStringLiteral("90"), QObject::tr("±90%")}}});

    s.append({QObject::tr("Decks"),
            QObject::tr("Pitch direction"),
            QObject::tr("On turntables and CDJs, pushing the fader down speeds "
                        "the track up. People who learned on hardware usually "
                        "find the opposite confusing."),
            QString(),
            QStringLiteral("[Controls]"), QStringLiteral("RateDir"),
            QStringLiteral("1"), false,
            {{QStringLiteral("1"), QObject::tr("Down speeds up  (like a turntable)")},
                    {QStringLiteral("0"), QObject::tr("Up speeds up")}}});

    s.append({QObject::tr("Decks"),
            QObject::tr("CUE button behaviour"),
            QObject::tr("Match this to your controller. With a Pioneer unit, "
                        "choosing Pioneer makes the hardware button and the "
                        "on-screen button behave the same way."),
            QStringLiteral("pioneer flx4 ddj"),
            QStringLiteral("[Controls]"), QStringLiteral("CueDefault"),
            QStringLiteral("0"), false,
            {{QStringLiteral("0"), QObject::tr("Mixxx")},
                    {QStringLiteral("1"), QObject::tr("Pioneer")},
                    {QStringLiteral("2"), QObject::tr("Denon")},
                    {QStringLiteral("3"), QObject::tr("Numark")},
                    {QStringLiteral("4"), QObject::tr("Mixxx (no blinking)")},
                    {QStringLiteral("5"), QObject::tr("CUE and play")}}});

    s.append({QObject::tr("Decks"),
            QObject::tr("Quantize (snap to grid)"),
            QObject::tr("Snaps cues and loops to the nearest beat. Helps in "
                        "house, where the grid is reliable. Gets in the way in "
                        "hip hop and reggae: the cue has to land exactly where "
                        "you set it, and those grids are often off."),
            QStringLiteral("scratch grid beat cue loop"),
            QString(), QStringLiteral("quantize"),
            QStringLiteral("1"), true, {}});

    s.append({QObject::tr("Decks"),
            QObject::tr("Keylock (keep the key)"),
            QObject::tr("Holds the musical key when you change tempo. Without "
                        "it the pitch rises with the speed, like vinyl - part of "
                        "the hip hop sound. In house, stretching the BPM far "
                        "without keylock detunes the vocal."),
            QString(),
            QString(), QStringLiteral("keylock"),
            QStringLiteral("0"), true, {}});

    // --- Mixer ---------------------------------------------------------------
    s.append({QObject::tr("Mixer"),
            QObject::tr("Crossfader curve"),
            QObject::tr("The gain is 1 - position^curve. A HIGH curve keeps the "
                        "sound at full level for nearly the whole travel and cuts "
                        "only at the very end, so a tiny movement turns the audio "
                        "on and off - the transformer and crab gesture. With "
                        "curve 1 the signal drops 3 dB after 29% of the travel; "
                        "with 300, after 99.6%."),
            QStringLiteral("scratch transformer crab cut battle"),
            QStringLiteral("[Mixer Profile]"), QStringLiteral("xFaderCurve"),
            QStringLiteral("1"), false,
            {{QStringLiteral("0.6"), QObject::tr("Very long fade")},
                    {QStringLiteral("1"), QObject::tr("Smooth fade  (default)")},
                    {QStringLiteral("10"), QObject::tr("Medium")},
                    {QStringLiteral("100"), QObject::tr("Fast cut")},
                    {QStringLiteral("300"), QObject::tr("Battle mixer  (scratch)")},
                    {QStringLiteral("1000"), QObject::tr("Hard cut")}}});

    s.append({QObject::tr("Mixer"),
            QObject::tr("Crossfader mode"),
            QObject::tr("Constant power keeps the loudness steady across a long "
                        "transition. For fast cutting it only gets in the way."),
            QStringLiteral("scratch cut mix transition"),
            QStringLiteral("[Mixer Profile]"), QStringLiteral("xFaderMode"),
            QStringLiteral("0"), false,
            {{QStringLiteral("0"), QObject::tr("Additive  (for cutting)")},
                    {QStringLiteral("1"), QObject::tr("Constant power  (for mixing)")}}});

    s.append({QObject::tr("Mixer"),
            QObject::tr("Reset EQ on track load"),
            QObject::tr("Returns the three EQ knobs to centre when a new track "
                        "loads, so you don't start the next one with the bass "
                        "still cut from the last."),
            QString(),
            QStringLiteral("[Mixer Profile]"), QStringLiteral("EqAutoReset"),
            QStringLiteral("0"), false, {}});

    s.append({QObject::tr("Mixer"),
            QObject::tr("Normalise volume (ReplayGain)"),
            QObject::tr("Evens out perceived loudness between tracks from "
                        "different sources. Without it a ripped vinyl comes in "
                        "much quieter than a modern release, and you fix it on "
                        "the gain knob in a hurry."),
            QStringLiteral("volume gain loudness"),
            QStringLiteral("[ReplayGain]"), QStringLiteral("ReplayGainEnabled"),
            QStringLiteral("1"), false, {}});

    // --- Analysis ------------------------------------------------------------
    s.append({QObject::tr("Analysis"),
            QObject::tr("Tempo assumption when detecting BPM"),
            QObject::tr("Constant assumes the BPM never drifts and draws an even "
                        "grid - right for music produced to a click. Hip hop and "
                        "reggae are played by people and drift: an even grid "
                        "starts aligned and slides out by the end of the track. "
                        "Only affects NEW analyses."),
            QStringLiteral("beatgrid grade"),
            QStringLiteral("[BPM]"),
            QStringLiteral("BeatDetectionFixedTempoAssumption"),
            QStringLiteral("1"), false,
            {{QStringLiteral("1"), QObject::tr("Constant  (house, techno)")},
                    {QStringLiteral("0"), QObject::tr("Variable  (hip hop, reggae, live)")}}});

    s.append({QObject::tr("Analysis"),
            QObject::tr("Fast analysis"),
            QObject::tr("Analyses only the beginning of each track. Much quicker "
                        "on a big library, but less accurate on music that "
                        "changes tempo."),
            QString(),
            QStringLiteral("[BPM]"), QStringLiteral("FastAnalysisEnabled"),
            QStringLiteral("0"), false, {}});

    // --- Library -------------------------------------------------------------
    s.append({QObject::tr("Library"),
            QObject::tr("Key notation"),
            QObject::tr("Lancelot is the harmonic wheel most DJs use: tracks "
                        "with the same or a neighbouring number fit together. "
                        "Much easier to read mid-set than Am and F#."),
            QStringLiteral("camelot harmonic key tone"),
            QStringLiteral("[Key]"), QStringLiteral("KeyNotation"),
            QStringLiteral("3"), false,
            {{QStringLiteral("4"), QObject::tr("Traditional  (Am, F#)")},
                    {QStringLiteral("3"), QObject::tr("Lancelot  (8A, 11B)")},
                    {QStringLiteral("2"), QObject::tr("OpenKey  (1m, 6d)")},
                    {QStringLiteral("6"), QObject::tr("Lancelot + traditional")}}});

    // --- Waveform ------------------------------------------------------------
    s.append({QObject::tr("Waveform"),
            QObject::tr("End of track warning"),
            QObject::tr("How many seconds before the end the waveform starts "
                        "flashing. With headphones on and noise on the floor, "
                        "this is what stops silence from creeping in."),
            QStringLiteral("alert flash remaining"),
            QStringLiteral("[Waveform]"), QStringLiteral("EndOfTrackWarningTime"),
            QStringLiteral("30"), false,
            {{QStringLiteral("15"), QObject::tr("15 seconds")},
                    {QStringLiteral("30"), QObject::tr("30 seconds  (default)")},
                    {QStringLiteral("45"), QObject::tr("45 seconds")},
                    {QStringLiteral("60"), QObject::tr("1 minute")},
                    {QStringLiteral("0"), QObject::tr("Off")}}});

    s.append({QObject::tr("Waveform"),
            QObject::tr("Sync drawing to the screen (VSync)"),
            QObject::tr("Aligns waveform drawing with the monitor refresh. "
                        "Smoother, but costs CPU - and CPU contention is what "
                        "causes audio dropouts at a low buffer size."),
            QString(),
            QStringLiteral("[Waveform]"), QStringLiteral("VSync"),
            QStringLiteral("0"), false, {}});

    // --- Auto DJ -------------------------------------------------------------
    s.append({QObject::tr("Auto DJ"),
            QObject::tr("Transition length"),
            QObject::tr("How long Auto DJ takes to move from one track to the "
                        "next."),
            QStringLiteral("automatic crossfade"),
            QStringLiteral("[Auto DJ]"), QStringLiteral("Transition"),
            QStringLiteral("10"), false,
            {{QStringLiteral("0"), QObject::tr("Hard cut")},
                    {QStringLiteral("4"), QObject::tr("4 seconds")},
                    {QStringLiteral("10"), QObject::tr("10 seconds  (default)")},
                    {QStringLiteral("20"), QObject::tr("20 seconds")},
                    {QStringLiteral("30"), QObject::tr("30 seconds")}}});

    // --- Recording -----------------------------------------------------------
    s.append({QObject::tr("Recording"),
            QObject::tr("Recording format"),
            QObject::tr("WAV loses nothing but takes about 600 MB per hour; "
                        "FLAC stores the same audio in half the space; MP3 is "
                        "for publishing."),
            QStringLiteral("record set mp3 wav flac"),
            QStringLiteral("[Recording]"), QStringLiteral("Encoding"),
            QStringLiteral("WAV"), false,
            {{QStringLiteral("WAV"), QObject::tr("WAV - lossless, large")},
                    {QStringLiteral("FLAC"), QObject::tr("FLAC - lossless, compressed")},
                    {QStringLiteral("AIFF"), QObject::tr("AIFF - lossless")},
                    {QStringLiteral("MP3"), QObject::tr("MP3 - lossy, small")},
                    {QStringLiteral("OGG"), QObject::tr("OGG - lossy")}}});

    return s;
}

/// Presets por estilo. Sao definidos pela chave do ajuste, e nao pela posicao
/// na lista, para nao quebrarem em silencio quando o catalogo mudar de ordem.
QList<QuickPreset> buildPresets(const QList<QuickSetting>& settings) {
    struct RawPreset {
        QString name;
        QString description;
        QList<QPair<QString, QString>> values; // chave -> valor
    };

    const QList<RawPreset> raw = {
            {QObject::tr("Hip hop / rap / reggae"),
                    QObject::tr("Cue exactly where you set it, fast crossfader "
                                "cut for scratching, wide pitch range, and beat "
                                "detection that tolerates tempo drift."),
                    {{QStringLiteral("quantize"), QStringLiteral("0")},
                            {QStringLiteral("keylock"), QStringLiteral("0")},
                            {QStringLiteral("RateRangePercent"), QStringLiteral("16")},
                            {QStringLiteral("xFaderCurve"), QStringLiteral("300")},
                            {QStringLiteral("xFaderMode"), QStringLiteral("0")},
                            {QStringLiteral("BeatDetectionFixedTempoAssumption"),
                                    QStringLiteral("0")}}},
            {QObject::tr("House / techno"),
                    QObject::tr("Snap to the grid, long crossfader transition "
                                "with steady loudness, finer pitch steps, and "
                                "beat detection assuming a steady tempo."),
                    {{QStringLiteral("quantize"), QStringLiteral("1")},
                            {QStringLiteral("keylock"), QStringLiteral("1")},
                            {QStringLiteral("RateRangePercent"), QStringLiteral("8")},
                            {QStringLiteral("xFaderCurve"), QStringLiteral("1")},
                            {QStringLiteral("xFaderMode"), QStringLiteral("1")},
                            {QStringLiteral("BeatDetectionFixedTempoAssumption"),
                                    QStringLiteral("1")}}},
    };

    QList<QuickPreset> presets;
    for (const RawPreset& r : raw) {
        QuickPreset preset;
        preset.name = r.name;
        preset.description = r.description;
        for (const auto& pair : r.values) {
            for (int i = 0; i < settings.size(); ++i) {
                if (settings.at(i).key == pair.first) {
                    preset.values.insert(i, pair.second);
                    break;
                }
            }
        }
        presets.append(preset);
    }
    return presets;
}

} // anonymous namespace

DlgPrefQuick::DlgPrefQuick(QWidget* pParent, UserSettingsPointer pConfig)
        : DlgPreferencePage(pParent),
          m_pConfig(pConfig),
          m_settings(buildCatalog()),
          m_presets(buildPresets(m_settings)) {
    auto* pOuter = new QVBoxLayout(this);

    auto* pTitle = new QLabel(
            tr("The settings that change how you play, gathered in one place."),
            this);
    pTitle->setWordWrap(true);
    pOuter->addWidget(pTitle);

    m_pSearch = new QLineEdit(this);
    m_pSearch->setPlaceholderText(tr("Search settings..."));
    m_pSearch->setClearButtonEnabled(true);
    connect(m_pSearch,
            &QLineEdit::textChanged,
            this,
            &DlgPrefQuick::slotFilterChanged);
    pOuter->addWidget(m_pSearch);

    // Botoes de estilo: preenchem varios ajustes de uma vez. Nao gravam
    // sozinhos - deixam tudo pendente para o usuario conferir e clicar em
    // Aplicar, igual a qualquer outra mudanca desta tela.
    auto* pPresetBox = new QGroupBox(tr("Apply a style"), this);
    auto* pPresetLayout = new QHBoxLayout(pPresetBox);
    for (int i = 0; i < m_presets.size(); ++i) {
        auto* pButton = new QPushButton(m_presets.at(i).name, pPresetBox);
        pButton->setToolTip(m_presets.at(i).description);
        connect(pButton, &QPushButton::clicked, this, [this, i] {
            slotApplyPreset(i);
        });
        pPresetLayout->addWidget(pButton);
    }
    pOuter->addWidget(pPresetBox);

    m_pCount = new QLabel(this);
    m_pCount->setEnabled(false);
    pOuter->addWidget(m_pCount);

    auto* pScroll = new QScrollArea(this);
    pScroll->setWidgetResizable(true);
    pScroll->setFrameShape(QFrame::NoFrame);
    m_pList = new QWidget(pScroll);
    m_pListLayout = new QVBoxLayout(m_pList);
    m_pListLayout->setAlignment(Qt::AlignTop);
    pScroll->setWidget(m_pList);
    pOuter->addWidget(pScroll, 1);

    rebuild();
}

QUrl DlgPrefQuick::helpUrl() const {
    return QUrl();
}

QStringList DlgPrefQuick::groupsFor(const QuickSetting& setting) const {
    if (!setting.perDeck) {
        return {setting.group};
    }
    QStringList groups;
    for (int deck = 1; deck <= 4; ++deck) {
        groups << QStringLiteral("[Channel%1]").arg(deck);
    }
    return groups;
}

QString DlgPrefQuick::currentValue(
        const QuickSetting& setting, bool* pUsingDefault) const {
    const QStringList groups = groupsFor(setting);
    for (const QString& group : groups) {
        const ConfigKey key(group, setting.key);
        if (m_pConfig->exists(key)) {
            if (pUsingDefault) {
                *pUsingDefault = false;
            }
            return m_pConfig->getValueString(key);
        }
    }
    if (pUsingDefault) {
        *pUsingDefault = true;
    }
    return setting.defaultValue;
}

void DlgPrefQuick::writeValue(const QuickSetting& setting, const QString& value) {
    const QStringList groups = groupsFor(setting);
    for (const QString& group : groups) {
        m_pConfig->setValue(ConfigKey(group, setting.key), value);
    }
}

void DlgPrefQuick::slotFilterChanged(const QString& /*text*/) {
    rebuild();
}

void DlgPrefQuick::rebuild() {
    // Limpa a lista atual. deleteLater e obrigatorio: rebuild() e chamado de
    // dentro de um sinal de um dos proprios widgets (o campo de busca), e
    // destrui-los na hora derrubaria o objeto que ainda esta emitindo.
    QLayoutItem* pItem = nullptr;
    while ((pItem = m_pListLayout->takeAt(0)) != nullptr) {
        if (pItem->widget()) {
            pItem->widget()->deleteLater();
        }
        delete pItem;
    }

    const QString filter = m_pSearch->text().trimmed().toLower();
    int shown = 0;

    for (int i = 0; i < m_settings.size(); ++i) {
        const QuickSetting& setting = m_settings.at(i);

        if (!filter.isEmpty()) {
            // A busca varre tambem os rotulos das escolhas: quem digita
            // "scratch" espera achar a curva do crossfader, e a palavra so
            // aparece ali.
            QString haystack = setting.category + QLatin1Char(' ') +
                    setting.label + QLatin1Char(' ') + setting.help +
                    QLatin1Char(' ') + setting.keywords;
            for (const QuickChoice& choice : setting.choices) {
                haystack += QLatin1Char(' ') + choice.label;
            }
            if (!haystack.toLower().contains(filter)) {
                continue;
            }
        }
        ++shown;

        bool usingDefault = false;
        QString value = currentValue(setting, &usingDefault);
        if (m_pending.contains(i)) {
            value = m_pending.value(i);
            usingDefault = false;
        }

        QString title = setting.category + QStringLiteral(" · ") + setting.label;
        if (usingDefault) {
            title += tr("   (using the default)");
        }
        auto* pBox = new QGroupBox(title, m_pList);
        auto* pBoxLayout = new QVBoxLayout(pBox);

        if (setting.choices.isEmpty()) {
            auto* pCheck = new QCheckBox(tr("Enabled"), pBox);
            pCheck->setChecked(value == QStringLiteral("1"));
            connect(pCheck, &QCheckBox::toggled, this, [this, i](bool on) {
                m_pending.insert(i, on ? QStringLiteral("1") : QStringLiteral("0"));
            });
            pBoxLayout->addWidget(pCheck);
        } else {
            auto* pCombo = new QComboBox(pBox);
            int selected = -1;
            for (int c = 0; c < setting.choices.size(); ++c) {
                const QuickChoice& choice = setting.choices.at(c);
                pCombo->addItem(choice.label, choice.value);
                if (choice.value == value) {
                    selected = c;
                }
            }
            if (selected < 0) {
                // Valor fora da lista (editado a mao ou vindo de outra versao):
                // mostramos como esta em vez de silenciosamente troca-lo.
                pCombo->addItem(tr("%1  (current value)").arg(value), value);
                selected = pCombo->count() - 1;
            }
            pCombo->setCurrentIndex(selected);
            setScrollSafeGuard(pCombo);
            connect(pCombo,
                    QOverload<int>::of(&QComboBox::currentIndexChanged),
                    this,
                    [this, i, pCombo](int index) {
                        m_pending.insert(i, pCombo->itemData(index).toString());
                    });
            pBoxLayout->addWidget(pCombo);
        }

        auto* pHelp = new QLabel(setting.help, pBox);
        pHelp->setWordWrap(true);
        pHelp->setEnabled(false);
        pBoxLayout->addWidget(pHelp);

        m_pListLayout->addWidget(pBox);
    }

    if (shown == 0) {
        m_pListLayout->addWidget(
                new QLabel(tr("Nothing matches that search."), m_pList));
    }
    m_pCount->setText(tr("%n setting(s)", "", shown));
}

void DlgPrefQuick::slotApplyPreset(int presetIndex) {
    if (presetIndex < 0 || presetIndex >= m_presets.size()) {
        return;
    }
    const QuickPreset& preset = m_presets.at(presetIndex);
    for (auto it = preset.values.constBegin(); it != preset.values.constEnd(); ++it) {
        m_pending.insert(it.key(), it.value());
    }
    // Limpa a busca: senao o usuario ve so parte do que acabou de mudar.
    m_pSearch->clear();
    rebuild();
}

void DlgPrefQuick::slotUpdate() {
    m_pending.clear();
    rebuild();
}

void DlgPrefQuick::slotApply() {
    for (auto it = m_pending.constBegin(); it != m_pending.constEnd(); ++it) {
        writeValue(m_settings.at(it.key()), it.value());
    }
    m_pending.clear();
    rebuild();
}

void DlgPrefQuick::slotResetToDefaults() {
    m_pending.clear();
    for (int i = 0; i < m_settings.size(); ++i) {
        m_pending.insert(i, m_settings.at(i).defaultValue);
    }
    rebuild();
}
