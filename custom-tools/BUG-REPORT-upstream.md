# Bug report para o upstream do Mixxx

Cole o conteúdo abaixo em <https://github.com/mixxxdj/mixxx/issues/new/choose>
(escolha *Bug Report*). O texto está em inglês, que é a língua do projeto.

> **Antes de enviar:** o `AGENTS.md` do Mixxx exige que texto gerado por IA venha
> marcado como tal, no início e no fim. Os marcadores já estão incluídos. Se você
> reescrever o relato com suas palavras, pode removê-los — mas não remova se for
> colar como está.

---

## Título sugerido

```
Adding any unused member to the Library class causes reproducible startup crashes (heap corruption) on Windows
```

---

## Corpo do relato

<!-- COPIE A PARTIR DAQUI -->

> ⚠️ *The text in this issue was written by an AI agent (Claude) working on the
> reporter's machine. The reporter reviewed it and reproduced the results.*

### Summary

On `main` (2.7.0-alpha), adding a **completely unused member** to the `Library`
class makes Mixxx crash on startup. The same build without that member starts
cleanly every time.

The crash is intermittent and its rate depends on the exact layout: two variants
of the same inert field gave 8 crashes out of 8 and 4 out of 8 respectively,
while the unmodified build gave 0 out of 12.

Since the added member is never read or written, this cannot be caused by
behaviour. It points to a **latent memory corruption** whose effect depends on
object layout: some write out of bounds only becomes fatal depending on where
objects land in memory.

### Steps to reproduce

1. Build `main` (commit `4e34154f92`) on Windows with MSVC.
2. Confirm it starts reliably (I ran 12 launches, no crash).
3. Apply this patch — the field is never used anywhere:

```diff
--- a/src/library/library.h
+++ b/src/library/library.h
@@
+    char m_padExperiment[512];  // inert: only takes up space
     std::unique_ptr<ControlObject> m_pKeyNotation;
```

```diff
--- a/src/library/library.cpp
+++ b/src/library/library.cpp
@@
+    memset(m_padExperiment, 0, sizeof(m_padExperiment));
+
     qRegisterMetaType<LibraryRemovalType>("LibraryRemovalType");
```

4. Rebuild and launch Mixxx repeatedly.

### Result

| Build | Crashes |
| --- | --- |
| `main`, unmodified | 0 out of 12 |
| `main` + inert field (variant A) | **8 out of 8** |
| `main` + inert field (variant B, the patch above) | **4 out of 8** |

Each launch was: start Mixxx, wait ~10 s, close it. Crashes happen during
startup, before the window is usable.

The two variants differ only in where the field sits among the other members,
which is itself evidence that layout — not behaviour — is what matters here. If
the patch above does not crash for you on the first few launches, try a dozen,
and try moving the field to a different position in the class.

### Why this looks like memory corruption

- **The faulting module changes between runs**: `Qt6Core.dll`, `ntdll.dll`,
  `Qt6Sql.dll` and `mixxx.exe` itself.
- **Exception codes vary**, including `0xc0000374` (heap corruption) and
  `0xc0000005` (access violation).
- **The log stops at different points** across runs — after the database driver
  is listed in some, during HID device enumeration in others.

All three are typical of a write past the end of a buffer: the damage is done
early and only surfaces later, somewhere unrelated.

### What I could rule out

- **Not the field's contents or name.** A `ControlObject` with an arbitrary name
  produces the same effect; so does a plain `char` array that is never touched.
- **Not a specific feature.** The field does nothing at all.
- **Not the hardware setup.** Reproduced with a DDJ-FLX4 both connected and
  disconnected.

### I tried AddressSanitizer, and it does not catch this

Worth reporting so nobody repeats the attempt. MSVC 2022 does support
`/fsanitize=address` and ships the runtime, so an instrumented build is possible
even though `CMakeLists.txt` rejects sanitizers outright under MSVC:

```
message(FATAL_ERROR "Sanitizers are only available on Clang or GCC")
```

Passing the flag through `CMAKE_CXX_FLAGS` works, with two caveats: the Visual
Studio generator needs `CMAKE_CONFIGURATION_TYPES` pinned to one config (the WiX
packaging step fails otherwise), and `QML=OFF` is required — MSVC hits an
internal compiler error (C1001) on `mixxx-qml-lib_autogen` with ASan on.

**The resulting build does not reproduce the crash.** With the inert field
applied and ASan active, 4 out of 4 launches reached the full UI and exited
cleanly, and ASan reported nothing. The likely reason is that ASan's redzones
change the very object layout this bug depends on, so instrumenting it hides it.

One report does appear, and it is a **false positive**: a `container-overflow`
inside `Waveform::readByteArray` (`src/waveform/waveform.cpp:161`) through
`protobuf::RepeatedField<float>::GrowNoAnnotate`. `container-overflow` requires
every module to be instrumented, and `libprotobuf-lite.dll` comes prebuilt from
vcpkg. It disappears with `detect_container_overflow=0`, and no real error takes
its place.

So the next step is probably **not** ASan. Windows PageHeap under a debugger, or
a Linux build with ASan where the dependencies are instrumented too, look more
promising. I don't have the Debugging Tools installed on this machine.

### Environment

| | |
| --- | --- |
| Mixxx | 2.7.0-alpha, commit `4e34154f92` |
| OS | Windows 11 Home Single Language, build 26200 |
| Compiler | MSVC 14.44.35207 (VS Build Tools 17.14.39) |
| Qt | 6.10.3 |
| Dependencies | `mixxx-deps-2.7-x64-windows-1c20f84a` |
| Build type | RelWithDebInfo |
| Library size | 674 tracks, 1220 analyses |

### It is not only the Library class

I first hit this while adding a field to `Library`. It also happens in
`SoundManagerConfig`: adding a single `QStringList` member there — **declared and
never used anywhere** — produced 8 crashes out of 8, the same as the inert array
in `Library`.

That has a practical cost beyond the crash itself. I was writing a fix for a
separate, real problem: Mixxx drops any sound device that is absent when the
config is read (`if (devicesMatchingByName == 0) { continue; }` in
`soundmanagerconfig.cpp`) and rewrites the file without it, so opening Mixxx once
with a controller unplugged permanently erases its output routing. My fix
preserved the absent device's XML and restored it on write, skipping any audio
path already claimed by a present device. **It worked** — the absent
device's configuration survived an open/close cycle. But it needs one new member
on `SoundManagerConfig`, and that alone makes Mixxx crash on startup.

So this bug is not just a nuisance: it currently blocks fixing other bugs.

### Why this matters

Any change that alters the size or layout of `Library` — adding a control, a
pointer, a member of any kind — can make Mixxx unstable for reasons unrelated to
the change itself. That makes the bug easy to misattribute: while working on
unrelated features I first blamed my own code, and only found the real cause
after reverting everything and testing the inert field.

> ⚠️ *End of AI-generated text.*

<!-- COPIE ATÉ AQUI -->
