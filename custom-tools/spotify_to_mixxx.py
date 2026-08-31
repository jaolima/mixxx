#!/usr/bin/env python3
"""
Exporta playlists do Spotify para o Mixxx.

Le uma playlist do Spotify, casa cada faixa com os arquivos que voce ja tem na
biblioteca do Mixxx e gera:

  <nome>.m3u8          playlist pronta para importar no Mixxx (so o que voce tem)
  <nome>_faltando.csv  o que nao foi encontrado (lista de compras)
  <nome>_completo.csv  tudo, com o status de cada faixa

Nao baixa nem reproduz audio do Spotify: o Spotify nao expoe o audio decodificado
e proibe uso em software de DJ. Isto trabalha apenas com metadados.

Uso:
    python spotify_to_mixxx.py --login --client-id SEU_CLIENT_ID
    python spotify_to_mixxx.py --list
    python spotify_to_mixxx.py <url-ou-id-da-playlist>
    python spotify_to_mixxx.py --liked

Requer apenas a biblioteca padrao do Python 3.9+.
"""

import argparse
import base64
import csv
import difflib
import hashlib
import json
import os
import re
import secrets
import sqlite3
import threading
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

# --- Configuracao ------------------------------------------------------------

# O Spotify exige redirect HTTPS, com uma unica excecao: o loopback literal
# 127.0.0.1. Nao use "localhost", que o Spotify passou a rejeitar.
REDIRECT_PORT = 8888
REDIRECT_URI = "http://127.0.0.1:{}/callback".format(REDIRECT_PORT)
SCOPES = "playlist-read-private playlist-read-collaborative user-library-read"

AUTH_URL = "https://accounts.spotify.com/authorize"
TOKEN_URL = "https://accounts.spotify.com/api/token"
API = "https://api.spotify.com/v1"

CONFIG_DIR = Path(os.environ.get("LOCALAPPDATA", Path.home())) / "MixxxSpotify"
TOKEN_FILE = CONFIG_DIR / "token.json"
MIXXX_DB = Path(os.environ.get("LOCALAPPDATA", Path.home())) / "Mixxx" / "mixxxdb.sqlite"

# Confianca minima para aceitar um casamento aproximado (0..1)
FUZZY_THRESHOLD = 0.87
# Tolerancia de duracao, em segundos, para confirmar um casamento aproximado
DURATION_TOLERANCE = 8


# --- HTTP --------------------------------------------------------------------

def http_json(url, data=None, headers=None, method=None):
    """Faz uma requisicao e devolve o JSON, com erros legiveis."""
    body = None
    headers = dict(headers or {})
    if data is not None:
        body = urllib.parse.urlencode(data).encode()
        headers["Content-Type"] = "application/x-www-form-urlencoded"
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")
        raise SystemExit("Erro HTTP {} em {}\n{}".format(e.code, url, detail)) from None
    except urllib.error.URLError as e:
        raise SystemExit("Falha de rede: {}".format(e.reason)) from None


# --- OAuth: Authorization Code + PKCE (nao precisa de client secret) ---------

class _CallbackHandler(BaseHTTPRequestHandler):
    code = None
    error = None

    def do_GET(self):
        params = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        _CallbackHandler.code = params.get("code", [None])[0]
        _CallbackHandler.error = params.get("error", [None])[0]
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        if _CallbackHandler.code:
            msg = "Autorizado. Pode fechar esta aba e voltar ao terminal."
        else:
            msg = "Falhou: {}".format(_CallbackHandler.error)
        page = "<html><body style=\"font-family:sans-serif;padding:40px\"><h2>{}</h2></body></html>"
        self.wfile.write(page.format(msg).encode())

    def log_message(self, *args):
        pass  # silencia o log do servidor


def login(client_id):
    """Fluxo PKCE: abre o navegador e captura o codigo no loopback."""
    verifier = base64.urlsafe_b64encode(secrets.token_bytes(64)).decode().rstrip("=")
    challenge = base64.urlsafe_b64encode(
        hashlib.sha256(verifier.encode()).digest()).decode().rstrip("=")

    params = {
        "client_id": client_id,
        "response_type": "code",
        "redirect_uri": REDIRECT_URI,
        "scope": SCOPES,
        "code_challenge_method": "S256",
        "code_challenge": challenge,
        "state": secrets.token_urlsafe(16),
    }
    url = AUTH_URL + "?" + urllib.parse.urlencode(params)

    _CallbackHandler.code = None
    _CallbackHandler.error = None
    server = HTTPServer(("127.0.0.1", REDIRECT_PORT), _CallbackHandler)
    threading.Thread(target=server.handle_request, daemon=True).start()

    print("Abrindo o navegador para autorizar...")
    print("Se nao abrir sozinho, acesse:\n{}\n".format(url))
    webbrowser.open(url)

    waited = 0.0
    while _CallbackHandler.code is None and _CallbackHandler.error is None and waited < 300:
        time.sleep(0.3)
        waited += 0.3
    server.server_close()

    if _CallbackHandler.error:
        raise SystemExit("Autorizacao negada: {}".format(_CallbackHandler.error))
    if not _CallbackHandler.code:
        raise SystemExit("Tempo esgotado esperando a autorizacao.")

    tok = http_json(TOKEN_URL, data={
        "grant_type": "authorization_code",
        "code": _CallbackHandler.code,
        "redirect_uri": REDIRECT_URI,
        "client_id": client_id,
        "code_verifier": verifier,
    })
    tok["client_id"] = client_id
    save_token(tok)
    print("Login concluido.")
    return tok["access_token"]


def save_token(tok):
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    TOKEN_FILE.write_text(json.dumps(tok), encoding="utf-8")
    try:
        os.chmod(TOKEN_FILE, 0o600)
    except OSError:
        pass


def get_token(client_id=None):
    """Devolve um access token valido, renovando pelo refresh token quando da."""
    if TOKEN_FILE.exists():
        tok = json.loads(TOKEN_FILE.read_text(encoding="utf-8"))
        cid = client_id or tok.get("client_id")
        if tok.get("refresh_token") and cid:
            new = http_json(TOKEN_URL, data={
                "grant_type": "refresh_token",
                "refresh_token": tok["refresh_token"],
                "client_id": cid,
            })
            new.setdefault("refresh_token", tok["refresh_token"])
            new["client_id"] = cid
            save_token(new)
            return new["access_token"]
    if not client_id:
        raise SystemExit(
            "Sem credenciais salvas. Rode primeiro:\n"
            "  python spotify_to_mixxx.py --login --client-id SEU_CLIENT_ID")
    return login(client_id)


def api_get(token, path, **params):
    url = path if path.startswith("http") else API + path
    if params:
        url += "?" + urllib.parse.urlencode(params)
    return http_json(url, headers={"Authorization": "Bearer " + token})


# --- Normalizacao e casamento -----------------------------------------------

# Sufixos comuns no Spotify que raramente aparecem no arquivo local
_NOISE = re.compile(
    r"\s*[\(\[\-]\s*(remaster(ed)?|radio edit|single version|album version|"
    r"bonus track|deluxe|explicit|clean|mono|stereo|feat\.?|ft\.?|with)\b.*$",
    re.IGNORECASE)


def norm(text):
    """Reduz um texto a forma comparavel: sem acento, sem pontuacao, sem ruido."""
    if not text:
        return ""
    text = unicodedata.normalize("NFKD", text)
    text = "".join(c for c in text if not unicodedata.combining(c))
    text = _NOISE.sub("", text)
    text = re.sub(r"[^0-9a-zA-Z]+", " ", text)
    return " ".join(text.lower().split())


def load_mixxx_library():
    """Le a biblioteca do Mixxx. Somente leitura: seguro com o Mixxx aberto."""
    if not MIXXX_DB.exists():
        raise SystemExit("Banco do Mixxx nao encontrado em {}".format(MIXXX_DB))
    con = sqlite3.connect("file:{}?mode=ro".format(MIXXX_DB.as_posix()), uri=True)
    rows = con.execute(
        "SELECT l.artist, l.title, l.album, l.duration, t.location "
        "FROM library l JOIN track_locations t ON l.location = t.id "
        "WHERE COALESCE(l.mixxx_deleted,0) = 0 AND COALESCE(t.fs_deleted,0) = 0"
    ).fetchall()
    con.close()

    lib = []
    for artist, title, album, duration, location in rows:
        lib.append({
            "artist": artist or "",
            "title": title or "",
            "album": album or "",
            "duration": duration or 0,
            "location": location,
            "nartist": norm(artist),
            "ntitle": norm(title),
            "key": (norm(artist) + " " + norm(title)).strip(),
        })
    return lib


def duration_gap(track, item):
    """Diferenca de duracao em segundos, ou None se algum lado nao informa."""
    if not track.get("duration") or not item.get("duration"):
        return None
    return abs(track["duration"] - item["duration"])


def dur_warning(track, item):
    """Aviso quando o arquivo local tem duracao bem diferente da faixa do Spotify.

    Artista e titulo iguais com duracao diferente quase sempre significa que voce
    tem OUTRA versao: radio edit no lugar do extended, ao vivo no lugar do estudio.
    Nao descartamos o casamento (voce perderia uma faixa que possui), mas avisamos,
    porque num set a diferenca entre um edit de 3 min e um extended de 7 min e
    justamente o que quebra a mixagem.
    """
    gap = duration_gap(track, item)
    if gap is None or gap <= DURATION_TOLERANCE:
        return ""
    return "versao diferente? spotify {}s vs local {}s".format(
        track["duration"], item["duration"])


def match(track, lib, index):
    """Casa uma faixa do Spotify -> (item, confianca, metodo, aviso)."""
    ntitle = norm(track["title"])
    nartist = norm(track["artist"])
    key = (nartist + " " + ntitle).strip()

    hit = index.get(key)
    if hit:
        warn = dur_warning(track, hit)
        # Confianca cai quando a duracao destoa, mesmo com artista e titulo iguais
        return hit, (0.80 if warn else 1.0), "exato", warn

    # Titulo identico e um dos artistas bate (cobre faixas com varios artistas)
    if ntitle:
        for item in lib:
            if item["ntitle"] == ntitle:
                if nartist and (nartist in item["nartist"] or item["nartist"] in nartist):
                    warn = dur_warning(track, item)
                    return item, (0.78 if warn else 0.95), "titulo+artista", warn

    # Aproximado: aqui a duracao e criterio de corte, nao apenas aviso. Sem
    # artista nem titulo batendo, uma duracao destoante torna o palpite fraco.
    best, best_score = None, 0.0
    for item in lib:
        score = difflib.SequenceMatcher(None, key, item["key"]).ratio()
        if score > best_score:
            best, best_score = item, score

    if best and best_score >= FUZZY_THRESHOLD:
        gap = duration_gap(track, best)
        if gap is not None and gap > DURATION_TOLERANCE:
            return None, best_score, "duracao divergente", ""
        return best, best_score, "aproximado", ""

    return None, best_score, "nao encontrado", ""


# --- Spotify: leitura de playlists ------------------------------------------

def playlist_id(ref):
    """Aceita URL, URI spotify: ou ID puro."""
    ref = ref.strip()
    m = re.search(r"playlist[/:]([A-Za-z0-9]+)", ref)
    return m.group(1) if m else ref


def fetch_tracks(token, pid):
    """Le todas as faixas, seguindo a paginacao."""
    if pid == "__liked__":
        url = API + "/me/tracks"
        name = "Curtidas"
    else:
        meta = api_get(token, "/playlists/{}".format(pid), fields="name")
        name = meta.get("name") or pid
        url = API + "/playlists/{}/tracks".format(pid)

    tracks = []
    page = api_get(token, url, limit=50)
    while True:
        for entry in page.get("items", []):
            t = entry.get("track") or {}
            if not t or t.get("is_local") or not t.get("name"):
                continue
            tracks.append({
                "title": t["name"],
                "artist": ", ".join(a["name"] for a in t.get("artists", [])),
                "album": (t.get("album") or {}).get("name", ""),
                "duration": round((t.get("duration_ms") or 0) / 1000),
                "isrc": (t.get("external_ids") or {}).get("isrc", ""),
                "url": (t.get("external_urls") or {}).get("spotify", ""),
            })
        nxt = page.get("next")
        if not nxt:
            break
        print("  ...{} faixas lidas".format(len(tracks)))
        page = api_get(token, nxt)
    return name, tracks


# --- Saida -------------------------------------------------------------------

def safe_name(text):
    return re.sub(r"[<>:\"/\\|?*]+", "_", text).strip() or "playlist"


def write_outputs(name, results, outdir):
    outdir.mkdir(parents=True, exist_ok=True)
    base = safe_name(name)
    found = [r for r in results if r["location"]]
    missing = [r for r in results if not r["location"]]

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

    miss = outdir / (base + "_faltando.csv")
    with miss.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=cols, extrasaction="ignore")
        w.writeheader()
        w.writerows(missing)

    return m3u, full, miss, len(found), len(missing)


# --- Main --------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(
        description="Exporta playlists do Spotify para o Mixxx (apenas metadados).")
    ap.add_argument("playlist", nargs="?", help="URL, URI ou ID da playlist")
    ap.add_argument("--client-id", default=os.environ.get("SPOTIFY_CLIENT_ID"),
                    help="Client ID do seu app no Spotify Developer Dashboard")
    ap.add_argument("--login", action="store_true", help="Autoriza e salva o token")
    ap.add_argument("--list", action="store_true", help="Lista suas playlists")
    ap.add_argument("--liked", action="store_true", help="Usa suas Musicas Curtidas")
    ap.add_argument("--out", default="./playlists", help="Pasta de saida")
    args = ap.parse_args()

    if args.login:
        if not args.client_id:
            raise SystemExit("Informe --client-id (ou defina SPOTIFY_CLIENT_ID).")
        login(args.client_id)
        return

    token = get_token(args.client_id)

    if args.list:
        page = api_get(token, "/me/playlists", limit=50)
        print("{:>7}  NOME".format("FAIXAS"))
        while True:
            for p in page.get("items", []):
                print("{:>7}  {}".format(p["tracks"]["total"], p["name"]))
                print("{:>9}{}".format("", p["external_urls"]["spotify"]))
            if not page.get("next"):
                break
            page = api_get(token, page["next"])
        return

    if not args.playlist and not args.liked:
        raise SystemExit(
            "Informe a playlist, ou use --liked, ou --list para ver as suas.")

    pid = "__liked__" if args.liked else playlist_id(args.playlist)

    print("Lendo o Spotify...")
    name, tracks = fetch_tracks(token, pid)
    print("Playlist '{}': {} faixas.".format(name, len(tracks)))
    if not tracks:
        raise SystemExit("Playlist vazia.")

    print("Lendo a biblioteca do Mixxx...")
    lib = load_mixxx_library()
    print("Biblioteca do Mixxx: {} faixas.".format(len(lib)))
    if not lib:
        print("\nAVISO: sua biblioteca do Mixxx esta vazia, entao nada vai casar.")
        print("Adicione sua pasta de musicas no Mixxx em:")
        print("  Preferencias > Biblioteca > Diretorios de musica > Adicionar")
        print("Os CSVs ainda serao gerados, com tudo marcado como faltando.\n")

    index = {item["key"]: item for item in lib}

    results = []
    for t in tracks:
        item, score, how, warn = match(t, lib, index)
        r = dict(t)
        r["location"] = item["location"] if item else ""
        r["confianca"] = "{:.2f}".format(score)
        r["metodo"] = how
        r["aviso"] = warn
        r["status"] = "encontrada" if item else "faltando"
        results.append(r)

    m3u, full, miss, n_found, n_miss = write_outputs(name, results, Path(args.out))

    total = len(results)
    pct = (n_found / total * 100) if total else 0
    print("\nEncontradas: {}/{} ({:.0f}%)   Faltando: {}".format(
        n_found, total, pct, n_miss))

    suspeitas = [r for r in results if r["aviso"]]
    if suspeitas:
        print("\nConfira estas {} faixa(s) - a duracao nao bate, provavelmente"
              " voce tem outra versao:".format(len(suspeitas)))
        for r in suspeitas:
            print("  {} - {}\n      {}".format(r["artist"], r["title"], r["aviso"]))

    print("\n  {}\n  {}\n  {}".format(m3u, full, miss))
    if n_found:
        print("\nPara importar no Mixxx: arraste o arquivo .m3u8 para a janela do")
        print("Mixxx, ou use o menu Arquivo > Carregar playlist.")


if __name__ == "__main__":
    main()
