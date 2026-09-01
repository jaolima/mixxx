#!/usr/bin/env python3
"""
Presets de configuracao do Mixxx por estilo musical - Windows, Linux e macOS.

Hip hop e house querem ajustes opostos, espalhados por telas diferentes das
Preferencias. Este script troca o conjunto todo de uma vez e mostra, antes de
aplicar, exatamente o que muda.

Uso:
    python mixxx_preset.py                 # abre a janela de selecao
    python mixxx_preset.py --status        # so imprime a config atual
    python mixxx_preset.py hiphop          # aplica direto, sem janela
    python mixxx_preset.py house --no-launch

IMPORTANTE: o Mixxx mantem estas opcoes em memoria e reescreve o mixxx.cfg
inteiro quando fecha. Por isso o script SEMPRE fecha o Mixxx antes de gravar -
editar com ele aberto faz a alteracao ser desfeita no fechamento seguinte.

Requer apenas a biblioteca padrao do Python 3.9+ (tkinter para a janela).
"""

import argparse
import os
import platform
import shutil
import subprocess
import sys
import time
from pathlib import Path

# --- Localizacao dos arquivos, por plataforma --------------------------------


def settings_dir():
    """Pasta de configuracao do Mixxx.

    Linux usa ~/.mixxx e nao as pastas XDG - ver o comentario em
    src/util/cmdlineargs.cpp e MIXXX_SETTINGS_PATH em CMakeLists.txt.
    """
    system = platform.system()
    if system == "Windows":
        base = os.environ.get("LOCALAPPDATA") or (Path.home() / "AppData/Local")
        return Path(base) / "Mixxx"
    if system == "Darwin":
        return Path.home() / "Library" / "Application Support" / "Mixxx"
    return Path.home() / ".mixxx"


def find_mixxx_exe():
    """Procura o executavel: primeiro o build deste repo, depois o PATH."""
    root = Path(__file__).resolve().parent.parent
    nomes = ["mixxx.exe", "mixxx"] if platform.system() == "Windows" else ["mixxx"]
    for nome in nomes:
        candidato = root / "build" / nome
        if candidato.exists():
            return candidato
    for nome in nomes:
        achado = shutil.which(nome)
        if achado:
            return Path(achado)
    return None


CFG_PATH = settings_dir() / "mixxx.cfg"


# --- Definicao dos ajustes ---------------------------------------------------
# Uma unica tabela descreve tudo: como aplicar, como exibir e por que existe.
# A janela comparativa e gerada a partir daqui, entao nada sai de sincronia.

PRESETS = {
    "hiphop": "Hip hop / rap / reggae / funk",
    "house": "House / techno / eletronica",
}

# "padrao" e o valor de fabrica do Mixxx, usado quando a chave ainda nao existe
# no arquivo. Nao da para deduzi-lo de um dos presets: o padrao do keylock_engine,
# por exemplo, nao coincide com nenhum dos dois.
AJUSTES = [
    {
        "rotulo": "Quantize (decks)",
        "escopo": "decks",  # aplica em [Channel1] .. [Channel4]
        "chave": "quantize",
        "valores": {"hiphop": "0", "house": "1"},
        "padrao": "1",
        "legivel": {"0": "desligado", "1": "ligado"},
        "porque": "a grade e imprecisa em hip hop/reggae, entao o cue deve cair "
                  "onde voce marcou; em house a grade e confiavel e travar ajuda",
    },
    {
        "rotulo": "Keylock",
        "escopo": "decks",
        "chave": "keylock",
        "valores": {"hiphop": "0", "house": "1"},
        "padrao": "0",
        "legivel": {"0": "desligado", "1": "ligado"},
        "porque": "sem keylock o tom sobe junto com o andamento, como em vinil - "
                  "estetica do hip hop; em house se mantem o tom ao esticar o BPM",
    },
    {
        "rotulo": "Alcance do pitch",
        "escopo": "[Controls]",
        "chave": "RateRangePercent",
        # kDefaultRateRangePercent = 8, em src/preferences/dialog/dlgprefdeck.cpp
        "valores": {"hiphop": "16", "house": "8"},
        "padrao": "8",
        "legivel": {"16": "+-16%", "8": "+-8%"},
        "porque": "sair de 85 para 100 BPM exige ~16%; house pede passo mais fino",
    },
    {
        "rotulo": "Tempo na analise",
        "escopo": "[BPM]",
        "chave": "BeatDetectionFixedTempoAssumption",
        # padrao true, em src/preferences/beatdetectionsettings.h
        "valores": {"hiphop": "0", "house": "1"},
        "padrao": "1",
        "legivel": {"0": "variavel", "1": "constante"},
        "porque": "hip hop e reggae sao tocados por gente e oscilam; house e feito "
                  "em DAW no clique. So vale para analises NOVAS",
    },
    {
        "rotulo": "Curva do crossfader",
        "escopo": "[Mixer Profile]",
        "chave": "xFaderCurve",
        # kTransformDefault = 1.0, em src/engine/enginexfader.cpp
        # A curva vai de 0.6 a 1000. Em 300 o som so cai depois de 99,6% do curso.
        "valores": {"hiphop": "300", "house": "1"},
        "padrao": "1",
        "legivel": {"300": "corte rapido", "1": "fade suave"},
        "porque": "com curva alta o som fica cheio quase todo o curso e corta so na "
                  "ponta - e o gesto do transformer e do crab; em house se quer o "
                  "contrario, transicao longa",
    },
    {
        "rotulo": "Modo do crossfader",
        "escopo": "[Mixer Profile]",
        "chave": "xFaderMode",
        # MIXXX_XFADER_ADDITIVE = 0.0, em src/engine/enginexfader.h
        "valores": {"hiphop": "0", "house": "1"},
        "padrao": "0",
        "legivel": {"0": "aditivo", "1": "potencia constante"},
        "porque": "potencia constante mantem o volume estavel ao longo de uma "
                  "transicao longa; para cortar rapido ela so atrapalha",
    },
    {
        "rotulo": "BPM do relogio interno",
        "escopo": "[InternalClock]",
        "chave": "bpm",
        # kDefaultBpm = 124.0, em src/engine/sync/internalclock.cpp
        "valores": {"hiphop": "90", "house": "124"},
        "padrao": "124",
        "legivel": {"90": "90", "124": "124"},
        "porque": "ponto de partida tipico de cada estilo",
    },
    {
        "rotulo": "Prato (jog wheel)",
        # Opcao do mapeamento da FLX4. O grupo e montado pelo Mixxx como
        # [ControllerSettings_<nome do device>_<caminho do mapeamento>], com
        # %RESOURCE_PATH no lugar da pasta res/ - por isso a chave nao quebra se
        # o projeto mudar de lugar. Ver src/controllers/legacycontrollermapping.cpp.
        "escopo": "[ControllerSettings_DDJ-FLX4_%RESOURCE_PATH"
                  "controllers/Pioneer-DDJ-FLX4.midi.xml]",
        "chave": "vinyl_mode",
        "valores": {"hiphop": "true", "house": "false"},
        "padrao": "true",
        "legivel": {"true": "vinil (scratch)", "false": "CD (pitch bend)"},
        "porque": "no hip hop o prato agarra o audio para scratch; em house ele "
                  "so adianta/atrasa a musica sem parar a reproducao",
    },
    {
        "rotulo": "Motor do keylock",
        "escopo": "[App]",
        # Igual nos dois presets de proposito. RubberBand e melhor que SoundTouch
        # e so custa CPU com o keylock ligado - rebaixa-lo no preset de hip hop
        # (onde o keylock fica desligado) seria perda sem ganho alto.
        # defaultKeylockEngine() em src/engine/enginebuffer.h ja devolve
        # RubberBandFaster quando o Mixxx e compilado com RubberBand, como o nosso.
        "chave": "keylock_engine",
        "valores": {"hiphop": "1", "house": "1"},
        "padrao": "1",
        "legivel": {"0": "SoundTouch", "1": "RubberBand"},
        "porque": "RubberBand tem qualidade melhor e so atua com o keylock ligado",
    },
]


# --- Leitura e escrita do mixxx.cfg ------------------------------------------
# Formato: linha "[Secao]" seguida de linhas "chave valor" (o primeiro espaco separa).


def ler_cfg(path):
    ordem, dados, atual = [], {}, None
    for linha in path.read_text(encoding="utf-8", errors="replace").splitlines():
        t = linha.strip()
        if t.startswith("[") and t.endswith("]"):
            atual = t
            if atual not in dados:
                dados[atual] = {}
                ordem.append(atual)
        elif t and atual:
            chave, _, valor = t.partition(" ")
            dados[atual][chave] = valor
    return ordem, dados


def gravar_cfg(path, ordem, dados):
    linhas = []
    for secao in ordem:
        linhas.append("")
        linhas.append(secao)
        for chave, valor in dados[secao].items():
            # Sem rstrip: chaves de valor vazio sao gravadas pelo Mixxx como
            # "Chave " (com o espaco separador). Aparar esse espaco mudaria a
            # linha para algo que o parser pode nao ler como par chave/valor.
            linhas.append("{} {}".format(chave, valor))
    path.write_text("\n".join(linhas) + "\n", encoding="utf-8")


def secoes_do_ajuste(ajuste):
    if ajuste["escopo"] == "decks":
        return ["[Channel{}]".format(n) for n in range(1, 5)]
    return [ajuste["escopo"]]


def valor_atual(dados, ajuste):
    """Valor em vigor, ou None se a chave ainda nao existe (usando o padrao)."""
    for secao in secoes_do_ajuste(ajuste):
        if secao in dados and ajuste["chave"] in dados[secao]:
            return dados[secao][ajuste["chave"]]
    return None


def valor_efetivo(dados, ajuste):
    """O que o Mixxx realmente usa: o do arquivo, ou o padrao se a chave falta."""
    valor = valor_atual(dados, ajuste)
    return ajuste["padrao"] if valor is None else valor


def texto_valor(ajuste, valor, ausente=False):
    texto = ajuste["legivel"].get(valor, valor)
    return "{} (padrao)".format(texto) if ausente else texto


def preset_ativo(dados):
    """Compara pelo valor efetivo: uma chave ausente conta como o padrao dela,
    senao um arquivo recem-criado nunca casaria com preset nenhum."""
    for nome in PRESETS:
        if all(valor_efetivo(dados, a) == a["valores"][nome] for a in AJUSTES):
            return nome
    return None


def aplicar(nome_preset, dados, ordem):
    for ajuste in AJUSTES:
        valor = ajuste["valores"][nome_preset]
        for secao in secoes_do_ajuste(ajuste):
            if secao not in dados:
                dados[secao] = {}
                ordem.append(secao)
            dados[secao][ajuste["chave"]] = valor


# --- Processo do Mixxx (multiplataforma) -------------------------------------


def mixxx_rodando():
    try:
        if platform.system() == "Windows":
            saida = subprocess.run(
                ["tasklist", "/FI", "IMAGENAME eq mixxx.exe", "/NH"],
                capture_output=True, text=True, timeout=20).stdout
            return "mixxx.exe" in saida.lower()
        return subprocess.run(["pgrep", "-x", "mixxx"],
                              capture_output=True, timeout=20).returncode == 0
    except Exception:
        return False


def fechar_mixxx(espera=30):
    """Pede o fechamento gracioso e espera. True se fechou (ou nem estava aberto)."""
    if not mixxx_rodando():
        return True
    try:
        if platform.system() == "Windows":
            # sem /F: envia WM_CLOSE, o Mixxx salva e sai normalmente
            subprocess.run(["taskkill", "/IM", "mixxx.exe"],
                           capture_output=True, timeout=20)
        else:
            subprocess.run(["pkill", "-TERM", "-x", "mixxx"],
                           capture_output=True, timeout=20)
    except Exception:
        return False
    for _ in range(espera):
        time.sleep(1)
        if not mixxx_rodando():
            return True
    return False


def abrir_mixxx():
    exe = find_mixxx_exe()
    if not exe:
        print("Executavel do Mixxx nao encontrado - abra manualmente.")
        return False
    subprocess.Popen([str(exe)], cwd=str(exe.parent))
    return True


# --- Aplicacao ---------------------------------------------------------------


def trocar_preset(nome, abrir=True, log=print):
    if not CFG_PATH.exists():
        raise SystemExit("mixxx.cfg nao encontrado em {}".format(CFG_PATH))

    if mixxx_rodando():
        log("Fechando o Mixxx (ele reescreve o cfg ao sair)...")
        if not fechar_mixxx():
            raise SystemExit(
                "O Mixxx nao fechou - pode haver um dialogo aberto.\n"
                "Feche-o manualmente e tente de novo.")
        log("  fechado.")

    shutil.copy2(CFG_PATH, CFG_PATH.with_suffix(".cfg.bak-preset"))
    ordem, dados = ler_cfg(CFG_PATH)
    aplicar(nome, dados, ordem)
    gravar_cfg(CFG_PATH, ordem, dados)

    log("")
    log("Preset aplicado: {}".format(PRESETS[nome]))
    for ajuste in AJUSTES:
        log("  {:<24} {}".format(
            ajuste["rotulo"] + ":", texto_valor(ajuste, ajuste["valores"][nome])))
    log("")
    log("'Tempo na analise' vale so para analises novas; faixas ja analisadas")
    log("mantem a grade atual ate serem reanalisadas.")

    if abrir:
        log("")
        log("Abrindo o Mixxx...")
        abrir_mixxx()


def imprimir_status():
    if not CFG_PATH.exists():
        raise SystemExit("mixxx.cfg nao encontrado em {}".format(CFG_PATH))
    _, dados = ler_cfg(CFG_PATH)
    ativo = preset_ativo(dados)

    print("\n  Configuracao atual  ({})".format(CFG_PATH))
    print("  " + "-" * 58)
    for ajuste in AJUSTES:
        ausente = valor_atual(dados, ajuste) is None
        print("  {:<24} {}".format(
            ajuste["rotulo"] + ":",
            texto_valor(ajuste, valor_efetivo(dados, ajuste), ausente)))
    print()
    if ativo:
        print("  => preset ativo: {}".format(ativo))
    else:
        print("  => configuracao mista (nao corresponde a um preset inteiro)")
    print()


# --- Janela de selecao -------------------------------------------------------


def abrir_janela():
    try:
        import tkinter as tk
        from tkinter import messagebox, ttk
    except ImportError:
        print("tkinter nao esta disponivel neste Python.")
        print("No Debian/Ubuntu: sudo apt install python3-tk")
        print("Use o modo texto: python mixxx_preset.py hiphop")
        return 1

    if not CFG_PATH.exists():
        print("mixxx.cfg nao encontrado em {}".format(CFG_PATH))
        return 1

    _, dados = ler_cfg(CFG_PATH)
    ativo = preset_ativo(dados)

    janela = tk.Tk()
    janela.title("Presets do Mixxx")
    janela.minsize(720, 460)

    def trazer_para_frente():
        """Sem isto a janela nasce atras do editor/terminal e passa despercebida.

        O -topmost e ligado e desligado logo em seguida: so o suficiente para
        vir ao topo, sem ficar presa sobre as outras janelas do usuario.
        """
        janela.update_idletasks()
        largura, altura = max(janela.winfo_width(), 720), max(janela.winfo_height(), 460)
        x = (janela.winfo_screenwidth() - largura) // 2
        y = (janela.winfo_screenheight() - altura) // 3
        janela.geometry("{}x{}+{}+{}".format(largura, altura, max(x, 0), max(y, 0)))
        janela.deiconify()
        janela.lift()
        janela.attributes("-topmost", True)
        janela.after(400, lambda: janela.attributes("-topmost", False))
        try:
            janela.focus_force()
        except tk.TclError:
            pass  # alguns gerenciadores de janela no Linux recusam o foco forcado

    topo = ttk.Frame(janela, padding=(14, 12, 14, 6))
    topo.pack(fill="x")
    ttk.Label(topo, text="Qual estilo voce vai tocar?",
              font=("", 13, "bold")).pack(anchor="w")
    atual_txt = ("Preset ativo: {}".format(PRESETS[ativo]) if ativo
                 else "Configuracao atual mista (nao bate com nenhum preset)")
    ttk.Label(topo, text=atual_txt, foreground="#555").pack(anchor="w", pady=(2, 0))

    escolha = tk.StringVar(value=ativo or "hiphop")

    linha = ttk.Frame(janela, padding=(14, 6))
    linha.pack(fill="x")
    for nome, descricao in PRESETS.items():
        ttk.Radiobutton(linha, text=descricao, value=nome,
                        variable=escolha).pack(side="left", padx=(0, 24))

    corpo = ttk.Frame(janela, padding=(14, 6))
    corpo.pack(fill="both", expand=True)

    colunas = ("ajuste", "agora", "depois")
    tabela = ttk.Treeview(corpo, columns=colunas, show="headings", height=7)
    for col, titulo, largura in (("ajuste", "Ajuste", 190),
                                 ("agora", "Agora", 130),
                                 ("depois", "Depois", 130)):
        tabela.heading(col, text=titulo)
        tabela.column(col, width=largura, anchor="w")
    tabela.pack(fill="x")
    tabela.tag_configure("muda", background="#fff4d6")

    motivo = tk.Text(corpo, height=5, wrap="word", relief="flat",
                     background=janela.cget("background"), foreground="#444")
    motivo.pack(fill="both", expand=True, pady=(10, 0))

    def atualizar(*_):
        nome = escolha.get()
        tabela.delete(*tabela.get_children())
        for ajuste in AJUSTES:
            ausente = valor_atual(dados, ajuste) is None
            agora = valor_efetivo(dados, ajuste)
            novo = ajuste["valores"][nome]
            tabela.insert("", "end",
                          values=(ajuste["rotulo"],
                                  texto_valor(ajuste, agora, ausente),
                                  texto_valor(ajuste, novo)),
                          tags=("muda",) if agora != novo else ())
        motivo.configure(state="normal")
        motivo.delete("1.0", "end")
        motivo.insert("end", "Por que cada ajuste:\n")
        for ajuste in AJUSTES:
            motivo.insert("end", "  - {}: {}\n".format(
                ajuste["rotulo"], ajuste["porque"]))
        motivo.configure(state="disabled")

    escolha.trace_add("write", atualizar)
    atualizar()

    rodape = ttk.Frame(janela, padding=(14, 8, 14, 14))
    rodape.pack(fill="x")
    botoes = []  # preenchido abaixo; confirmar() os desabilita enquanto aplica
    aviso = ttk.Label(
        rodape,
        text="O Mixxx sera fechado antes de gravar - ele reescreve o cfg ao sair.",
        foreground="#777")
    aviso.pack(side="left")

    def confirmar(abrir):
        nome = escolha.get()
        # Fechar o Mixxx leva alguns segundos e trava o mainloop; sem este aviso
        # a janela parece ter congelado.
        aviso.configure(text="Aplicando... fechando o Mixxx, aguarde.",
                        foreground="#b06000")
        for botao in botoes:
            botao.state(["disabled"])
        janela.update()
        try:
            mensagens = []
            trocar_preset(nome, abrir=abrir, log=mensagens.append)
            messagebox.showinfo("Preset aplicado",
                                "\n".join(mensagens).strip(), parent=janela)
        except SystemExit as erro:
            messagebox.showerror("Nao foi possivel aplicar", str(erro), parent=janela)
        finally:
            janela.destroy()

    b_cancelar = ttk.Button(rodape, text="Cancelar", command=janela.destroy)
    b_aplicar = ttk.Button(rodape, text="Aplicar",
                           command=lambda: confirmar(False))
    b_abrir = ttk.Button(rodape, text="Aplicar e abrir o Mixxx",
                         command=lambda: confirmar(True))
    b_cancelar.pack(side="right")
    b_aplicar.pack(side="right", padx=6)
    b_abrir.pack(side="right")
    botoes.extend([b_cancelar, b_aplicar, b_abrir])

    trazer_para_frente()
    janela.mainloop()
    return 0


# --- Main --------------------------------------------------------------------


def main():
    p = argparse.ArgumentParser(
        description="Troca as configuracoes do Mixxx conforme o estilo a tocar.")
    p.add_argument("preset", nargs="?", choices=sorted(PRESETS),
                   help="aplica direto, sem abrir a janela")
    p.add_argument("--status", action="store_true",
                   help="imprime a configuracao atual e sai")
    p.add_argument("--no-launch", action="store_true",
                   help="aplica sem abrir o Mixxx em seguida")
    args = p.parse_args()

    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")

    if args.status:
        imprimir_status()
        return 0
    if args.preset:
        trocar_preset(args.preset, abrir=not args.no_launch)
        return 0
    return abrir_janela()


if __name__ == "__main__":
    sys.exit(main())
