/* ============================================================
 * fileio.pl - File processing: load config musuh, save/load
 *             game, dan high score.
 * ============================================================ */

/* ---------- Load data musuh dari config/enemies.txt ---------- */
load_config :-
    retractall(enemy(_,_,_,_,_)),
    open('config/enemies.txt', read, S),
    read_enemies(S),
    close(S),
    write('(Data musuh dimuat dari config/enemies.txt)'), nl.

/* read_enemies(+Stream) : baca term sampai end_of_file (rekurens) */
read_enemies(S) :-
    read(S, Term),
    (Term = end_of_file -> !
    ; assertz(Term), read_enemies(S)).

/* ---------- Save game ---------- */
saveGame(File) :-
    run_started(1), game_over(0), in_battle(0), !,
    hero(Nm,C,Lv,E,HP,MaxHP,A,Df),
    loop_tiles(T), enemies(F), hero_pos(P), day(D), hand(H),
    placed_count(PC), potions(Po), kills(K), loops_done(L),
    boss_spawned(B),
    findall(eq(Sl,Ti,V), equipped(Sl,Ti,V), EQ),
    open(File, write, S),
    writeq(S, state(hero(Nm,C,Lv,E,HP,MaxHP,A,Df), T, F, P, D, H, PC, Po, K, L, B, EQ)),
    write(S, '.'), nl(S),
    close(S),
    format('Permainan tersimpan ke file "~w".~n', [File]).
saveGame(_) :-
    in_battle(1), !,
    write('Tidak bisa menyimpan saat battle!'), nl, fail.
saveGame(_) :-
    write('Tidak ada permainan aktif untuk disimpan.'), nl, fail.

/* ---------- Load game ---------- */
loadGame(File) :-
    catch(open(File, read, S), _, fail), !,
    read(S, State),
    close(S),
    State = state(Hero, T, F, P, D, H, PC, Po, K, L, B, EQ),
    reset_state,
    (rng_state(_) -> true ; rand_seed(7)),
    load_config,
    assertz(Hero),
    assertz(loop_tiles(T)), assertz(enemies(F)),
    assertz(hero_pos(P)), assertz(day(D)), assertz(hand(H)),
    assertz(placed_count(PC)), assertz(potions(Po)), assertz(kills(K)),
    assertz(loops_done(L)), assertz(boss_spawned(B)),
    assert_equipped_list(EQ),
    assertz(in_battle(0)), assertz(defend_up(0)), assertz(game_over(0)),
    assertz(run_started(1)), assertz(lich_round(0)),
    format('Permainan dimuat dari file "~w".~n', [File]),
    showLoop.
loadGame(_) :-
    write('Gagal memuat: file save tidak ditemukan / rusak.'), nl, fail.

/* assert_equipped_list(+List) : rekurens */
assert_equipped_list([]).
assert_equipped_list([eq(Sl,Ti,V)|T]) :-
    assertz(equipped(Sl,Ti,V)),
    assert_equipped_list(T).

/* ---------- High score ---------- */
add_highscore(Name, Score) :-
    open('highscore.txt', append, S),
    writeq(S, score(Name, Score)),
    write(S, '.'), nl(S),
    close(S).

showHighScore :-
    catch(open('highscore.txt', read, S), _, fail), !,
    read_scores(S, List),
    close(S),
    sort_desc(List, Sorted),
    nl, write('========== HIGH SCORE =========='), nl,
    print_top(Sorted, 1).
showHighScore :-
    write('Belum ada high score yang tercatat.'), nl.

/* read_scores(+Stream, -List) : rekurens */
read_scores(S, List) :-
    read(S, Term),
    (Term = end_of_file -> List = []
    ; List = [Term|Rest], read_scores(S, Rest)).

/* sort_desc : insertion sort menurun berdasarkan nilai skor (rekurens) */
sort_desc([], []).
sort_desc([H|T], Sorted) :-
    sort_desc(T, ST),
    insert_score(H, ST, Sorted).

insert_score(X, [], [X]) :- !.
insert_score(score(N,V), [score(N2,V2)|T], [score(N,V),score(N2,V2)|T]) :-
    V >= V2, !.
insert_score(X, [H|T], [H|R]) :-
    insert_score(X, T, R).

/* print_top(+List, +Rank) : maksimal 10 besar */
print_top(_, I) :- I > 10, !.
print_top([], _) :- !.
print_top([score(N,V)|T], I) :-
    format('~w. ~w - ~w pts~n', [I, N, V]),
    I1 is I + 1,
    print_top(T, I1).
