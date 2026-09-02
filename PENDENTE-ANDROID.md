# Pendências do Android — o que depende de hardware

Branch `android`. Este arquivo existe porque duas perguntas do projeto **não podem
ser respondidas por software**, e é fácil esquecer que elas seguem em aberto
enquanto o resto avança.

## Pendente: comprar o adaptador

**Adaptador OTG USB-C (macho) → USB-A (fêmea)**, ~R$ 20. Usa o cabo que já veio
com a FLX4.

O hub OTG **com fonte externa** (~R$ 100-200) só se justifica depois, para tocar
de verdade: num set de duas horas a controladora drena a bateria do celular, e
com fonte externa ele até carrega enquanto toca. Para medir, o adaptador basta.

## Pendente: os dois testes de hardware

Ainda **não foram feitos**. O que sabemos hoje veio de vídeos e da documentação
da Pioneer — que descreve a FLX4 funcionando com **o app da própria Pioneer**,
possivelmente com driver proprietário. Não é a mesma pergunta que "o Android
genérico expõe isto".

Enquanto não forem feitos, os riscos **R1** e **R4** do plano seguem abertos.

### Preparação

1. Carregar o celular (OTG com bateria baixa causa desconexão aleatória, que
   imita defeito de software).
2. **Ligar o Wi-Fi** do celular na mesma rede do PC. O S24 Ultra tem uma única
   porta USB-C: com o cabo do PC nela, não há como conectar a FLX4. A saída é
   passar o `adb` para wireless e liberar a porta.

### Teste 1 — o Android enxerga o MIDI da FLX4?

Conectar a FLX4 pelo adaptador OTG e ler:

```
adb shell dumpsys midi
```

Aparecendo a controladora, a ponte MIDI (Fase 2) é viável como planejada. Não
aparecendo, **R4** se materializou e o caminho passa a ser libusb — bem mais
caro.

### Teste 2 — quantos canais de áudio o Android expõe?

```
adb shell dumpsys audio
```

Esta é **a medição que decide o formato do produto**:

- **4 canais ou mais** — master no RCA da controladora e pré-escuta no fone
  dela. Dá para mixar de verdade.
- **2 canais** — o Android expõe a placa como estéreo simples. Dá para controlar,
  não dá para fazer cue no fone. **R1** materializado; decidir entre as
  alternativas antes de investir os 10-20 dias da ponte MIDI.

Vale medir também a latência de saída, testando de 5 a 20 ms e anotando a menor
que aguente dez minutos sem falha.

### Por que a resposta deste aparelho vale como geral

O S24 Ultra declara `android.hardware.audio.pro` — a certificação de áudio
profissional do Google, que exige latência de ida e volta abaixo de 20 ms e
suporte a USB Audio Class. Se os quatro canais não aparecerem nele, não vão
aparecer em aparelho nenhum.

## Já resolvido, para não refazer

| | |
| --- | --- |
| Ubuntu 24.04 no WSL2 | o build exige host Linux (`CMakeLists.txt:79`) |
| NDK 27.2 · SDK android-35 · deps arm64 | via `tools/android_buildenv.sh setup` |
| Bloqueio de WSL no CMakeLists | corrigido no commit `1b218f48ba` |
| Libs X11 (`libsm6`, `libice6`, …) | as ferramentas host do Qt não rodam sem elas |
| APK arm64 assinado e instalado | abre na interface QML |
| Permissões de armazenamento | concedidas via `adb`, inclusive a especial |

Compilar sempre com **`LILV=OFF`**: o bug de 1 byte do lilv derruba o Mixxx de
forma aleatória, e no Android faltariam as ferramentas que usamos para achá-lo
no Windows. Ver `custom-tools/BUG-REPORT-upstream.md`.

## Receita do build

```bash
# no WSL, com o fork clonado em ~/mixxx (dentro do FS do Linux, nunca /mnt/c)
cd ~/mixxx
source tools/android_buildenv.sh setup

cmake -S . -B build \
  -DCMAKE_TOOLCHAIN_FILE=$MIXXX_VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake \
  -DCMAKE_SYSTEM_NAME=Android \
  -DVCPKG_TARGET_TRIPLET=arm64-android \
  -DQT6=ON -DQML=ON -DHID=ON -DBULK=ON \
  -DBUILD_TESTING=OFF -DBUILD_BENCH=OFF \
  -DLILV=OFF

cmake --build build -j$(nproc)

# assinar (o APK sai sem assinatura)
BT=$(ls -d /usr/lib/android-sdk/build-tools/* | tail -1)
$BT/zipalign -f -p 4 build/android-build/build/outputs/apk/release/android-build-release-unsigned.apk /tmp/a.apk
$BT/apksigner sign --ks ~/mixxx-debug.keystore --ks-pass pass:mixxxdev --key-pass pass:mixxxdev --out ~/mixxx-custom.apk /tmp/a.apk
```
