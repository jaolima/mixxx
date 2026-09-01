#!/usr/bin/env python3
"""
Central de configuracoes do Mixxx - Windows, Linux e macOS.

Uma tela unica, no estilo das preferencias do VS Code: busca no topo, categorias
a esquerda, opcoes a direita com o que cada uma faz escrito embaixo.

As Preferencias do proprio Mixxx espalham esses ajustes por mais de dez telas, e
varios dos que mais importam para tocar - curva do crossfader, alcance do pitch,
modo do CUE - ficam em abas diferentes. Aqui estao juntos e com busca.

Uso:
    python mixxx_config.py            # abre a janela
    python mixxx_config.py --list     # imprime tudo em texto, sem janela

O Mixxx precisa estar fechado para gravar: ele mantem as opcoes em memoria e
reescreve o mixxx.cfg inteiro ao sair, desfazendo qualquer edicao externa. A
janela cuida disso ao salvar.

Requer apenas a biblioteca padrao do Python 3.9+ (tkinter para a janela).
"""

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from mixxx_preset import (  # noqa: E402
    CFG_PATH, PERFIS_AUDIO, SOUND_XML, audio_atual, escrever_audio,
    fechar_mixxx, gravar_cfg, ler_cfg, mixxx_rodando, abrir_mixxx,
)

# --- Catalogo de opcoes ------------------------------------------------------
# Cada entrada diz onde mora no mixxx.cfg, que tipo de controle usar e o que faz.
# "opcoes" e uma lista de (valor gravado, rotulo na tela).
#
# Escolhi expor o que muda a forma de tocar. O mixxx.cfg tem mais de 600 chaves,
# a maioria estado interno (tamanho de janela, ultima pasta aberta) que nao faz
# sentido editar aqui.

CATEGORIAS = ["Decks", "Mixer", "Analise", "Biblioteca", "Waveform",
              "Auto DJ", "Gravacao", "Controlador", "Audio"]

OPCOES = [
    # --- Decks ---------------------------------------------------------------
    {
        "cat": "Decks", "rotulo": "Alcance do pitch",
        "busca": "bpm tom velocidade andamento",
        "secao": "[Controls]", "chave": "RateRangePercent",
        "tipo": "escolha", "padrao": "8",
        "opcoes": [("4", "+-4%  (ajuste fino)"), ("8", "+-8%  (padrao de CDJ)"),
                   ("16", "+-16%  (hip hop, mudanca grande de BPM)"),
                   ("50", "+-50%  (extremo)"), ("90", "+-90%  (quase parar)")],
        "ajuda": "Quanto o fader de pitch consegue esticar a musica. Sair de 85 para "
                 "100 BPM exige cerca de 16%; em house, um alcance menor da passo "
                 "mais fino e facilita casar as batidas.",
    },
    {
        "cat": "Decks", "rotulo": "Direcao do pitch",
        "secao": "[Controls]", "chave": "RateDir",
        "tipo": "escolha", "padrao": "1",
        "opcoes": [("1", "Para baixo acelera  (como toca-discos)"),
                   ("0", "Para cima acelera")],
        "ajuda": "Em toca-discos e CDJs, empurrar o fader para baixo acelera a "
                 "musica. Quem aprendeu no hardware costuma estranhar o contrario.",
    },
    {
        "cat": "Decks", "rotulo": "Modo do botao CUE",
        "secao": "[Controls]", "chave": "CueDefault",
        "tipo": "escolha", "padrao": "0",
        "opcoes": [("0", "Mixxx"), ("1", "Pioneer"), ("2", "Denon"),
                   ("3", "Numark"), ("4", "Mixxx (sem piscar)"),
                   ("5", "CUE e tocar")],
        "ajuda": "Como o botao CUE se comporta. Escolha Pioneer para bater com o "
                 "que a DDJ-FLX4 faz - assim o botao da controladora e o da tela "
                 "reagem igual, sem surpresa no meio do set.",
    },
    {
        "cat": "Decks", "rotulo": "Ao carregar uma faixa",
        "secao": "[Controls]", "chave": "CueRecall",
        "tipo": "escolha", "padrao": "0",
        "opcoes": [("0", "Ir para o CUE principal"), ("1", "Ir para o inicio"),
                   ("2", "Pular o silencio inicial")],
        "ajuda": "Onde a agulha cai quando voce carrega a musica. Pular o silencio "
                 "evita aquele atraso mudo ao dar play em arquivo mal cortado.",
    },
    {
        "cat": "Decks", "rotulo": "Quantize (travar na grade)",
        "busca": "scratch grade batida cue loop",
        "secao": "decks", "chave": "quantize",
        "tipo": "bool", "padrao": "1",
        "ajuda": "Empurra cue e loop para a batida mais proxima. Ajuda em house, "
                 "onde a grade e confiavel. Atrapalha em hip hop e reggae: o cue "
                 "precisa cair exatamente onde voce marcou, e a grade dessas "
                 "faixas costuma estar torta.",
    },
    {
        "cat": "Decks", "rotulo": "Keylock (manter o tom)",
        "secao": "decks", "chave": "keylock",
        "tipo": "bool", "padrao": "0",
        "ajuda": "Mantem o tom mesmo mudando o andamento. Sem ele o tom sobe junto, "
                 "como em vinil - parte da estetica do hip hop. Em house, esticar "
                 "muito o BPM sem keylock desafina o vocal.",
    },
    {
        "cat": "Decks", "rotulo": "Motor do keylock",
        "secao": "[App]", "chave": "keylock_engine",
        "tipo": "escolha", "padrao": "1",
        "opcoes": [("0", "SoundTouch  (leve)"), ("1", "RubberBand  (melhor)"),
                   ("2", "RubberBand fino"), ("3", "RubberBand janela curta")],
        "ajuda": "Algoritmo que segura o tom. RubberBand soa melhor e so consome "
                 "CPU quando o keylock esta ligado.",
    },

    # --- Mixer ---------------------------------------------------------------
    {
        "cat": "Mixer", "rotulo": "Curva do crossfader",
        "busca": "scratch transformer crab corte battle",
        "secao": "[Mixer Profile]", "chave": "xFaderCurve",
        "tipo": "escolha", "padrao": "1",
        "opcoes": [("0.6", "Fade bem longo"), ("1", "Fade suave  (padrao)"),
                   ("10", "Transicao media"), ("100", "Corte rapido"),
                   ("300", "Battle mixer  (scratch)"), ("1000", "Corte seco")],
        "ajuda": "O calculo e  ganho = 1 - posicao^curva. Curva ALTA mantem o som "
                 "cheio quase todo o curso e corta so na ponta, entao um movimento "
                 "minimo liga e desliga o audio - e o gesto do transformer e do "
                 "crab. Com curva 1 voce precisa de 29% do curso para o som cair "
                 "3 dB; com 300, de 99,6%.",
    },
    {
        "cat": "Mixer", "rotulo": "Modo do crossfader",
        "busca": "scratch corte mixagem transicao",
        "secao": "[Mixer Profile]", "chave": "xFaderMode",
        "tipo": "escolha", "padrao": "0",
        "opcoes": [("0", "Aditivo  (para cortar)"),
                   ("1", "Potencia constante  (para mixar)")],
        "ajuda": "Potencia constante mantem o volume estavel ao longo de uma "
                 "transicao longa. Para cortar rapido ela so atrapalha.",
    },
    {
        "cat": "Mixer", "rotulo": "Zerar EQ ao trocar de faixa",
        "secao": "[Mixer Profile]", "chave": "EqAutoReset",
        "tipo": "bool", "padrao": "0",
        "ajuda": "Devolve os tres EQs ao centro quando outra musica entra no deck. "
                 "Evita comecar a proxima com o grave cortado da anterior.",
    },
    {
        "cat": "Mixer", "rotulo": "Zerar ganho ao trocar de faixa",
        "secao": "[Mixer Profile]", "chave": "GainAutoReset",
        "tipo": "bool", "padrao": "0",
        "ajuda": "Mesma ideia, para o botao de ganho do canal.",
    },

    # --- Analise -------------------------------------------------------------
    {
        "cat": "Analise", "rotulo": "Andamento na deteccao de BPM",
        "secao": "[BPM]", "chave": "BeatDetectionFixedTempoAssumption",
        "tipo": "escolha", "padrao": "1",
        "opcoes": [("1", "Constante  (house, techno)"),
                   ("0", "Variavel  (hip hop, reggae, ao vivo)")],
        "ajuda": "Constante assume BPM rigidamente igual do inicio ao fim e traca "
                 "uma grade uniforme - perfeito para musica feita em DAW no clique. "
                 "Hip hop e reggae sao tocados por gente e oscilam: com grade "
                 "uniforme ela nasce alinhada e vai derivando ate errar no final. "
                 "So vale para analises NOVAS.",
    },
    {
        "cat": "Analise", "rotulo": "Analise rapida",
        "secao": "[BPM]", "chave": "FastAnalysisEnabled",
        "tipo": "bool", "padrao": "0",
        "ajuda": "Analisa so o comeco da faixa. Termina bem mais rapido numa "
                 "biblioteca grande, mas erra mais em musica que muda de andamento.",
    },
    {
        "cat": "Analise", "rotulo": "Reanalisar ao mudar estes ajustes",
        "secao": "[BPM]", "chave": "ReanalyzeWhenSettingsChange",
        "tipo": "bool", "padrao": "0",
        "ajuda": "Refaz a analise das faixas ja processadas quando voce muda a "
                 "configuracao acima. Sem isso, o que ja foi analisado mantem a "
                 "grade antiga.",
    },

    # --- Biblioteca ----------------------------------------------------------
    {
        "cat": "Biblioteca", "rotulo": "Notacao de tonalidade",
        "busca": "camelot harmonica mixagem tom key",
        "secao": "[Key]", "chave": "KeyNotation",
        "tipo": "escolha", "padrao": "3",
        "opcoes": [("4", "Tradicional  (Am, F#)"), ("3", "Lancelot  (8A, 11B)"),
                   ("2", "OpenKey  (1m, 6d)"),
                   ("6", "Lancelot + tradicional"), ("5", "OpenKey + tradicional")],
        "ajuda": "Lancelot e o sistema de roda harmonica que a maioria dos DJs usa: "
                 "faixas com numero igual ou vizinho combinam. Bem mais pratico de "
                 "ler no meio do set do que Am e F#.",
    },
    {
        "cat": "Biblioteca", "rotulo": "BPM com casas decimais",
        "secao": "[Library]", "chave": "BpmColumnPrecision",
        "tipo": "escolha", "padrao": "1",
        "opcoes": [("0", "Inteiro  (128)"), ("1", "Uma casa  (128,5)"),
                   ("2", "Duas casas  (128,50)")],
        "ajuda": "Quantas casas a coluna BPM mostra. Uma casa costuma bastar para "
                 "decidir se duas faixas casam.",
    },

    # --- Controlador ---------------------------------------------------------
    {
        "cat": "Controlador", "rotulo": "Prato da DDJ-FLX4",
        "busca": "jog wheel scratch vinil prato",
        # O grupo e montado pelo Mixxx como [ControllerSettings_<device>_<caminho>]
        # com %RESOURCE_PATH no lugar de res/, entao nao quebra se o projeto mudar
        # de pasta. Ver src/controllers/legacycontrollermapping.cpp.
        "secao": "[ControllerSettings_DDJ-FLX4_%RESOURCE_PATH"
                 "controllers/Pioneer-DDJ-FLX4.midi.xml]",
        "chave": "vinyl_mode",
        "tipo": "escolha", "padrao": "true",
        "opcoes": [("true", "Vinil - tocar no prato agarra o audio (scratch)"),
                   ("false", "CD - o prato so adianta e atrasa (pitch bend)")],
        "ajuda": "Define o estado inicial. Durante o set, o botao JOG na barra "
                 "superior alterna a qualquer momento.",
    },
    # --- Waveform ------------------------------------------------------------
    {
        "cat": "Waveform", "rotulo": "Aviso de fim de faixa",
        "busca": "alerta piscar tempo restante fim",
        "secao": "[Waveform]", "chave": "EndOfTrackWarningTime",
        "tipo": "escolha", "padrao": "30",
        "opcoes": [("15", "15 segundos"), ("30", "30 segundos  (padrao)"),
                   ("45", "45 segundos"), ("60", "1 minuto"), ("0", "Desligado")],
        "ajuda": "Quantos segundos antes do fim a waveform comeca a piscar. E o "
                 "aviso de que voce precisa engatar a proxima - com o fone no "
                 "ouvido e barulho na pista, e o que salva de deixar o silencio "
                 "entrar.",
    },
    {
        "cat": "Waveform", "rotulo": "Zoom padrao da waveform",
        "secao": "[Waveform]", "chave": "DefaultZoom",
        "tipo": "escolha", "padrao": "3",
        "opcoes": [("1", "1 - bem aproximado"), ("2", "2"), ("3", "3  (padrao)"),
                   ("4", "4"), ("6", "6 - visao ampla")],
        "ajuda": "Aproximado mostra o detalhe da batida, util para alinhar no "
                 "scratch. Ampliado mostra mais da musica de uma vez.",
    },
    {
        "cat": "Waveform", "rotulo": "Sincronizar com a tela (VSync)",
        "secao": "[Waveform]", "chave": "VSync",
        "tipo": "bool", "padrao": "0",
        "ajuda": "Alinha o desenho da waveform com a atualizacao do monitor. Deixa "
                 "mais suave, mas custa CPU - e CPU disputada e o que causa estalo "
                 "no audio com buffer baixo.",
    },

    # --- Auto DJ -------------------------------------------------------------
    {
        "cat": "Auto DJ", "rotulo": "Duracao da transicao",
        "busca": "automatico crossfade tempo",
        "secao": "[Auto DJ]", "chave": "Transition",
        "tipo": "escolha", "padrao": "10",
        "opcoes": [("0", "Corte seco"), ("4", "4 segundos"),
                   ("10", "10 segundos  (padrao)"), ("20", "20 segundos"),
                   ("30", "30 segundos")],
        "ajuda": "Quanto tempo o Auto DJ leva passando de uma faixa para a outra.",
    },
    {
        "cat": "Auto DJ", "rotulo": "Devolver a faixa a fila",
        "secao": "[Auto DJ]", "chave": "Requeue",
        "tipo": "bool", "padrao": "0",
        "ajuda": "Depois de tocar, manda a musica de volta para o fim da fila em vez "
                 "de remove-la. Faz a lista tocar em loop indefinidamente.",
    },

    # --- Gravacao ------------------------------------------------------------
    {
        "cat": "Gravacao", "rotulo": "Formato da gravacao",
        "busca": "gravar set mp3 wav flac",
        "secao": "[Recording]", "chave": "Encoding",
        "tipo": "escolha", "padrao": "WAV",
        "opcoes": [("WAV", "WAV - sem perda, arquivo grande"),
                   ("FLAC", "FLAC - sem perda, comprimido"),
                   ("AIFF", "AIFF - sem perda"),
                   ("MP3", "MP3 - com perda, arquivo pequeno"),
                   ("OGG", "OGG - com perda")],
        "ajuda": "Formato do arquivo ao gravar o set. WAV nao perde nada mas ocupa "
                 "cerca de 600 MB por hora; FLAC guarda o mesmo audio na metade do "
                 "espaco; MP3 serve para publicar.",
    },

    # --- Mixer (normalizacao) -----------------------------------------------
    {
        "cat": "Mixer", "rotulo": "Normalizar volume (ReplayGain)",
        "busca": "volume ganho igualar loudness",
        "secao": "[ReplayGain]", "chave": "ReplayGainEnabled",
        "tipo": "bool", "padrao": "1",
        "ajuda": "Iguala o volume percebido entre faixas de origens diferentes. Sem "
                 "isso, um vinil ripado entra bem mais baixo que um lancamento "
                 "moderno, e voce corrige no ganho as pressas.",
    },
]



def texto_busca(opcao):
    """Tudo em que a busca procura.

    Inclui os rotulos das escolhas de proposito: quem digita "scratch" espera
    achar a curva do crossfader e o modo do prato, e a palavra so aparece ali.
    """
    partes = [opcao["rotulo"], opcao["ajuda"], opcao["cat"],
              opcao.get("busca", "")]
    partes += [rot for _, rot in opcao.get("opcoes", [])]
    return " ".join(partes).lower()


def opcao_por_chave(secao, chave):
    for o in OPCOES:
        if o["secao"] == secao and o["chave"] == chave:
            return o
    return None


def secoes_de(opcao):
    """A opcao 'decks' vale para os quatro canais."""
    if opcao["secao"] == "decks":
        return ["[Channel{}]".format(n) for n in range(1, 5)]
    return [opcao["secao"]]


def ler_valor(dados, opcao):
    for secao in secoes_de(opcao):
        if secao in dados and opcao["chave"] in dados[secao]:
            return dados[secao][opcao["chave"]]
    return None


def rotulo_do_valor(opcao, valor):
    if opcao["tipo"] == "bool":
        return "ligado" if valor == "1" else "desligado"
    for v, rot in opcao.get("opcoes", []):
        if v == valor:
            return rot
    return valor


def escrever_valor(dados, ordem, opcao, valor):
    for secao in secoes_de(opcao):
        if secao not in dados:
            dados[secao] = {}
            ordem.append(secao)
        dados[secao][opcao["chave"]] = valor


# --- Modo texto --------------------------------------------------------------

def listar():
    _, dados = ler_cfg(CFG_PATH)
    for cat in CATEGORIAS:
        itens = [o for o in OPCOES if o["cat"] == cat]
        if cat == "Audio":
            som = audio_atual()
            print("\n{}\n{}".format(cat.upper(), "-" * 60))
            for nome, perfil in PERFIS_AUDIO.items():
                marca = ">" if nome == som else " "
                print(" {} {:<12} {}".format(marca, nome, perfil["descricao"]))
            if som == "vazio":
                print("   (o Mixxx apagou a saida ao abrir sem o dispositivo)")
            continue
        if not itens:
            continue
        print("\n{}\n{}".format(cat.upper(), "-" * 60))
        for o in itens:
            atual = ler_valor(dados, o)
            usando_padrao = atual is None
            if usando_padrao:
                atual = o["padrao"]
            print("  {:<32} {}{}".format(
                o["rotulo"] + ":", rotulo_do_valor(o, atual),
                "   (padrao)" if usando_padrao else ""))
    print()


# --- Janela ------------------------------------------------------------------

def abrir_janela():
    try:
        import tkinter as tk
        from tkinter import messagebox, ttk
    except ImportError:
        print("tkinter nao disponivel. No Debian/Ubuntu: sudo apt install python3-tk")
        print("Use o modo texto: python mixxx_config.py --list")
        return 1

    if not CFG_PATH.exists():
        print("mixxx.cfg nao encontrado em {}".format(CFG_PATH))
        return 1

    ordem, dados = ler_cfg(CFG_PATH)
    pendentes = {}          # (secao, chave) -> valor novo
    audio_pendente = [None]  # perfil de audio a aplicar, se mudou

    win = tk.Tk()
    win.title("Configuracoes do Mixxx")
    win.minsize(940, 620)

    def trazer_para_frente():
        """Sem isto a janela nasce atras do editor e passa despercebida."""
        win.update_idletasks()
        largura = max(win.winfo_width(), 940)
        altura = max(win.winfo_height(), 620)
        x = (win.winfo_screenwidth() - largura) // 2
        y = (win.winfo_screenheight() - altura) // 3
        win.geometry("{}x{}+{}+{}".format(largura, altura, max(x, 0), max(y, 0)))
        win.deiconify()
        win.lift()
        win.attributes("-topmost", True)
        win.after(400, lambda: win.attributes("-topmost", False))
        try:
            win.focus_force()
        except tk.TclError:
            pass  # alguns gerenciadores de janela no Linux recusam o foco forcado

    # ----- busca -----
    topo = ttk.Frame(win, padding=(12, 10, 12, 6))
    topo.pack(fill="x")
    ttk.Label(topo, text="Buscar:").pack(side="left", padx=(0, 6))
    busca_var = tk.StringVar()
    entrada = ttk.Entry(topo, textvariable=busca_var)
    entrada.pack(side="left", fill="x", expand=True)
    entrada.focus_set()
    contador = ttk.Label(topo, text="", foreground="#666")
    contador.pack(side="left", padx=(10, 0))

    corpo = ttk.Frame(win, padding=(12, 0, 12, 0))
    corpo.pack(fill="both", expand=True)

    # ----- categorias -----
    esq = ttk.Frame(corpo)
    esq.pack(side="left", fill="y", padx=(0, 12))
    cat_var = tk.StringVar(value="Todas")
    lista = tk.Listbox(esq, width=16, height=18, exportselection=False,
                       activestyle="none")
    for c in ["Todas"] + CATEGORIAS:
        lista.insert("end", c)
    lista.selection_set(0)
    lista.pack(fill="y", expand=True)

    # ----- painel rolavel de opcoes -----
    dir_ = ttk.Frame(corpo)
    dir_.pack(side="left", fill="both", expand=True)
    canvas = tk.Canvas(dir_, highlightthickness=0, background=win.cget("background"))
    scroll = ttk.Scrollbar(dir_, orient="vertical", command=canvas.yview)
    interno = ttk.Frame(canvas)
    interno.bind("<Configure>",
                 lambda e: canvas.configure(scrollregion=canvas.bbox("all")))
    janela_id = canvas.create_window((0, 0), window=interno, anchor="nw")
    canvas.bind("<Configure>", lambda e: canvas.itemconfigure(janela_id, width=e.width))
    canvas.configure(yscrollcommand=scroll.set)
    canvas.pack(side="left", fill="both", expand=True)
    scroll.pack(side="right", fill="y")
    canvas.bind_all("<MouseWheel>",
                    lambda e: canvas.yview_scroll(int(-e.delta / 120), "units"))

    rodape = ttk.Frame(win, padding=(12, 8, 12, 12))
    rodape.pack(fill="x")
    resumo = ttk.Label(rodape, text="Nenhuma alteracao", foreground="#666")
    resumo.pack(side="left")

    def marcar(opcao, valor):
        chave = (opcao["secao"], opcao["chave"])
        if valor == (ler_valor(dados, opcao) or opcao["padrao"]):
            pendentes.pop(chave, None)
        else:
            pendentes[chave] = valor
        atualizar_resumo()

    def atualizar_resumo():
        n = len(pendentes) + (1 if audio_pendente[0] else 0)
        resumo.configure(
            text="Nenhuma alteracao" if n == 0
            else "{} alteracao{} para salvar".format(n, "" if n == 1 else "es"),
            foreground="#666" if n == 0 else "#a06000")

    def montar():
        for w in interno.winfo_children():
            w.destroy()
        termo = busca_var.get().strip().lower()
        sel = lista.curselection()
        cat_sel = lista.get(sel[0]) if sel else "Todas"
        mostrados = 0

        # Audio e um caso a parte: nao mora no mixxx.cfg
        if cat_sel in ("Todas", "Audio") and (
                not termo or "audio" in termo or "saida" in termo or "fone" in termo):
            bloco = ttk.LabelFrame(interno, text="Saida de audio", padding=10)
            bloco.pack(fill="x", pady=(8, 4))
            som = audio_atual()
            var = tk.StringVar(value=som if som in PERFIS_AUDIO else "")
            for nome, perfil in PERFIS_AUDIO.items():
                ttk.Radiobutton(
                    bloco, text=perfil["descricao"], value=nome, variable=var,
                    command=lambda v=var: (audio_pendente.__setitem__(0, v.get()),
                                           atualizar_resumo())).pack(anchor="w")
            if som == "vazio":
                ttk.Label(bloco, foreground="#a04000",
                          text="O Mixxx apagou a saida ao abrir sem o dispositivo. "
                               "Escolha uma acima.").pack(anchor="w", pady=(6, 0))
            ttk.Label(bloco, foreground="#555", wraplength=620, justify="left",
                      text="O perfil do notebook nao tem pre-escuta: a placa expoe "
                           "um par estereo so, entao o CUE do fone nao isola a "
                           "faixa.").pack(anchor="w", pady=(6, 0))
            mostrados += 1

        for o in OPCOES:
            if cat_sel != "Todas" and o["cat"] != cat_sel:
                continue
            if termo and termo not in texto_busca(o):
                continue
            mostrados += 1
            atual = ler_valor(dados, o)
            usando_padrao = atual is None
            if usando_padrao:
                atual = o["padrao"]
            chave = (o["secao"], o["chave"])
            if chave in pendentes:
                atual = pendentes[chave]

            titulo = o["rotulo"] + ("   (usando o padrao)" if usando_padrao else "")
            bloco = ttk.LabelFrame(interno, text=titulo, padding=10)
            bloco.pack(fill="x", pady=(8, 4))

            if o["tipo"] == "bool":
                v = tk.BooleanVar(value=(atual == "1"))
                ttk.Checkbutton(
                    bloco, text="Ligado", variable=v,
                    command=lambda oo=o, vv=v: marcar(oo, "1" if vv.get() else "0")
                ).pack(anchor="w")
            else:
                valores = [rot for _, rot in o["opcoes"]]
                atual_rot = rotulo_do_valor(o, atual)
                v = tk.StringVar(value=atual_rot)
                combo = ttk.Combobox(bloco, values=valores, textvariable=v,
                                     state="readonly", width=46)
                combo.pack(anchor="w")

                def escolher(_e, oo=o, vv=v):
                    for valor, rot in oo["opcoes"]:
                        if rot == vv.get():
                            marcar(oo, valor)
                            break
                combo.bind("<<ComboboxSelected>>", escolher)

            ttk.Label(bloco, text=o["ajuda"], foreground="#555",
                      wraplength=620, justify="left").pack(anchor="w", pady=(6, 0))

        contador.configure(text="{} opcoes".format(mostrados))
        if mostrados == 0:
            ttk.Label(interno, foreground="#777",
                      text="Nada encontrado para essa busca.").pack(pady=20)
        canvas.yview_moveto(0)

    busca_var.trace_add("write", lambda *_: montar())
    lista.bind("<<ListboxSelect>>", lambda _e: montar())
    montar()
    win.after(80, trazer_para_frente)

    def salvar():
        if not pendentes and not audio_pendente[0]:
            messagebox.showinfo("Nada a salvar", "Nenhuma alteracao foi feita.")
            return
        if mixxx_rodando():
            if not messagebox.askyesno(
                    "Fechar o Mixxx?",
                    "O Mixxx precisa ser fechado para gravar: ele reescreve o\n"
                    "arquivo de configuracao ao sair e desfaria estas mudancas.\n\n"
                    "Fechar agora?"):
                return
            if not fechar_mixxx():
                messagebox.showerror(
                    "Nao foi possivel fechar",
                    "O Mixxx nao respondeu - pode haver um dialogo aberto.\n"
                    "Feche-o na mao e tente de novo.")
                return

        if pendentes:
            import shutil
            shutil.copy2(CFG_PATH, CFG_PATH.with_suffix(".cfg.bak-config"))
            for (secao, chave), valor in pendentes.items():
                escrever_valor(dados, ordem, opcao_por_chave(secao, chave), valor)
            gravar_cfg(CFG_PATH, ordem, dados)
        if audio_pendente[0]:
            escrever_audio(audio_pendente[0])

        total = len(pendentes) + (1 if audio_pendente[0] else 0)
        pendentes.clear()
        audio_pendente[0] = None
        print("{} alteracao(oes) salvas.".format(total))
        # Perguntar ANTES de destruir a janela: um dialogo criado depois de
        # destruir a raiz do tkinter nao tem pai e falha.
        abrir = messagebox.askyesno(
            "Salvo", "{} alteracao(oes) gravadas.\n\nAbrir o Mixxx agora?".format(total))
        win.destroy()
        if abrir:
            abrir_mixxx()

    ttk.Button(rodape, text="Fechar", command=win.destroy).pack(side="right")
    ttk.Button(rodape, text="Salvar", command=salvar).pack(side="right", padx=6)

    win.mainloop()
    return 0


def main():
    p = argparse.ArgumentParser(
        description="Central de configuracoes do Mixxx, com busca e categorias.")
    p.add_argument("--list", action="store_true",
                   help="imprime as configuracoes em texto e sai")
    args = p.parse_args()

    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")

    if args.list:
        listar()
        return 0
    return abrir_janela()


if __name__ == "__main__":
    sys.exit(main())
