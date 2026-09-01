#pragma once

#include <QComboBox>
#include <QLineEdit>
#include <QList>
#include <QString>
#include <QVBoxLayout>
#include <QWidget>

#include "preferences/dialog/dlgpreferencepage.h"
#include "preferences/usersettings.h"

/// Uma escolha possivel para um ajuste: o valor gravado no arquivo e o texto
/// que o usuario le.
struct QuickChoice {
    QString value;
    QString label;
};

/// Um ajuste exposto nesta pagina.
///
/// `group` vazio com `perDeck` verdadeiro significa que o ajuste vale para os
/// quatro decks ([Channel1] .. [Channel4]) e e gravado nos quatro.
struct QuickSetting {
    QString category;
    QString label;
    QString help;
    /// Palavras que a busca deve encontrar mas que nao aparecem em nenhum texto
    /// visivel (ex.: "camelot" para a notacao de tonalidade).
    QString keywords;
    QString group;
    QString key;
    QString defaultValue;
    bool perDeck = false;
    /// Vazio => caixa de marcar (liga/desliga). Preenchido => lista de escolhas.
    QList<QuickChoice> choices;
};

/// Pagina "Essencial" das Preferencias.
///
/// As Preferencias do Mixxx tem dezesseis paginas, e os ajustes que mais pesam
/// na hora de tocar ficam espalhados: curva do crossfader em Mixer, alcance do
/// pitch em Decks, deteccao de BPM em Beats. Trocar de estilo musical obriga a
/// passear por todas. Esta pagina reune esses ajustes com busca, cada um com a
/// explicacao do efeito pratico ao lado, e marca quais ainda estao no padrao de
/// fabrica - coisa que as outras paginas nao distinguem.
class DlgPrefQuick : public DlgPreferencePage {
    Q_OBJECT
  public:
    DlgPrefQuick(QWidget* pParent, UserSettingsPointer pConfig);
    ~DlgPrefQuick() override = default;

    QUrl helpUrl() const override;

  public slots:
    void slotUpdate() override;
    void slotApply() override;
    void slotResetToDefaults() override;

  private slots:
    void slotFilterChanged(const QString& text);

  private:
    /// (Re)desenha a lista de ajustes aplicando o filtro de busca.
    void rebuild();
    /// Le o valor em vigor, ou o padrao de fabrica quando a chave nao existe.
    QString currentValue(const QuickSetting& setting, bool* pUsingDefault) const;
    void writeValue(const QuickSetting& setting, const QString& value);
    QStringList groupsFor(const QuickSetting& setting) const;

    UserSettingsPointer m_pConfig;
    QList<QuickSetting> m_settings;
    /// Alteracoes ainda nao aplicadas, indexadas pela posicao em m_settings.
    QHash<int, QString> m_pending;

    QLineEdit* m_pSearch;
    QWidget* m_pList;
    QVBoxLayout* m_pListLayout;
    QLabel* m_pCount;
};
