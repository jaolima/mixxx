# custom-tools

Ferramentas próprias deste fork. Nada aqui vem do upstream do Mixxx.

> **O que saiu daqui:** os scripts de configuração (`mixxx_preset.py` e
> `mixxx_config.py`) foram aposentados quando viraram código nativo. As opções,
> os presets por estilo e os perfis de áudio agora vivem em
> **Preferências → Essentials**, dentro do próprio Mixxx.

## spotify_to_mixxx.py

Exporta playlists do Spotify para o Mixxx, casando cada faixa com os arquivos
que você já tem na biblioteca.

### Por que não toca o áudio do Spotify

O Spotify não expõe áudio decodificado em nenhuma API atual (o Web Playback SDK
toca sob DRM e nunca entrega o PCM), e os termos de desenvolvedor proíbem mixar
ou alterar o áudio — foi por isso que, em julho de 2020, todos os apps de DJ
perderam a integração. Esta ferramenta usa **apenas metadados**, que é permitido.

### Configuração (uma vez)

1. Acesse <https://developer.spotify.com/dashboard> e clique em **Create app**.
2. Preencha nome e descrição livremente.
3. Em **Redirect URI**, use exatamente:

   ```
   http://127.0.0.1:8888/callback
   ```

   Precisa ser `127.0.0.1`, não `localhost` — o Spotify rejeita `localhost`.
4. Em **APIs used**, marque **Web API**.
5. Salve, abra **Settings** e copie o **Client ID** (o *Client Secret* não é
   necessário: usamos PKCE).
6. Autorize uma vez:

   ```powershell
   python spotify_to_mixxx.py --login --client-id SEU_CLIENT_ID
   ```

O token fica em `%LOCALAPPDATA%\MixxxSpotify\token.json` e é renovado sozinho.

### Uso

```powershell
python spotify_to_mixxx.py --list                    # suas playlists
python spotify_to_mixxx.py <url-da-playlist>         # exporta uma playlist
python spotify_to_mixxx.py --liked                   # suas Músicas Curtidas
python spotify_to_mixxx.py <url> --out D:\sets       # escolhe a pasta de saída
```

### Saída

| Arquivo | Conteúdo |
| --- | --- |
| `<nome>.m3u8` | Playlist com os arquivos que você tem. Arraste para o Mixxx. |
| `<nome>_faltando.csv` | O que não foi encontrado — sua lista de compras. |
| `<nome>_completo.csv` | Tudo, com confiança e método de cada casamento. |

### Como o casamento funciona

Compara artista e título normalizados (sem acento, sem pontuação, sem sufixos
como `- Remastered 2011` ou `(feat. …)`), em três níveis:

| Método | Confiança | Quando |
| --- | --- | --- |
| `exato` | 1.00 | artista + título batem |
| `titulo+artista` | 0.95 | título bate e um dos artistas bate |
| `aproximado` | ≥ 0.87 | similaridade alta, confirmada pela duração |

**Coluna `aviso`:** quando artista e título batem mas a duração destoa em mais
de 8 s, a faixa é casada mesmo assim (descartar faria você perder música que
possui) e recebe um aviso — quase sempre significa que você tem outra versão,
tipo radio edit no lugar do extended. Confira essas antes do set.

### Requisito

A biblioteca do Mixxx precisa estar populada, senão nada casa. No Mixxx:
**Preferências → Biblioteca → Diretórios de música → Adicionar**, e deixe a
varredura terminar.

## deezer_to_mixxx.py

O mesmo para o Deezer, com duas diferenças a favor: **não precisa de login**
(a API do Deezer serve playlists públicas sem OAuth, client id ou token) e a
lista do que falta já sai com os **links de compra prontos**.

### Uso

```powershell
python deezer_to_mixxx.py https://www.deezer.com/br/playlist/1234567
python deezer_to_mixxx.py 1234567 --outdir D:\sets
python deezer_to_mixxx.py --list <id-ou-url-do-seu-perfil>   # descobre os IDs
```

### Saída

| Arquivo | Conteúdo |
| --- | --- |
| `<nome>.m3u8` | Playlist com os arquivos que você tem. Arraste para o Mixxx. |
| `<nome>_completo.csv` | Tudo, com confiança e método de cada casamento. |
| `<nome>_faltando.csv` | O que falta, com uma coluna de link por loja. |
| `<nome>_comprar.html` | A mesma lista, para abrir no navegador e clicar. |

Busca em Beatport, Traxsource, Juno, Bandcamp, Apple Music e Amazon.

### Por que não baixa o áudio

O Deezer entrega apenas metadados e um trecho de 30 s. Baixar as faixas
completas exigiria burlar a proteção do serviço — é infração de direitos
autorais e, num software destinado à venda, um risco jurídico direto ao
negócio. Por isso a saída é uma lista de compras, não um downloader.

### Recuperação de metadado (o que este faz e o do Spotify ainda não)

Metade de uma biblioteca real costuma vir de download: o campo artista fica
vazio e o título carrega tudo junto, com o id do vídeo colado no fim —
`JOPLYN - Can't Get Enough (Adana Twins Remix) [pNEuK4ZRtvk]`. Comparado assim,
**nada casa**, e a lista de compras manda comprar o que você já tem.

`enrich_library()` deriva chaves adicionais desses nomes: remove o id do vídeo,
o ruído de clipe (`(Lyric Video)`, `Video Clipe Oficial`, `[HD]`), a hashtag de
canal e o `feat. Fulano` sem parênteses, e separa `Artista - Título` quando o
campo artista está vazio. As chaves originais **nunca são descartadas** — só
somamos tentativas, então o tratamento pode melhorar o resultado, nunca piorar.

Medido nesta biblioteca (674 faixas, 85 % com sufixo de download), sobre faixas
reais buscadas no Deezer de artistas que o acervo comprovadamente tem:

| | encontradas |
| --- | --- |
| sem o tratamento | 0 de 12 |
| com o tratamento | 6 de 12 |

As 6 restantes são versões genuinamente diferentes (outro remix, versão de DJ) —
não devem casar mesmo. Verificado que não surgem falsos positivos: uma playlist
de sertanejo contra este acervo continua dando 0 de 50.

Vale portar `enrich_library()` para o `spotify_to_mixxx.py`, que ainda usa só a
chave crua.
