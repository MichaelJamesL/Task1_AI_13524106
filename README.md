# Task1_AI_13524106 — Loop Hero! (Proof of Concept)

Proof of concept untuk **Task #1 Seleksi Laboratorium Intelegensi Buatan**:
rancangan spesifikasi Tugas Besar IF1221 Logika Komputasional bertema
**Loop Hero** diimplementasikan sebagian fitur utamanya menggunakan **GNU Prolog**.

Dokumen spesifikasi lengkap ada di [`doc/spec.pdf`](doc/spec.pdf).

## Deskripsi Singkat

Sang hero berjalan mengelilingi **loop 24 petak** secara otomatis. Pemain tidak
menggerakkan hero secara langsung; strategi pemain adalah **memasang tile**
(Rock, Meadow, Mountain, Vampire Mansion, Cemetery, Battlefield, Village, Ruins)
yang memperkuat hero sekaligus memunculkan musuh baru. Dua ekor slime sudah
menanti di loop sejak awal permainan, dan slime baru berpeluang 5% muncul setiap
langkah. Setiap tile yang dipasang mendekatkan kebangkitan **Lich** — pasang 10
tile, lalu kalahkan dia untuk mematahkan kutukan. HP hero habis = run berakhir;
`retreat` = pulang dengan skor.

## Requirements

- **GNU Prolog** (diuji dengan GNU Prolog 1.5.0 64-bit di Windows).
  Jika `gprolog` tidak ada di PATH, gunakan path penuh, misalnya
  `C:\GNU-Prolog\bin\gprolog.exe`.

## Cara Menjalankan

Jalankan dari dalam folder `src` (file konfigurasi dibaca relatif dari sana):

```bash
cd src
gprolog --consult-file main.pl
```

Lalu di prompt `| ?-`:

```prolog
startGame.
```

Program akan meminta nama dan pilihan class — **akhiri setiap input dengan titik**
(contoh: `budi.` lalu `1.`).

Alternatif tanpa prompt input (berguna untuk demo/skrip):

```prolog
startGameAs(budi, warrior).
```

Class yang tersedia: `warrior`, `rogue`, `necromancer`.

## Daftar Command

| Grup | Command | Deskripsi |
| --- | --- | --- |
| Mulai | `startGame.` | Mulai interaktif (input nama & class) |
| | `startGameAs(Nama, Class).` | Mulai langsung tanpa prompt |
| Umum | `showLoop.` | Tampilkan peta loop, hari, tile, kill |
| | `showHero.` | Tampilkan status hero & gear |
| | `showHand.` | Tampilkan tile di tangan (+indeks) |
| | `showBag.` | Tampilkan potion & gear |
| | `help.` | Daftar command + legenda simbol |
| Loop | `step.` | Hero maju 1 petak searah jarum jam |
| | `autoStep.` | Lompat ke petak berarti berikutnya (lihat di bawah) |
| | `step(N).` | Maju maksimal `N` petak, berhenti bila ada kejadian |
| | `stepTo(Pos).` | Maju sampai petak `Pos`, berhenti bila ada kejadian |
| | `placeTile(Idx, Pos).` | Pasang tile hand `Idx` ke petak `Pos` |
| | `retreat.` | Akhiri run, catat skor |
| Battle | `attack.` | Serangan biasa (damage = max(1, ATK-DEF)) |
| | `defend.` | Damage masuk berikutnya -30% |
| | `skill.` | Serangan 150% ATK |
| | `usePotion.` | Pulihkan 30% MaxHP |
| File | `saveGame(File).` | Simpan run ke file |
| | `loadGame(File).` | Muat run dari file |
| | `showHighScore.` | 10 skor tertinggi |

Contoh sesi singkat:

```prolog
| ?- startGameAs(budi, warrior).
| ?- placeTile(0, 5).     % pasang Rock di petak 5
| ?- autoStep.            % lompat langsung ke kejadian berikutnya
| ?- attack.              % dalam battle: serang
| ?- saveGame('save1.txt').
| ?- loadGame('save1.txt').
| ?- retreat.
```

## Melangkah Cepat (`autoStep`)

Melewati Wasteland kosong tidak menghasilkan apa pun, jadi `step.` berulang kali
hanya membuang giliran. `autoStep.` menjalankan langkah-langkah itu sekaligus dan
berhenti begitu ada sesuatu yang butuh keputusan pemain:

- **musuh menghadang** — petak tujuan berisi musuh, battle dimulai;
- **tile berefek** — petak punya efek saat dimasuki (Village: heal 20% MaxHP);
- **hari baru** — hero melewati Campfire (petak 0), pergantian hari terjadi;
- **run berakhir** — hero gugur atau permainan selesai.

Semua efek per langkah tetap dihitung satu per satu (regen warrior, peluang spawn
slime 5%, pergantian hari), hanya pesan `Hero melangkah ke petak N.` yang diganti
satu baris ringkasan. Batas amannya satu putaran penuh (24 petak).

```prolog
| ?- autoStep.
>> Hero melaju 9 petak, berhenti di petak 9: musuh menghadang.

!!! Slime liar menghadang! HP: 20/20 | ATK 5 | DEF 1 !!!
Gunakan attack / defend / skill / usePotion.
```

Dua varian dengan kendali lebih rinci — keduanya juga berhenti lebih awal bila ada
kejadian di tengah jalan:

```prolog
| ?- step(5).             % maju maksimal 5 petak
| ?- stepTo(14).          % maju sampai petak 14 (searah jarum jam)
```

`step.` sendiri tetap ada dan tetap berperilaku sama: maju tepat satu petak.

## Penerapan Materi Wajib

| Materi | Implementasi | Lokasi |
| --- | --- | --- |
| Rekurens | `my_nth0/3`, `replace0/4`, `fill_list/3`, `print_tile_line/1`, `heal_from_meadows/4`, `spawn_scheduled_at/3`, `fast_forward/3` (langkah beruntun `autoStep`), `level_up_check/8` (level berantai), `sort_desc/2` & `insert_score/3` (insertion sort high score), `read_enemies/1`, `print_hand/2` | `loop.pl`, `battle.pl`, `fileio.pl`, `main.pl` |
| List | Loop 24 petak (circular, wrap `mod 24`), daftar musuh per petak, hand tile, daftar gear, daftar high score | `loop.pl`, `battle.pl`, `fileio.pl` |
| Cut | `ask_class/1` (input class valid), `placeTile/2` (commit cabang sukses/gagal), `equip_gear/3` (lebih baik vs dibuang), `find_empty_wasteland` via `try_empty_wasteland/2`, `stop_reason/2` (alasan berhenti pertama yang cocok) | `main.pl`, `loop.pl`, `battle.pl` |
| Fail | `attack`/`skill`/`defend` di luar battle, `placeTile` posisi/indeks tidak valid, `stepTo`/`step(N)` argumen tidak valid, `usePotion` saat potion habis, `loadGame` file tidak ada | `battle.pl`, `loop.pl`, `fileio.pl` |
| Loop | `repeat` pada `ask_class/1`, `try_empty_wasteland/2` (percobaan acak berulang), `fast_forward/3` (langkah beruntun sampai kejadian), siklus hari/putaran loop | `main.pl`, `loop.pl` |
| File Processing | Muat data musuh dari `config/enemies.txt`, `saveGame`/`loadGame` (tulis/baca term state), `highscore.txt` (append & baca) | `fileio.pl` |

## Struktur Proyek

```
Task1_AI_13524106/
├── doc/
│   └── spec.pdf          # Spesifikasi (PDF, dengan diagram & gambar)
├── src/
│   ├── main.pl           # Entry point: startGame, command umum, retreat
│   ├── facts.pl          # Tabel class/musuh/tile/gear/boss, rumus, RNG
│   ├── loop.pl           # Circular list, step & fast-forward, spawn, placeTile, boss
│   ├── battle.pl         # Battle turn-based, EXP/level, drop, boss Lich
│   ├── fileio.pl         # Load config, save/load, high score
│   └── config/
│       └── enemies.txt   # Data musuh (dimuat saat start)
└── README.md
```

## Penulis

13524106 — Seleksi Laboratorium Intelegensi Buatan, Task #1
