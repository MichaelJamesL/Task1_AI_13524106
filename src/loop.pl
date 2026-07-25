/* ============================================================
 * loop.pl - Jalur melingkar (circular list), pergerakan hero,
 *           spawn musuh, dan pemasangan tile.
 * Loop direpresentasikan sebagai list 24 elemen dengan
 * indeks wrap-around (mod 24).
 * ============================================================ */

loop_size(24).
boss_tile_threshold(10).

/* ---------- Utilitas list (rekurens) ---------- */

/* my_nth0(+List, +Idx, -Elem) */
my_nth0([H|_], 0, H) :- !.
my_nth0([_|T], I, E) :-
    I > 0,
    I1 is I - 1,
    my_nth0(T, I1, E).

/* replace0(+List, +Idx, +NewElem, -NewList) */
replace0([_|T], 0, X, [X|T]) :- !.
replace0([H|T], I, X, [H|R]) :-
    I > 0,
    I1 is I - 1,
    replace0(T, I1, X, R).

/* wrap(+Idx, -Wrapped) : indeks melingkar 0..23 */
wrap(I, W) :-
    loop_size(N),
    W is ((I mod N) + N) mod N.

/* ---------- Inisialisasi loop ---------- */
init_loop :-
    loop_size(N),
    N1 is N - 1,
    fill_list(wasteland, N1, Rest),
    retractall(loop_tiles(_)),
    assertz(loop_tiles([campfire|Rest])),
    fill_list(none, N, Foes),
    retractall(enemies(_)),
    assertz(enemies(Foes)).

/* fill_list(+Elem, +Count, -List) */
fill_list(_, 0, []) :- !.
fill_list(E, N, [E|T]) :-
    N > 0,
    N1 is N - 1,
    fill_list(E, N1, T).

/* initial_enemies : 2 slime ditempatkan acak di Wasteland saat awal permainan */
initial_enemies :-
    (find_empty_wasteland(P1) -> spawn_enemy_at(P1, slime) ; true),
    (find_empty_wasteland(P2) -> spawn_enemy_at(P2, slime) ; true).

/* ---------- Tampilan loop ---------- */
showLoop :-
    run_started(1), !,
    day(D), loops_done(L), placed_count(PC), kills(K),
    loop_tiles(Tiles), enemies(Foes), hero_pos(Pos),
    format('~n=== Day ~w | Loop ~w | Tile terpasang: ~w/10 | Kill: ~w ===~n', [D, L, PC, K]),
    print_tile_line(Tiles), nl,
    print_foe_line(Foes), nl,
    print_hero_marker(0, Pos), nl.
showLoop :-
    write('Permainan belum dimulai. Jalankan startGame. terlebih dahulu.'), nl.

/* print_tile_line(+Tiles) : cetak simbol tile dipisah spasi */
print_tile_line([]).
print_tile_line([T|Ts]) :-
    symbol(T, C), write(C), write(' '),
    print_tile_line(Ts).

/* print_foe_line(+Foes) : cetak simbol musuh (spasi bila kosong) */
print_foe_line([]).
print_foe_line([F|Fs]) :-
    foe_symbol(F, C), write(C), write(' '),
    print_foe_line(Fs).

/* print_hero_marker(+Idx, +HeroPos) : pointer P di bawah posisi hero */
print_hero_marker(I, Pos) :-
    loop_size(N), I < N, !,
    (I =:= Pos -> write('P') ; write('  ')),
    I1 is I + 1,
    print_hero_marker(I1, Pos).
print_hero_marker(_, _).

/* ---------- Pergerakan ---------- */

/* advance_pos(-NewPos) : geser hero satu petak searah jarum jam */
advance_pos(NewPos) :-
    hero_pos(Pos),
    wrap(Pos + 1, NewPos),
    retractall(hero_pos(_)),
    assertz(hero_pos(NewPos)).

/* resolve_step(+Pos) : seluruh efek satu langkah - pergantian hari,
   regen warrior, spawn acak, efek tile, dan battle bila ada musuh */
resolve_step(Pos) :-
    (Pos =:= 0 -> morning ; true),
    warrior_regen,
    maybe_spawn_slime,
    tile_on_enter(Pos),
    enemies(Foes), my_nth0(Foes, Pos, Foe),
    (Foe \= none -> start_battle(Foe) ; true).

/* step : majukan hero 1 petak searah jarum jam */
step :-
    run_started(1), game_over(0), in_battle(0), !,
    advance_pos(NewPos),
    format('Hero melangkah ke petak ~w.~n', [NewPos]),
    resolve_step(NewPos),
    (in_battle(0), game_over(0) -> showLoop ; true).
step :-
    in_battle(1), !,
    write('Tidak bisa melangkah: sedang dalam battle! Selesaikan dengan attack/defend/skill/usePotion.'), nl.
step :-
    write('Tidak bisa melangkah sekarang (game belum mulai / sudah berakhir).'), nl.

/* ---------- Fast-forward: lompat ke petak yang berarti ----------
 * Wasteland kosong tidak menghasilkan apa pun saat dimasuki, jadi
 * melangkahinya satu per satu hanya membuang giliran pemain. autoStep,
 * step(N), dan stepTo(Pos) menjalankan langkah-langkah itu sekaligus -
 * seluruh efek per langkah (regen, peluang spawn 5%, pergantian hari)
 * tetap dihitung satu per satu - lalu berhenti begitu ada sesuatu yang
 * butuh keputusan pemain: musuh, tile berefek, atau pagi hari baru.
 */

/* autoStep : maju sampai kejadian berikutnya (maksimal satu putaran penuh) */
autoStep :-
    run_started(1), game_over(0), in_battle(0), !,
    loop_size(N),
    fast_forward(N, full_loop, 0),
    (in_battle(0), game_over(0) -> showLoop ; true).
autoStep :-
    in_battle(1), !,
    write('Tidak bisa melangkah: sedang dalam battle! Selesaikan dengan attack/defend/skill/usePotion.'), nl.
autoStep :-
    write('Tidak bisa melangkah sekarang (game belum mulai / sudah berakhir).'), nl.

/* step(+N) : maju maksimal N petak, berhenti lebih awal bila ada kejadian */
step(N) :-
    run_started(1), game_over(0), in_battle(0), !,
    (integer(N), N > 0 ->
        fast_forward(N, steps_done, 0),
        (in_battle(0), game_over(0) -> showLoop ; true)
    ;   write('Jumlah langkah harus bilangan bulat positif, mis. step(5).'), nl, fail).
step(_) :-
    in_battle(1), !,
    write('Tidak bisa melangkah: sedang dalam battle! Selesaikan dengan attack/defend/skill/usePotion.'), nl.
step(_) :-
    write('Tidak bisa melangkah sekarang (game belum mulai / sudah berakhir).'), nl.

/* stepTo(+Target) : maju sampai petak Target searah jarum jam,
   berhenti lebih awal bila ada kejadian di tengah jalan */
stepTo(Target) :-
    run_started(1), game_over(0), in_battle(0), !,
    (valid_target(Target) ->
        hero_pos(Cur),
        cw_distance(Cur, Target, D),
        fast_forward(D, arrived, 0),
        (in_battle(0), game_over(0) -> showLoop ; true)
    ;   loop_size(N), Max is N - 1,
        format('Tujuan tidak valid: pilih petak 0..~w selain posisi hero sekarang.~n', [Max]),
        fail).
stepTo(_) :-
    in_battle(1), !,
    write('Tidak bisa melangkah: sedang dalam battle! Selesaikan dengan attack/defend/skill/usePotion.'), nl.
stepTo(_) :-
    write('Tidak bisa melangkah sekarang (game belum mulai / sudah berakhir).'), nl.

/* valid_target(+Pos) : petak 0..23 dan bukan posisi hero saat ini */
valid_target(Pos) :-
    integer(Pos), Pos >= 0, loop_size(N), Pos < N,
    hero_pos(Cur), Pos =\= Cur, !.

/* cw_distance(+From, +To, -Jarak) : jarak searah jarum jam pada loop */
cw_distance(From, To, D) :-
    loop_size(N),
    D is ((To - From) mod N + N) mod N.

/* fast_forward(+Sisa, +AlasanHabis, +SudahDilangkah) : rekurens langkah
   beruntun; berhenti saat petak berarti, kejadian tak terduga, atau Sisa = 0 */
fast_forward(0, DoneReason, Steps) :- !,
    hero_pos(Pos),
    report_ff(Steps, Pos, DoneReason).
fast_forward(K, DoneReason, Acc) :-
    advance_pos(NewPos),
    Steps is Acc + 1,
    stop_reason(NewPos, R),
    (R = none -> true ; report_ff(Steps, NewPos, R)),
    resolve_step(NewPos),
    (R \= none -> true
    ; unexpected_stop(Why) -> report_ff(Steps, NewPos, Why)
    ; K1 is K - 1,
      fast_forward(K1, DoneReason, Steps)).

/* stop_reason(+Pos, -Alasan) : apakah petak Pos layak dihentikan?
   Wasteland dan tile tanpa efek masuk dilewati begitu saja. */
stop_reason(Pos, battle) :-
    enemies(Foes), my_nth0(Foes, Pos, Foe),
    Foe \= none, !.
stop_reason(Pos, tile(T)) :-
    loop_tiles(Tiles), my_nth0(Tiles, Pos, T),
    stop_tile(T), !.
stop_reason(0, morning) :- !.
stop_reason(_, none).

/* unexpected_stop(-Alasan) : kejadian yang baru diketahui setelah efek
   langkah dijalankan, mis. slime muncul tepat di petak yang dituju hero */
unexpected_stop(game_over) :- game_over(1), !.
unexpected_stop(battle)    :- in_battle(1).

/* report_ff(+JumlahLangkah, +Pos, +Alasan) : ringkasan satu baris,
   pengganti pesan "Hero melangkah" yang berulang */
report_ff(Steps, Pos, Reason) :-
    ff_reason(Reason, Txt),
    format('>> Hero melaju ~w petak, berhenti di petak ~w: ~w.~n', [Steps, Pos, Txt]).

ff_reason(tile(T), Txt) :- !,
    display_name(T, Name),
    atom_concat('singgah di ', Name, Txt).
ff_reason(battle,     'musuh menghadang').
ff_reason(morning,    'hari baru dimulai di Campfire').
ff_reason(game_over,  'run berakhir').
ff_reason(arrived,    'sampai di petak tujuan').
ff_reason(steps_done, 'jumlah langkah terpenuhi').
ff_reason(full_loop,  'satu putaran penuh tanpa kejadian').

/* morning : efek saat hero melewati campfire (hari baru) */
morning :-
    day(D), loops_done(L),
    D1 is D + 1, L1 is L + 1,
    retractall(day(_)), retractall(loops_done(_)),
    assertz(day(D1)), assertz(loops_done(L1)),
    format('~n--- Pagi hari ke-~w. Cahaya fajar menyegarkan loop. ---~n', [D1]),
    meadow_heal,
    scheduled_spawns(D1),
    draw_morning_tile.

/* meadow_heal : heal 2 HP per meadow (4 bila blooming), rekurens */
meadow_heal :-
    loop_tiles(Tiles),
    heal_from_meadows(Tiles, 0, 0, Total),
    (Total > 0 ->
        hero(N,C,Lv,E,HP,MaxHP,A,Df),
        HP1 is min(MaxHP, HP + Total),
        retractall(hero(_,_,_,_,_,_,_,_)),
        assertz(hero(N,C,Lv,E,HP1,MaxHP,A,Df)),
        format('Meadow memulihkan ~w HP.~n', [Total])
    ; true).

heal_from_meadows([], _, Acc, Acc).
heal_from_meadows([meadow|Ts], I, Acc, Total) :-
    !, wrap(I-1, L), wrap(I+1, R),
    loop_tiles(All),
    my_nth0(All, L, LT), my_nth0(All, R, RT),
    ((LT = mountain ; RT = mountain) -> H = 4 ; H = 2),
    Acc1 is Acc + H,
    I1 is I + 1,
    heal_from_meadows(Ts, I1, Acc1, Total).
heal_from_meadows([_|Ts], I, Acc, Total) :-
    I1 is I + 1,
    heal_from_meadows(Ts, I1, Acc, Total).

/* scheduled_spawns(+Day) : spawn terjadwal per tile (rekurens atas indeks) */
scheduled_spawns(Day) :-
    loop_tiles(Tiles),
    spawn_scheduled_at(Tiles, 0, Day).

spawn_scheduled_at([], _, _).
spawn_scheduled_at([Tile|Ts], I, Day) :-
    (spawns_from(Tile, Enemy, N), Day mod N =:= 0 ->
        (Tile = vampire_mansion ->
            wrap(I+1, Tgt)
        ;   Tgt = I),
        enemies(Foes), my_nth0(Foes, Tgt, Cur),
        (Cur = none ->
            spawn_enemy_at(Tgt, Enemy)
        ; true)
    ; true),
    I1 is I + 1,
    spawn_scheduled_at(Ts, I1, Day).

/* maybe_spawn_slime : 5% peluang slime muncul di wasteland kosong acak */
maybe_spawn_slime :-
    rand_int(100, R), X is R + 1,
    X =< 5, !,
    (find_empty_wasteland(Pos) -> spawn_enemy_at(Pos, slime) ; true).
maybe_spawn_slime.

/* find_empty_wasteland(-Pos) : maks 50 percobaan acak (loop rekursif) */
find_empty_wasteland(Pos) :-
    try_empty_wasteland(50, Pos).

try_empty_wasteland(0, _) :- !, fail.
try_empty_wasteland(K, Pos) :-
    rand_int(23, R), P is R + 1,
    loop_tiles(Tiles), my_nth0(Tiles, P, T),
    enemies(Foes), my_nth0(Foes, P, F),
    (T = wasteland, F = none -> Pos = P
    ; K1 is K - 1, try_empty_wasteland(K1, Pos)).

/* spawn_enemy_at(+Pos, +Type) */
spawn_enemy_at(Pos, Type) :-
    enemies(Foes),
    replace0(Foes, Pos, Type, Foes1),
    retractall(enemies(_)),
    assertz(enemies(Foes1)),
    display_name(Type, Name),
    format('~w muncul di petak ~w!~n', [Name, Pos]).

/* tile_on_enter(+Pos) : efek saat hero berhenti di suatu petak */
tile_on_enter(Pos) :-
    loop_tiles(Tiles), my_nth0(Tiles, Pos, village), !,
    hero(N,C,Lv,E,HP,MaxHP,A,Df),
    Heal is MaxHP * 20 // 100,
    HP1 is min(MaxHP, HP + Heal),
    retractall(hero(_,_,_,_,_,_,_,_)),
    assertz(hero(N,C,Lv,E,HP1,MaxHP,A,Df)),
    format('Hero beristirahat di Village. HP pulih ~w.~n', [Heal]).
tile_on_enter(_).

/* warrior_regen : trait warrior, regen 2% MaxHP per langkah */
warrior_regen :-
    hero(N,warrior,Lv,E,HP,MaxHP,A,Df), !,
    Regen is max(1, MaxHP * 2 // 100),
    HP1 is min(MaxHP, HP + Regen),
    retractall(hero(_,_,_,_,_,_,_,_)),
    assertz(hero(N,warrior,Lv,E,HP1,MaxHP,A,Df)).
warrior_regen.

/* draw_morning_tile : +1 tile ke hand tiap pagi bila hand < 5 */
draw_morning_tile :-
    hand(H), length(H, Len),
    (Len < 5 ->
        random_tile(T),
        retractall(hand(_)),
        assertz(hand([T|H])),
        display_name(T, Name),
        format('Kamu mendapat tile baru: ~w.~n', [Name])
    ; true).

/* random_tile(-T) */
random_tile(T) :-
    Pool = [rock, meadow, mountain, vampire_mansion, cemetery, battlefield, village, ruins],
    rand_int(8, R), X is R + 1,
    my_nth0(Pool, X-1, T).

/* ---------- Pemasangan tile ---------- */
placeTile(HandIdx, Pos) :-
    run_started(1), game_over(0), in_battle(0), !,
    hand(H),
    (my_nth0(H, HandIdx, Tile) ->
        (valid_placement(Pos) ->
            do_place(Tile, Pos),
            remove_at(H, HandIdx, H1),
            retractall(hand(_)), assertz(hand(H1)),
            placed_count(PC), PC1 is PC + 1,
            retractall(placed_count(_)), assertz(placed_count(PC1)),
            display_name(Tile, Name),
            format('Tile ~w dipasang di posisi ~w. (~w/10 menuju kebangkitan Lich)~n', [Name, Pos, PC1]),
            maybe_spawn_boss(PC1)
        ;   format('Gagal memasang tile: posisi ~w tidak valid (harus petak kosong selain Campfire).~n', [Pos]), fail)
    ;   write('Gagal memasang tile: indeks hand tidak valid.'), nl, fail).
placeTile(_, _) :-
    in_battle(1), !,
    write('Tidak bisa memasang tile saat battle!'), nl, fail.
placeTile(_, _) :-
    write('Tidak bisa memasang tile: permainan belum mulai / sudah berakhir.'), nl, fail.

/* remove_at(+List, +Idx, -NewList) */
remove_at([_|T], 0, T) :- !.
remove_at([H|T], I, [H|R]) :-
    I > 0, I1 is I - 1,
    remove_at(T, I1, R).

/* valid_placement(+Pos) : bukan campfire, wasteland kosong, tanpa musuh */
valid_placement(Pos) :-
    integer(Pos), Pos >= 1, loop_size(N), Pos < N,
    loop_tiles(Tiles), my_nth0(Tiles, Pos, wasteland),
    enemies(Foes), my_nth0(Foes, Pos, none), !.

/* do_place(+Tile, +Pos) : pasang tile + efek langsung */
do_place(Tile, Pos) :-
    loop_tiles(Tiles),
    replace0(Tiles, Pos, Tile, Tiles1),
    retractall(loop_tiles(_)),
    assertz(loop_tiles(Tiles1)),
    (place_bonus(Tile, Bonus) ->
        hero(N,C,Lv,E,HP,MaxHP,A,Df),
        MaxHP1 is MaxHP + Bonus, HP1 is HP + Bonus,
        retractall(hero(_,_,_,_,_,_,_,_)),
        assertz(hero(N,C,Lv,E,HP1,MaxHP1,A,Df)),
        format('MaxHP bertambah ~w!~n', [Bonus])
    ; true).

/* maybe_spawn_boss(+PlacedCount) */
maybe_spawn_boss(PC) :-
    boss_tile_threshold(Th),
    PC >= Th, boss_spawned(0), !,
    retractall(boss_spawned(_)), assertz(boss_spawned(1)),
    enemies(Foes),
    replace0(Foes, 0, lich, Foes1),
    retractall(enemies(_)), assertz(enemies(Foes1)),
    write(''), nl,
    write('Udara tiba-tiba mendingin... Langit di atas Campfire menghitam.'), nl,
    write('LICH TELAH BANGKIT di Campfire (petak 0)!'), nl,
    write('Kalahkan dia untuk mematahkan kutukan Loop!'), nl.
maybe_spawn_boss(_).
