#!/usr/bin/env python3
"""
Exporta playlists do Deezer para o Mixxx.

Le uma playlist do Deezer, casa cada faixa com os arquivos que voce ja tem na
biblioteca do Mixxx e gera:

  <nome>.m3u8            playlist pronta para o Mixxx (so o que voce ja tem)
  <nome>_completo.csv    tudo, com o status de cada faixa
  <nome>_faltando.csv    o que falta, com links de compra
  <nome>_comprar.html    a mesma lista de compras, com os links clicaveis

Ao contrario do Spotify, a API do Deezer serve playlists publicas sem login:
basta a URL. Nao ha OAuth, client id nem token.

O que este script NAO faz: baixar audio. O Deezer entrega apenas metadados
(titulo, artista, album, duracao) e um trecho de 30 s de amostra. Baixar as
faixas completas exigiria burlar a protecao do servico - e infracao de direitos
autorais, e num software que voce pretende vender seria um risco juridico
direto. Por isso a saida daqui e uma lista de compras, nao um downloader.

Uso:
    python deezer_to_mixxx.py https://www.deezer.com/br/playlist/1234567
    python deezer_to_mixxx.py 1234567 --outdir "D:/playlists"
    python deezer_to_mixxx.py --list <id-ou-url-do-seu-perfil>

Requer apenas a biblioteca padrao do Python 3.9+.
"""

import argparse
import csv
import html
import re
import sys
import urllib.parse
from pathlib import Path

# O nucleo de casamento (normalizacao, leitura da biblioteca, comparacao) e o
# mesmo usado para o Spotify: o que muda entre servicos e so a leitura da
# playlist. Reaproveitamos em vez de duplicar; se um terceiro servico entrar,
# vale extrair essas funcoes para um modulo proprio.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from spotify_to_mixxx import (  # noqa: E402
    http_json, load_mixxx_library, match, norm, safe_name,
)

API = "https://api.deezer.com"
PAGE = 100

# Sufixo de 11 caracteres que o yt-dlp cola no nome do arquivo: "... [pNEuK4ZRtvk]".
_YT_ID = re.compile(r"\s*\[[A-Za-z0-9_-]{11}\]\s*$")

# Ruido tipico de titulo vindo de video, que o servico de streaming nunca traz:
# "(Lyric Video)", "Video Clipe Oficial", "[HD]", "#DiscotecaNegra".
# Termos deliberadamente especificos - "video" sozinho sairia em "Video Games".
_VIDEO_NOISE = re.compile(
    r"\s*[\(\[\-]?\s*\b("
    r"official\s+(music\s+)?video|official\s+audio|lyric\s+video|visualizer|"
    r"video\s*clipe\s*oficial|clipe\s*oficial|videoclipe|audio\s+oficial|"
    r"ao\s+vivo\s+oficial|hd|hq|4k|full\s+album"
    r")\b\s*[\)\]]?", re.IGNORECASE)

# "feat. Fulano" ate o fim, mesmo sem parenteses delimitando.
_FEAT_TAIL = re.compile(r"\s+(feat\.?|ft\.?|com)\s+.*$", re.IGNORECASE)

# Hashtag de canal/coletivo: "#DiscotecaNegra"
_HASHTAG = re.compile(r"\s*#\w+")

# Lojas onde a faixa pode ser comprada. Cada entrada monta uma URL de busca por
# "artista titulo" - a busca e mais robusta que tentar adivinhar o link direto.
LOJAS = [
    ("Beatport", "https://www.beatport.com/search?q={}"),
    ("Traxsource", "https://www.traxsource.com/search?term={}"),
    ("Juno", "https://www.junodownload.com/search/?q%5Ball%5D%5B%5D={}"),
    ("Bandcamp", "https://bandcamp.com/search?q={}"),
    ("Apple", "https://music.apple.com/search?term={}"),
    ("Amazon", "https://www.amazon.com.br/s?i=digital-music&k={}"),
]


# --- Deezer ------------------------------------------------------------------

def playlist_id(ref):
    """Aceita URL (com ou sem /br/) ou ID puro."""
    ref = ref.strip()
    m = re.search(r"playlist/(\d+)", ref)
    if m:
        return m.group(1)
    if ref.isdigit():
        return ref
    raise SystemExit(
        "Nao reconheci '{}' como playlist do Deezer.\n"
        "Use a URL (https://www.deezer.com/br/playlist/1234567) ou so o numero.".format(ref))


def user_id(ref):
    ref = ref.strip()
    m = re.search(r"profile/(\d+)", ref)
    if m:
        return m.group(1)
    if ref.isdigit():
        return ref
    raise SystemExit("Nao reconheci '{}' como perfil do Deezer.".format(ref))


def _check(payload):
    """A API do Deezer responde 200 mesmo em erro, sinalizando no corpo."""
    if isinstance(payload, dict) and payload.get("error"):
        err = payload["error"]
        msg = err.get("message") if isinstance(err, dict) else str(err)
        raise SystemExit("Deezer recusou a requisicao: {}".format(msg))
    return payload


def fetch_playlist(pid):
    """Devolve (nome, [faixas]) de uma playlist publica."""
    meta = _check(http_json("{}/playlist/{}".format(API, pid)))
    name = meta.get("title") or "playlist"

    tracks, index = [], 0
    while True:
        page = _check(http_json(
            "{}/playlist/{}/tracks?index={}&limit={}".format(API, pid, index, PAGE)))
        data = page.get("data") or []
        for t in data:
            if not t.get("title"):
                continue
            tracks.append({
                "artist": (t.get("artist") or {}).get("name", ""),
                "title": t.get("title", ""),
                "album": (t.get("album") or {}).get("title", ""),
                # o Deezer ja informa a duracao em segundos
                "duration": t.get("duration") or 0,
                "isrc": t.get("isrc", ""),
                "url": t.get("link", ""),
            })
        if not page.get("next") or not data:
            break
        index += PAGE
    return name, tracks


def list_playlists(uid):
    out, index = [], 0
    while True:
        page = _check(http_json(
            "{}/user/{}/playlists?index={}&limit={}".format(API, uid, index, PAGE)))
        data = page.get("data") or []
        out.extend(data)
        if not page.get("next") or not data:
            break
        index += PAGE
    return out


# --- Biblioteca: recuperar metadados de arquivos baixados --------------------

def enrich_library(lib):
    """Gera chaves alternativas para faixas com metadado pobre.

    Boa parte de uma biblioteca real vem de download: o campo artista fica vazio
    e o titulo carrega tudo junto, com o id do video no fim -
    "JOPLYN - Can't Get Enough (Adana Twins Remix) [pNEuK4ZRtvk]".
    Comparado assim, nada casa, e a lista de compras manda comprar o que voce ja
    tem. Aqui derivamos "artista - titulo" do proprio nome e guardamos como chave
    adicional. Nunca descartamos a chave original: so acrescentamos tentativas,
    de modo que este tratamento pode melhorar o resultado, nunca piorar.
    """
    for item in lib:
        alt = set()
        alt.add(item["key"])  # a chave original nunca se perde
        limpo = _YT_ID.sub("", item["title"]).strip()

        # O id do video so atrapalha a comparacao: a versao limpa vira a
        # principal, inclusive para o casamento aproximado por similaridade.
        if limpo != item["title"]:
            item["ntitle"] = norm(limpo)
            item["key"] = (item["nartist"] + " " + item["ntitle"]).strip()
            alt.add(item["key"])

        # Sem artista, o titulo costuma trazer tudo junto: "Artista - Titulo"
        if not item["artist"].strip() and " - " in limpo:
            a, _, t = limpo.partition(" - ")
            derivada = (norm(a) + " " + norm(t)).strip()
            if derivada:
                # a chave sem artista e fraca: promovemos a derivada
                item["key"] = derivada
                item["nartist"] = norm(a)
                item["ntitle"] = norm(t)
                alt.add(derivada)

        # Variantes sem o ruido de video e sem o "feat. Fulano": o Deezer
        # entrega o titulo limpo, entao estas sao as chaves que de fato casam.
        # Sao acrescentadas, nunca substituem - se a limpeza exagerar num caso,
        # as chaves anteriores continuam valendo.
        enxuto = _HASHTAG.sub("", _VIDEO_NOISE.sub("", limpo)).strip(" -")
        for candidato in (enxuto, _FEAT_TAIL.sub("", enxuto)):
            if not candidato:
                continue
            alt.add((item["nartist"] + " " + norm(candidato)).strip())
            if " - " in candidato:
                a, _, t = candidato.partition(" - ")
                a, t = norm(a), norm(_FEAT_TAIL.sub("", t))
                if a and t:
                    alt.add((a + " " + t).strip())

        alt.discard(item["key"])
        item["altkeys"] = alt
    return lib


def build_index(lib):
    """Indice chave -> item, incluindo as chaves alternativas."""
    index = {}
    for item in lib:
        index.setdefault(item["key"], item)
    for item in lib:
        for k in item.get("altkeys", ()):
            index.setdefault(k, item)
    return index


# --- Lista de compras --------------------------------------------------------

def links_de_compra(artist, title):
    termo = urllib.parse.quote_plus("{} {}".format(artist, title).strip())
    return [(loja, url.format(termo)) for loja, url in LOJAS]


def write_shopping_list(name, missing, outdir):
    """Grava o que falta em CSV e em HTML com os links clicaveis."""
    base = safe_name(name)

    cols = ["artist", "title", "album", "duration", "metodo", "aviso", "url"]
    cols += [loja for loja, _ in LOJAS]

    csv_path = outdir / (base + "_faltando.csv")
    with csv_path.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=cols, extrasaction="ignore")
        w.writeheader()
        for r in missing:
            row = dict(r)
            for loja, link in links_de_compra(r["artist"], r["title"]):
                row[loja] = link
            w.writerow(row)

    html_path = outdir / (base + "_comprar.html")
    with html_path.open("w", encoding="utf-8", newline="\n") as f:
        f.write("<!doctype html><meta charset='utf-8'>")
        f.write("<title>Comprar - {}</title>".format(html.escape(name)))
        f.write("<style>"
                "body{font:14px system-ui,sans-serif;margin:2rem;max-width:1100px}"
                "table{border-collapse:collapse;width:100%}"
                "th,td{padding:.5rem .6rem;border-bottom:1px solid #ddd;text-align:left}"
                "th{background:#f4f4f5}tr:hover td{background:#fafafa}"
                "a{margin-right:.5rem;white-space:nowrap}"
                ".n{color:#666;font-size:.9em}"
                "</style>")
        f.write("<h1>Faltando em &laquo;{}&raquo;</h1>".format(html.escape(name)))
        f.write("<p class=n>{} faixas para adquirir. Os links abrem a busca em cada loja.</p>"
                .format(len(missing)))
        f.write("<table><tr><th>#</th><th>Artista</th><th>Titulo</th>"
                "<th>Duracao</th><th>Onde comprar</th></tr>")
        for i, r in enumerate(missing, 1):
            dur = ""
            if r["duration"]:
                dur = "{}:{:02d}".format(r["duration"] // 60, r["duration"] % 60)
            lojas = " ".join(
                "<a href='{}' target='_blank' rel='noopener'>{}</a>".format(
                    html.escape(link), loja)
                for loja, link in links_de_compra(r["artist"], r["title"]))
            f.write("<tr><td class=n>{}</td><td>{}</td><td>{}</td>"
                    "<td class=n>{}</td><td>{}</td></tr>".format(
                        i, html.escape(r["artist"]), html.escape(r["title"]), dur, lojas))
        f.write("</table>")

    return csv_path, html_path


def write_m3u_and_full(name, results, outdir):
    base = safe_name(name)
    found = [r for r in results if r["location"]]

    m3u = outdir / (base + ".m3u8")
    with m3u.open("w", encoding="utf-8", newline="\n") as f:
        f.write("#EXTM3U\n")
        for r in found:
            f.write("#EXTINF:{},{} - {}\n".format(r["duration"], r["artist"], r["title"]))
            f.write(r["location"] + "\n")

    cols = ["artist", "title", "album", "duration", "isrc", "status",
            "confianca", "metodo", "aviso", "location", "url"]
    full = outdir / (base + "_completo.csv")
    with full.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=cols, extrasaction="ignore")
        w.writeheader()
        w.writerows(results)
    return m3u, full


# --- Main --------------------------------------------------------------------

def main():
    # O console do Windows usa cp1252 e levanta UnicodeEncodeError em nomes com
    # emoji - que sao a regra, nao a excecao, nas playlists do Deezer. Os
    # arquivos gerados sao sempre UTF-8; isto conserta so a impressao na tela.
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")

    p = argparse.ArgumentParser(
        description="Exporta uma playlist do Deezer para o Mixxx e lista o que falta comprar.")
    p.add_argument("playlist", nargs="?", help="URL ou ID da playlist do Deezer")
    p.add_argument("--list", metavar="PERFIL",
                   help="lista as playlists publicas de um perfil (URL ou ID)")
    p.add_argument("--outdir", default=".", help="pasta de saida (padrao: atual)")
    args = p.parse_args()

    if args.list:
        pls = list_playlists(user_id(args.list))
        if not pls:
            print("Nenhuma playlist publica nesse perfil.")
            return
        print("{} playlists:\n".format(len(pls)))
        for pl in pls:
            print("  {:>10}  {:<45} {} faixas".format(
                pl.get("id", ""), (pl.get("title") or "")[:45], pl.get("nb_tracks", "?")))
        print("\nRode de novo passando o ID da playlist que quiser exportar.")
        return

    if not args.playlist:
        p.error("informe a playlist, ou use --list para descobrir os IDs")

    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    print("Lendo playlist no Deezer...")
    name, tracks = fetch_playlist(playlist_id(args.playlist))
    print('  "{}" - {} faixas'.format(name, len(tracks)))

    print("Lendo a biblioteca do Mixxx...")
    lib = enrich_library(load_mixxx_library())
    index = build_index(lib)
    recuperadas = sum(1 for i in lib if i.get("altkeys"))
    print("  {} faixas na sua biblioteca".format(len(lib)))
    if recuperadas:
        print("  {} com metadado incompleto - artista/titulo deduzidos do nome do arquivo"
              .format(recuperadas))

    print("Comparando...")
    results = []
    for t in tracks:
        item, score, metodo, aviso = match(t, lib, index)
        r = dict(t)
        r["location"] = item["location"] if item else ""
        r["status"] = "tenho" if item else "falta"
        r["confianca"] = "{:.2f}".format(score)
        r["metodo"] = metodo
        r["aviso"] = aviso
        results.append(r)

    missing = [r for r in results if not r["location"]]
    m3u, full = write_m3u_and_full(name, results, outdir)
    csv_path, html_path = write_shopping_list(name, missing, outdir)

    tenho = len(results) - len(missing)
    print("\n{} de {} faixas voce ja tem.".format(tenho, len(results)))
    avisos = [r for r in results if r["aviso"]]
    if avisos:
        print("{} com duracao divergente (pode ser outra versao) - veja o CSV completo."
              .format(len(avisos)))
    print("\nGerado em {}:".format(outdir.resolve()))
    print("  {}   <- importe no Mixxx".format(m3u.name))
    print("  {}".format(full.name))
    print("  {}".format(csv_path.name))
    print("  {}   <- abra no navegador para comprar".format(html_path.name))


if __name__ == "__main__":
    main()
