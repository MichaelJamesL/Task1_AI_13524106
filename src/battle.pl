/* ============================================================
 * battle.pl - Sistem battle turn-based (command-driven),
 *             EXP/level up, drop gear/potion/tile, boss Lich.
 * ============================================================ */

/* ---------- Memulai battle (dipanggil dari step) ---------- */
start_battle(lich) :-
    !, boss(lich, HP, ATK, DEF, _),
    retractall(battle_enemy(_,_,_,_,_)),
    assertz(battle_enemy(lich, HP, HP, ATK, DEF)),
    retractall(in_battle(_)), assertz(in_battle(1)),
    retractall(lich_round(_)), assertz(lich_round(0)),
    nl,
    write('========================================'), nl,
    write(' LICH, SANG PENGUTUK LOOP, MENGHADANG!'), nl,
    write(' Dia memanggil 2 skeletal guard di sisinya!'), nl,
    format(' Lich HP: ~w/~w | ATK ~w | DEF ~w~n', [HP, HP, ATK, DEF]),
    write('========================================'), nl,
    write('Gunakan attack / defend / skill / usePotion.'), nl.
start_battle(Type) :-
    enemy(Type, HP, ATK, DEF, _),
    retractall(battle_enemy(_,_,_,_,_)),
    assertz(battle_enemy(Type, HP, HP, ATK, DEF)),
    retractall(in_battle(_)), assertz(in_battle(1)),
    display_name(Type, Name),
    format('~n!!! ~w liar menghadang! HP: ~w/~w | ATK ~w | DEF ~w !!!~n', [Name, HP, HP, ATK, DEF]),
    write('Gunakan attack / defend / skill / usePotion.'), nl.

/* ---------- Stat total hero (base + gear) ---------- */
hero_atk_total(ATK) :-
    hero(_,_,_,_,_,_,A,_),
    (equipped(sword,_,V) -> ATK is A + V ; ATK = A).

hero_def_total(DEF) :-
    hero(_,_,_,_,_,_,_,Df),
    (equipped(shield,_,V) -> DEF is Df + V ; DEF = Df).

/* heal dari ring vampirism setelah hero memberi damage */
ring_lifesteal(Dmg) :-
    equipped(ring,_,V), !,
    Heal is Dmg * V // 100,
    (Heal > 0 ->
        hero(N,C,Lv,E,HP,MaxHP,A,Df),
        HP1 is min(MaxHP, HP + Heal),
        retractall(hero(_,_,_,_,_,_,_,_)),
        assertz(hero(N,C,Lv,E,HP1,MaxHP,A,Df)),
        format('Ring menyerap ~w HP.~n', [Heal])
    ; true).
ring_lifesteal(_).

/* ---------- Command: attack ---------- */
attack :-
    in_battle(1), game_over(0), !,
    battle_enemy(Type, EHP, EMax, EATK, EDEF),
    hero_atk_total(ATK),
    compute_damage(ATK, EDEF, Dmg),
    display_name(Type, Name),
    format('Hero menyerang ~w! Damage: ~w~n', [Name, Dmg]),
    apply_enemy_damage(Type, EHP, EMax, EATK, EDEF, Dmg, AfterFirst),
    (AfterFirst = alive, hero(_,rogue,_,_,_,_,_,_), rand_int(100,Rr), X is Rr + 1, X =< 15 ->
        write('TRAIT ROGUE: Double Strike!'), nl,
        format('Hero menyerang ~w lagi! Damage: ~w~n', [Name, Dmg]),
        battle_enemy(T2, EHP2, EM2, EA2, ED2),
        apply_enemy_damage(T2, EHP2, EM2, EA2, ED2, Dmg, _)
    ; true),
    (in_battle(1) -> enemy_turn ; true).
attack :-
    write('Tidak ada musuh untuk diserang (kamu tidak sedang dalam battle).'), nl, fail.

/* apply_enemy_damage : kurangi HP musuh, cek kematian */
apply_enemy_damage(Type, EHP, EMax, EATK, EDEF, Dmg, Result) :-
    EHP1 is EHP - Dmg,
    display_name(Type, Name),
    (EHP1 =< 0 ->
        format('~w HP: 0/~w~n', [Name, EMax]),
        battle_victory(Type),
        Result = dead
    ;   retractall(battle_enemy(_,_,_,_,_)),
        assertz(battle_enemy(Type, EHP1, EMax, EATK, EDEF)),
        format('~w HP: ~w/~w~n', [Name, EHP1, EMax]),
        ring_lifesteal(Dmg),
        Result = alive).

/* ---------- Command: skill (150% ATK) ---------- */
skill :-
    in_battle(1), game_over(0), !,
    battle_enemy(Type, EHP, EMax, EATK, EDEF),
    hero(_,Class,_,_,_,_,_,_),
    class_skill(Class, SkillName),
    hero_atk_total(ATK),
    EffATK is ATK * 150 // 100,
    compute_damage(EffATK, EDEF, Dmg),
    format('Hero menggunakan "~w"! Damage: ~w~n', [SkillName, Dmg]),
    apply_enemy_damage(Type, EHP, EMax, EATK, EDEF, Dmg, _),
    (in_battle(1) -> enemy_turn ; true).
skill :-
    write('Skill hanya bisa digunakan dalam battle.'), nl, fail.

/* ---------- Command: defend (kurangi damage masuk 30%) ---------- */
defend :-
    in_battle(1), game_over(0), !,
    retractall(defend_up(_)), assertz(defend_up(1)),
    write('Hero mengambil posisi bertahan! Damage berikutnya dikurangi 30%.'), nl,
    enemy_turn.
defend :-
    write('Defend hanya bisa digunakan dalam battle.'), nl, fail.

/* ---------- Command: usePotion (heal 30% MaxHP) ---------- */
usePotion :-
    run_started(1), game_over(0),
    potions(P), P > 0, !,
    P1 is P - 1,
    retractall(potions(_)), assertz(potions(P1)),
    hero(N,C,Lv,E,HP,MaxHP,A,Df),
    Heal is MaxHP * 30 // 100,
    HP1 is min(MaxHP, HP + Heal),
    retractall(hero(_,_,_,_,_,_,_,_)),
    assertz(hero(N,C,Lv,E,HP1,MaxHP,A,Df)),
    format('Hero meminum potion. HP pulih ~w (sisa potion: ~w).~n', [Heal, P1]),
    (in_battle(1) -> enemy_turn ; true).
usePotion :-
    run_started(1), !,
    write('Potion habis!'), nl, fail.
usePotion :-
    write('Tidak ada permainan aktif.'), nl, fail.

/* ---------- Giliran musuh ---------- */
enemy_turn :-
    battle_enemy(lich, EHP, EMax, EATK, EDEF), !,
    lich_round(R), R1 is R + 1,
    retractall(lich_round(_)), assertz(lich_round(R1)),
    (R1 mod 3 =:= 0 ->
        EffATK is EATK * 150 // 100,
        write('Lich melancarkan ARCANE BOLT! (150% ATK)'), nl,
        enemy_strike(lich, EHP, EMax, EATK, EDEF, EffATK)
    ;   enemy_strike(lich, EHP, EMax, EATK, EDEF, EATK)).
enemy_turn :-
    battle_enemy(Type, EHP, EMax, EATK, EDEF),
    enemy_strike(Type, EHP, EMax, EATK, EDEF, EATK).

/* enemy_strike : musuh menyerang hero (dengan cek defend & lifesteal vampire) */
enemy_strike(Type, _EHP, _EMax, _EATK, _EDEF, EffATK) :-
    hero_def_total(DEF),
    compute_damage(EffATK, DEF, Dmg0),
    (defend_up(1) ->
        Dmg is Dmg0 * 70 // 100,
        retractall(defend_up(_)), assertz(defend_up(0)),
        display_name(Type, DName),
        format('Serangan ~w diredam pertahanan hero! Damage: ~w~n', [DName, Dmg])
    ;   Dmg = Dmg0,
        display_name(Type, Name),
        format('~w menyerang balik! Damage: ~w~n', [Name, Dmg])),
    hero(N,C,Lv,E,HP,MaxHP,A,Df),
    HP1 is max(0, HP - Dmg),
    retractall(hero(_,_,_,_,_,_,_,_)),
    assertz(hero(N,C,Lv,E,HP1,MaxHP,A,Df)),
    vampire_lifesteal(Type, Dmg),
    (HP1 =< 0 ->
        write('Hero HP: 0/'), write(MaxHP), nl,
        hero_dies
    ;   format('Hero HP: ~w/~w~n', [HP1, MaxHP])).

/* vampire_lifesteal : vampire memulihkan 25% damage yang diberikan */
vampire_lifesteal(vampire, Dmg) :-
    battle_enemy(vampire, EHP, EMax, EATK, EDEF), !,
    Heal is Dmg * 25 // 100,
    (Heal > 0 ->
        EHP1 is min(EMax, EHP + Heal),
        retractall(battle_enemy(_,_,_,_,_)),
        assertz(battle_enemy(vampire, EHP1, EMax, EATK, EDEF)),
        format('Vampire menyerap ~w HP!~n', [Heal])
    ; true).
vampire_lifesteal(_, _).

/* ---------- Kemenangan battle ---------- */
battle_victory(Type) :-
    display_name(Type, Name),
    format('~w dikalahkan!~n', [Name]),
    kills(K), K1 is K + 1,
    retractall(kills(_)), assertz(kills(K1)),
    hero_pos(Pos), enemies(Foes),
    replace0(Foes, Pos, none, Foes1),
    retractall(enemies(_)), assertz(enemies(Foes1)),
    retractall(in_battle(_)), assertz(in_battle(0)),
    retractall(defend_up(_)), assertz(defend_up(0)),
    retractall(battle_enemy(_,_,_,_,_)),
    exp_of(Type, Exp),
    gain_exp(Exp),
    roll_drops,
    (Type = lich -> win_game
    ;   write('Battle selesai.'), nl, showLoop).

exp_of(lich, Exp) :- !, boss(lich, _, _, _, Exp).
exp_of(Type, Exp) :- enemy(Type, _, _, _, Exp).

/* gain_exp(+Amount) : dengan trait necromancer +25% */
gain_exp(Amount) :-
    hero(N,C,Lv,E,HP,MaxHP,A,Df),
    (C = necromancer -> A1 is Amount * 125 // 100 ; A1 = Amount),
    E1 is E + A1,
    format('EXP +~w~n', [A1]),
    level_up_check(N,C,Lv,E1,HP,MaxHP,A,Df).

/* level_up_check : rekurens untuk multi level-up */
level_up_check(N,C,Lv,E,HP,MaxHP,A,Df) :-
    exp_needed(Lv, Need),
    E >= Need, !,
    E1 is E - Need, Lv1 is Lv + 1,
    level_gain(HG, AG, DG),
    MaxHP1 is MaxHP + HG, HP1 is HP + HG,
    A1 is A + AG, Df1 is Df + DG,
    format('LEVEL UP! Hero naik ke level ~w (MaxHP +~w, ATK +~w, DEF +~w)~n', [Lv1, HG, AG, DG]),
    level_up_check(N,C,Lv1,E1,HP1,MaxHP1,A1,Df1).
level_up_check(N,C,Lv,E,HP,MaxHP,A,Df) :-
    retractall(hero(_,_,_,_,_,_,_,_)),
    assertz(hero(N,C,Lv,E,HP,MaxHP,A,Df)).

/* ---------- Drop setelah kill ---------- */
roll_drops :-
    roll_gear_drop,
    roll_potion_drop,
    roll_tile_drop.

roll_gear_drop :-
    gear_drop_chance(C), rand_int(100,R1), X is R1 + 1, X =< C, !,
    rand_int(4,R2), S is R2 + 1, slot_by_idx(S, Slot),
    roll_tier(Tier),
    tier(Tier, Lo, Hi),
    Range is Hi - Lo + 1,
    rand_int(Range,Off), Val is Lo + Off,
    equip_gear(Slot, Tier, Val).
roll_gear_drop.

slot_by_idx(1, sword).
slot_by_idx(2, shield).
slot_by_idx(3, armor).
slot_by_idx(4, ring).

roll_tier(Tier) :-
    rand_int(100,R), X is R + 1,
    (X =< 60 -> Tier = common
    ; X =< 90 -> Tier = magic
    ; Tier = rare).

/* equip_gear : auto-equip bila lebih baik (cut), selain itu dibuang */
equip_gear(Slot, Tier, Val) :-
    equipped(Slot, _, OldVal), !,
    (Val > OldVal ->
        retractall(equipped(Slot,_,_)),
        assertz(equipped(Slot, Tier, Val)),
        apply_armor_bonus(Slot, Val, OldVal),
        format('Gear ditemukan: ~w (~w, +~w). Lebih baik! Langsung terpasang.~n', [Slot, Tier, Val])
    ;   format('Gear ditemukan: ~w (~w, +~w). Tidak lebih baik dari yang terpasang, dibuang.~n', [Slot, Tier, Val])).
equip_gear(Slot, Tier, Val) :-
    assertz(equipped(Slot, Tier, Val)),
    apply_armor_bonus(Slot, Val, 0),
    format('Gear ditemukan: ~w (~w, +~w). Langsung terpasang.~n', [Slot, Tier, Val]).

apply_armor_bonus(armor, Val, OldVal) :-
    !, hero(N,C,Lv,E,HP,MaxHP,A,Df),
    Delta is Val - OldVal,
    MaxHP1 is MaxHP + Delta, HP1 is HP + Delta,
    retractall(hero(_,_,_,_,_,_,_,_)),
    assertz(hero(N,C,Lv,E,HP1,MaxHP1,A,Df)).
apply_armor_bonus(_, _, _).

roll_potion_drop :-
    potion_drop_chance(C), rand_int(100,R), X is R + 1, X =< C, !,
    potions(P), P1 is P + 1,
    retractall(potions(_)), assertz(potions(P1)),
    write('Musuh menjatuhkan potion! (+1)'), nl.
roll_potion_drop.

roll_tile_drop :-
    tile_drop_chance(C), rand_int(100,R), X is R + 1, X =< C, !,
    hand(H), length(H, Len),
    (Len < 5 ->
        random_tile(T),
        retractall(hand(_)), assertz(hand([T|H])),
        display_name(T, Name),
        format('Musuh menjatuhkan tile: ~w!~n', [Name])
    ;   write('Hand penuh, tile drop hilang.'), nl).
roll_tile_drop.

/* ---------- Menang / kalah ---------- */
win_game :-
    nl,
    write('************************************************'), nl,
    write(' SELAMAT! Lich berhasil dikalahkan!'), nl,
    write(' Kutukan Loop telah patah. Kamu pemenangnya!'), nl,
    write('************************************************'), nl,
    end_run(win).

hero_dies :-
    nl,
    write('Hero gugur... Loop kembali menelan korban.'), nl,
    retractall(battle_enemy(_,_,_,_,_)),
    retractall(in_battle(_)), assertz(in_battle(0)),
    end_run(lose).
