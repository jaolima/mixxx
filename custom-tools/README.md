# custom-tools

Ferramentas próprias deste fork. Nada aqui vem do upstream do Mixxx.

## mixxx_preset.py

Troca o conjunto de configurações do Mixxx conforme o estilo que você vai tocar.
Hip hop e house querem ajustes **opostos**, e são seis opções espalhadas por
telas diferentes das Preferências — este script troca tudo de uma vez.

Funciona em **Windows, Linux e macOS**, só com a biblioteca padrão do Python.

```shell
python mixxx_preset.py                    # abre a janela de seleção
python mixxx_preset.py --status           # imprime a config atual
python mixxx_preset.py hiphop             # aplica direto, sem janela
python mixxx_preset.py house --no-launch  # aplica sem abrir o Mixxx
```

Sem argumentos, abre uma janela com os presets, uma tabela **Agora → Depois**
(as linhas que mudam ficam destacadas) e a justificativa de cada ajuste, para
você conferir antes de aplicar. A janela usa tkinter; em algumas distribuições
Linux ele vem separado (`sudo apt install python3-tk`), e sem ele o modo texto
continua funcionando.

Caminhos detectados automaticamente: `%LOCALAPPDATA%\Mixxx` no Windows,
`~/.mixxx` no Linux (o Mixxx não usa XDG — ver `MIXXX_SETTINGS_PATH` no
CMakeLists.txt) e `~/Library/Application Support/Mixxx` no macOS.

| Ajuste | `hiphop` | `house` | Por quê |
| --- | --- | --- | --- |
| quantize (decks) | OFF | ON | grade é imprecisa em hip hop/reggae; em house é confiável |
| pitch range | ±16% | ±8% | 85→100 BPM exige alcance; house pede passo fino |
| keylock | OFF | ON | vinil sobe o tom; house mantém |
| tempo na análise | variável | fixo | hip hop/reggae oscila; house é feito no clique |
| BPM do relógio interno | 90 | 124 | ponto de partida de cada estilo |
| motor do keylock | RubberBand | RubberBand | igual de propósito — ver abaixo |

O **motor do keylock** fica em RubberBand nos dois presets. Ele tem qualidade
melhor que o SoundTouch e só custa CPU quando o keylock está ligado, então
rebaixá-lo no preset de hip hop (onde o keylock fica desligado) seria perda sem
ganho. É também o padrão do Mixxx quando compilado com RubberBand, que é o caso
deste build — ver `defaultKeylockEngine()` em `src/engine/enginebuffer.h`.

**Por que o script sempre fecha o Mixxx antes de gravar:** o Mixxx mantém essas
opções em memória e **reescreve o `mixxx.cfg` inteiro ao sair**. Editar o arquivo
com ele aberto — ou passar pelas Preferências depois — desfaz a alteração. Foi
exatamente assim que um ajuste manual anterior se perdeu.

Cada aplicação salva `mixxx.cfg.bak-preset` antes de gravar.

**Nota sobre "tempo na análise":** vale só para análises **novas**. Faixas já
analisadas mantêm a grade que têm até você reanalisá-las.

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
