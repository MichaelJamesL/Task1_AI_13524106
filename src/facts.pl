/* ============================================================
 * facts.pl - Fakta statis & rumus game Loop Hero (PoC)
 * Tabel class, tile, gear, boss + rumus damage/EXP/skor.
 * Data musuh dimuat dari config/enemies.txt (lihat fileio.pl).
 * ============================================================ */

/* ---------- Deklarasi predikat dinamis (state game) ---------- */
:- dynamic(enemy/5).        /* enemy(Type, HP, ATK, DEF, Exp) - dari config */
:- dynamic(hero/8).         /* hero(Name, Class, Level, Exp, HP, MaxHP, ATK, DEF) */
:- dynamic(loop_tiles/1).   /* list 24 atom tile */
:- dynamic(enemies/1).      /* list 24 atom musuh (none | tipe musuh) */
:- dynamic(hero_pos/1).     /* indeks 0..23 */
:- dynamic(day/1).
:- dynamic(hand/1).         /* list atom tile di tangan (maks 5) */
:- dynamic(placed_count/1).
:- dynamic(potions/1).
:- dynamic(kills/1).
:- dynamic(loops_done/1).
:- dynamic(boss_spawned/1). /* 0 | 1 */
:- dynamic(in_battle/1).    /* 0 | 1 */
:- dynamic(battle_enemy/5). /* battle_enemy(Type, HP, MaxHP, ATK, DEF) */
:- dynamic(equipped/3).     /* equipped(Slot, Tier, Val) */
:- dynamic(defend_up/1).    /* 0 | 1 */
:- dynamic(game_over/1).    /* 0 | 1 */
:- dynamic(run_started/1).  /* 0 | 1 */
:- dynamic(lich_round/1).   /* counter ronde untuk Arcane Bolt */

/* ---------- Class hero: class(Name, HP, ATK, DEF, TraitDesc) ---------- */
class(warrior,     100, 12, 8, 'Regenerasi 2% MaxHP setiap langkah').
class(rogue,        80, 16, 5, '15% peluang menyerang dua kali').
class(necromancer,  90, 10, 6, 'Mendapat 25% EXP tambahan').

class_skill(warrior,     'Power Strike').
class_skill(rogue,       'Backstab').
class_skill(necromancer, 'Soul Rend').

/* ---------- Simbol peta ---------- */
symbol(campfire,        'C').
symbol(wasteland,       '.').
symbol(rock,            'R').
symbol(meadow,          'M').
symbol(mountain,        'T').
symbol(vampire_mansion, 'V').
symbol(cemetery,        'G').
symbol(battlefield,     'B').
symbol(village,         'L').
symbol(ruins,           'U').

foe_symbol(none,     ' ').
foe_symbol(slime,    's').
foe_symbol(skeleton, 'k').
foe_symbol(ratwolf,  'r').
foe_symbol(harpy,    'h').
foe_symbol(vampire,  'v').
foe_symbol(gargoyle, 'g').
foe_symbol(lich,     'Z').

/* ---------- Nama tampilan ---------- */
display_name(slime,    'Slime').
display_name(skeleton, 'Skeleton').
display_name(ratwolf,  'Ratwolf').
display_name(harpy,    'Harpy').
display_name(vampire,  'Vampire').
display_name(gargoyle, 'Gargoyle').
display_name(lich,     'Lich').
display_name(rock,            'Rock').
display_name(meadow,          'Meadow').
display_name(mountain,        'Mountain').
display_name(vampire_mansion, 'Vampire Mansion').
display_name(cemetery,        'Cemetery').
display_name(battlefield,     'Battlefield').
display_name(village,         'Village').
display_name(ruins,           'Ruins').

/* ---------- Jadwal spawn: spawns_from(Tile, Enemy, EveryNDays) ---------- */
spawns_from(cemetery,        skeleton, 3).
spawns_from(battlefield,     ratwolf,  2).
spawns_from(mountain,        harpy,    4).
spawns_from(vampire_mansion, vampire,  2).
spawns_from(ruins,           gargoyle, 3).

/* ---------- Boss: boss(Name, HP, ATK, DEF, ExpGiven) ---------- */
boss(lich, 200, 20, 10, 200).   /* summon 2 skeletal guard hanya flavor text */

/* ---------- Gear: slot(Slot, StatAffected) ---------- */
slot(sword,  'ATK').
slot(shield, 'DEF').
slot(armor,  'MaxHP').
slot(ring,   'Vampirism%').

/* tier(Tier, MinVal, MaxVal) */
tier(common, 1, 3).
tier(magic,  4, 7).
tier(rare,   8, 12).

/* ---------- Efek tile saat dipasang ---------- */
place_bonus(rock,     2).   /* +MaxHP */
place_bonus(mountain, 8).   /* +MaxHP */

/* ---------- Tile yang punya efek saat dimasuki ----------
   stop_tile(Tile) : fast-forward (autoStep/step(N)/stepTo) berhenti di sini.
   Tile lain hanya berefek saat dipasang atau saat pagi hari, jadi dilewati. */
stop_tile(village).

/* ---------- Rumus ---------- */

/* Damage = max(1, ATK - DEF) */
compute_damage(ATK, DEF, Dmg) :-
    Dmg0 is ATK - DEF,
    (Dmg0 < 1 -> Dmg = 1 ; Dmg = Dmg0).

/* EXP yang dibutuhkan untuk naik dari Level */
exp_needed(Level, Need) :-
    Need is 15 * Level.

/* Kenaikan stat per level: HP+5, ATK+2, DEF+1 */
level_gain(HPGain, ATKGain, DEFGain) :-
    HPGain = 5, ATKGain = 2, DEFGain = 1.

/* Skor akhir run */
compute_score(Loops, Placed, Kills, Level, Score) :-
    Score is 100 * Loops + 10 * Placed + 5 * Kills + 20 * Level.

/* Peluang drop (persen) */
gear_drop_chance(40).
potion_drop_chance(20).
tile_drop_chance(35).

/* ---------- RNG sendiri (LCG) supaya bisa di-seed deterministik ---------- */
:- dynamic(rng_state/1).

/* rand_seed(+S) : set seed (dipakai juga untuk demo yang reproducible) */
rand_seed(S) :-
    retractall(rng_state(_)),
    assertz(rng_state(S)).

/* rand_int(+N, -X) : X integer acak dalam [0, N) - LCG Numerical Recipes,
   ambil 16 bit tinggi supaya distribusi untuk N kecil lebih merata */
rand_int(N, X) :-
    rng_state(S),
    S1 is (S * 1664525 + 1013904223) mod 4294967296,
    retractall(rng_state(_)),
    assertz(rng_state(S1)),
    X is (S1 // 65536) mod N.
