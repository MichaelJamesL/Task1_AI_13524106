/* ============================================================
 * main.pl - Entry point Loop Hero (PoC Task #1 Seleksi Lab AI)
 * Jalankan dari folder src:  gprolog --consult-file main.pl
 * lalu query:  startGame.
 * ============================================================ */

:- initialization(consult('facts.pl')).
:- initialization(consult('loop.pl')).
:- initialization(consult('battle.pl')).
:- initialization(consult('fileio.pl')).

/* ---------- Reset seluruh state dinamis ---------- */
reset_state :-
    retractall(hero(_,_,_,_,_,_,_,_)),
    retractall(loop_tiles(_)),
    retractall(enemies(_)),
    retractall(hero_pos(_)),
    retractall(day(_)),
    retractall(hand(_)),
    retractall(placed_count(_)),
    retractall(potions(_)),
    retractall(kills(_)),
    retractall(loops_done(_)),
    retractall(boss_spawned(_)),
    retractall(in_battle(_)),
    retractall(battle_enemy(_,_,_,_,_)),
    retractall(equipped(_,_,_)),
    retractall(defend_up(_)),
    retractall(game_over(_)),
    retractall(run_started(_)),
    retractall(lich_round(_)).

/* ---------- Start game ---------- */
startGame :-
    nl,
    write('================================================'), nl,
    write('              L O O P   H E R O !               '), nl,
    write('   Patahkan kutukan Loop. Kalahkan sang Lich.   '), nl,
    write('================================================'), nl, nl,
    write('Masukkan nama hero (akhiri dengan titik, mis. budi.): '),
    read(Name),
    nl,
    write('Pilih class hero:'), nl,
    write('1. Warrior     (HP 100, ATK 12, DEF 8)  - regen 2% MaxHP/langkah'), nl,
    write('2. Rogue       (HP  80, ATK 16, DEF 5)  - 15% double strike'), nl,
    write('3. Necromancer (HP  90, ATK 10, DEF 6)  - +25% EXP'), nl,
    ask_class(Choice),
    class_by_choice(Choice, Class),
    init_game(Name, Class).

/* init_game(+Name, +Class) : inisialisasi state run baru (seed acak dari waktu) */
init_game(Name, Class) :-
    statistics(runtime, [T|_]),
    Seed is T + 1,
    init_game_seed(Name, Class, Seed).

/* init_game_seed(+Name, +Class, +Seed) : init dengan seed deterministik (demo/test) */
init_game_seed(Name, Class, Seed) :-
    reset_state,
    rand_seed(Seed),
    class(Class, HP, ATK, DEF, Trait),
    assertz(hero(Name, Class, 1, 0, HP, HP, ATK, DEF)),
    init_loop,
    initial_enemies,
    assertz(hero_pos(0)),
    assertz(day(1)),
    assertz(loops_done(0)),
    assertz(hand([rock, meadow, village])),
    assertz(placed_count(0)),
    assertz(potions(3)),
    assertz(kills(0)),
    assertz(boss_spawned(0)),
    assertz(in_battle(0)),
    assertz(defend_up(0)),
    assertz(game_over(0)),
    assertz(run_started(1)),
    assertz(lich_round(0)),
    load_config,
    nl,
    format('Selamat datang, ~w sang ~w!~n', [Name, Class]),
    format('Trait: ~w~n', [Trait]),
    write('Pasang 10 tile untuk memancing Lich keluar, lalu kalahkan dia!'), nl,
    write('Ketik help. untuk melihat daftar command.'), nl,
    showLoop.

/* ask_class(-Choice) : loop sampai input valid (repeat + cut + fail) */
ask_class(C) :-
    repeat,
    write('Pilihanmu (1/2/3, akhiri dengan titik): '),
    read(N),
    (member(N, [1,2,3]) -> C = N, !
    ; write('Pilihan tidak valid, coba lagi.'), nl, fail).

class_by_choice(1, warrior).
class_by_choice(2, rogue).
class_by_choice(3, necromancer).

/* startGameAs(+Name, +Class) : mulai langsung tanpa prompt input.
   Berguna untuk skrip/demo. Class: warrior | rogue | necromancer. */
startGameAs(Name, Class) :-
    class(Class, _, _, _, _), !,
    init_game(Name, Class).
startGameAs(_, _) :-
    write('Class tidak dikenal. Pilih: warrior / rogue / necromancer.'), nl, fail.

/* ---------- Command umum ---------- */
showHero :-
    run_started(1), !,
    hero(N,C,Lv,E,HP,MaxHP,_A,_Df),
    hero_atk_total(ATK), hero_def_total(DEF),
    exp_needed(Lv, Need),
    potions(P),
    nl, write('========== HERO =========='), nl,
    format('Nama  : ~w (~w)~n', [N, C]),
    format('Level : ~w (EXP ~w/~w)~n', [Lv, E, Need]),
    format('HP    : ~w/~w~n', [HP, MaxHP]),
    format('ATK   : ~w | DEF: ~w~n', [ATK, DEF]),
    format('Potion: ~w~n', [P]),
    show_gear_line(sword), show_gear_line(shield),
    show_gear_line(armor), show_gear_line(ring).
showHero :-
    write('Permainan belum dimulai. Jalankan startGame. terlebih dahulu.'), nl.

show_gear_line(Slot) :-
    (equipped(Slot, Tier, Val) ->
        format('~w: ~w (~w, +~w)~n', [Slot, Slot, Tier, Val])
    ;   format('~w: (kosong)~n', [Slot])).

showHand :-
    run_started(1), !,
    hand(H),
    nl, write('========== HAND (tile) =========='), nl,
    (H = [] -> write('(kosong - dapatkan tile dari kill/pagi hari)'), nl
    ; print_hand(H, 0)).
showHand :-
    write('Permainan belum dimulai. Jalankan startGame. terlebih dahulu.'), nl.

print_hand([], _).
print_hand([T|Ts], I) :-
    display_name(T, Name),
    format('~w. ~w~n', [I, Name]),
    I1 is I + 1,
    print_hand(Ts, I1).

showBag :-
    run_started(1), !,
    nl, write('========== BAG =========='), nl,
    potions(P),
    format('Potion: ~w~n', [P]),
    show_gear_line(sword), show_gear_line(shield),
    show_gear_line(armor), show_gear_line(ring).
showBag :-
    write('Permainan belum dimulai. Jalankan startGame. terlebih dahulu.'), nl.

help :-
    nl, write('========== DAFTAR COMMAND =========='), nl,
    write('--- Mulai ---'), nl,
    write('  startGame.           Mulai interaktif (input nama & class)'), nl,
    write('  startGameAs(N, C).   Mulai langsung, mis. startGameAs(budi, warrior).'), nl,
    write('--- Umum ---'), nl,
    write('  showLoop.            Lihat peta loop'), nl,
    write('  showHero.            Lihat status hero'), nl,
    write('  showHand.            Lihat tile di tangan'), nl,
    write('  showBag.             Lihat gear & potion'), nl,
    write('--- Loop ---'), nl,
    write('  step.                Hero maju 1 petak'), nl,
    write('  autoStep.            Lompat ke petak berarti berikutnya'), nl,
    write('  step(N).             Maju maksimal N petak (berhenti bila ada kejadian)'), nl,
    write('  stepTo(Pos).         Maju sampai petak Pos (berhenti bila ada kejadian)'), nl,
    write('  placeTile(Idx, Pos). Pasang tile hand Idx ke posisi Pos'), nl,
    write('  retreat.             Akhiri run & catat skor'), nl,
    write('--- Battle ---'), nl,
    write('  attack.              Serangan biasa'), nl,
    write('  defend.              Kurangi damage masuk 30%'), nl,
    write('  skill.               Serangan 150% ATK'), nl,
    write('  usePotion.           Pulihkan 30% MaxHP'), nl,
    write('--- File ---'), nl,
    write('  saveGame(F).         Simpan run ke file'), nl,
    write('  loadGame(F).         Muat run dari file'), nl,
    write('  showHighScore.       Lihat papan skor'), nl,
    write('--- Legenda ---'), nl,
    write('  C Campfire | . Wasteland | R Rock | M Meadow | T Mountain'), nl,
    write('  V V.Mansion | G Cemetery | B Battlefield | L Village | U Ruins'), nl,
    write('  s slime | k skeleton | r ratwolf | h harpy | v vampire | g gargoyle'), nl,
    write('  Z LICH | P posisi Hero'), nl.

/* ---------- Retreat & akhir run ---------- */
retreat :-
    run_started(1), game_over(0), in_battle(0), !,
    write('Hero mundur dari loop dan menyelamatkan diri...'), nl,
    end_run(retreat).
retreat :-
    in_battle(1), !,
    write('Tidak bisa retreat saat battle!'), nl, fail.
retreat :-
    write('Tidak ada permainan aktif.'), nl, fail.

/* end_run(+Reason) : hitung skor, catat high score */
end_run(Reason) :-
    hero(Name,_,Lv,_,_,_,_,_),
    loops_done(L), placed_count(PC), kills(K),
    compute_score(L, PC, K, Lv, Score),
    nl, write('========== RUN BERAKHIR =========='), nl,
    (Reason = win     -> write('Hasil: MENANG!') ;
     Reason = lose    -> write('Hasil: Gugur dalam battle.') ;
                         write('Hasil: Retreat.')),
    nl,
    format('Loop diselesaikan: ~w | Tile terpasang: ~w | Kill: ~w | Level: ~w~n', [L, PC, K, Lv]),
    format('SKOR AKHIR: ~w~n', [Score]),
    add_highscore(Name, Score),
    write('Skor tercatat di highscore.txt.'), nl,
    retractall(game_over(_)), assertz(game_over(1)).
