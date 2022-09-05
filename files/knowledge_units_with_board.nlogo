extensions [table]

globals [
  mf_ratio

  exploit_trend
  attention_norm

  male_exploit_trend
  male_attention_norm

  female_exploit_trend
  female_attention_norm

  first_ku
  divergencies_from_first_ku ; hamming distance for ALL messages in relation to first_ku
  all_divergencies_from_first_ku

  compat_with_init_ctr
  incompat_with_init_ctr
  compat_ratio ; was the mean ku compat with first_ku?
  all_compat_ratios ; ratios of compat / incompat msgs per tick
]

breed [boards board]
breed [agents _agent]

boards-own [
  curr_board     ; current kus on board
  board_history  ; history of kus posted on the board per tick

  agents_history ; all agents that sent kus to board
  curr_agents    ; agents that sent ku to board this tick

  ratio ; compat / incompat ratio, cant delete because of plot
  all_compatibilities
  compatibilities

  male_participation
  female_participation
]

agents-own [ ;; KU
  kus ;; ( 0..255 )
  list_of_links
  prob_exploit ;; exploration vs exploitation
  focused_ku

  ;; individual vars
  gender
  class
]

to setup
  clear-all
  ;random-seed 250474

  set first_ku 255 ; 0000 0000 1111 1111

  let male_exploit male_prob_exploit
  let female_exploit female_prob_exploit ; TODO : why am I doing this ? seems useless i can just use female_prob_exploit
  set mf_ratio (males / (males + females))

  if ku_number > (2 ^ ku_len) [
    error "ERROR: TOO MANY KNOWLEDGE UNITS, CAN'T BE UNIQUE"
    stop
  ]

  setup-agents
  layout-circle agents 12

  ;let y sort agents
  ;foreach y [ x ->
    ;type [who] of x type " unique KUs : " print sort [kus] of x
    ;type [who] of x type " links : " print [list_of_links] of x
    ;type [gender] of x type "\n"
  ;]
  show-mf-ratio

  setup-board

  set all_compat_ratios []
  set all_divergencies_from_first_ku []

  reset-ticks
  ;; go
end

to setup-board
  create-boards 1
  [
    set shape "star"
    set color yellow
    set size 5
    set label "board"

    set agents_history [] ; save agent participation
    set curr_agents []

    set board_history lput (insert-item 0 [] first_ku) [] ; add first ku to board
    set curr_board []

    set all_compatibilities []
    set compatibilities []

    set ratio 0.5

    create-links-with other agents [
      set thickness 0.4
      if [gender] of [end1] of self = "m" [ set color yellow ]
      if [gender] of [end1] of self = "f" [ set color orange ]
    ]

  ]
end

to setup-agents
  let agent_ctr number_of_agents
  let m_ctr 0
  let f_ctr 0
  create-agents number_of_agents
  [
    set shape "circle"
    set color violet
    set size 2
    ; set label ([who] of self)
    set kus []

    ; 16 compat em 60  test
    ; 40 compat em 150 run simulation
    let compat_kus_ctr 40
    let incompat_kus_ctr (ku_number - compat_kus_ctr)

    ;; generate ku_number of kus
    repeat ku_number [
      let this_ku random (2 ^ ku_len)

      ;; is ku unique? is the quota for compatible/incompat ku's filled?
      while [(member? this_ku kus)
        or ((get-compat-as-decimal this_ku first_ku) >  c_threshold and compat_kus_ctr = 0)
        or ((get-compat-as-decimal this_ku first_ku) <= c_threshold and incompat_kus_ctr = 0)
        ]
      [
        set this_ku random (2 ^ ku_len)
      ]

      if-else (get-compat-as-decimal this_ku first_ku) > c_threshold
      [ set compat_kus_ctr   (compat_kus_ctr - 1) ]
      [ set incompat_kus_ctr (incompat_kus_ctr - 1) ]

      set kus lput this_ku kus
      ; print ( ku_number - length kus ) ; show ku's left
     ]

    ;print "Bottleneck !!!"
    ;; initiate list of links
    set list_of_links []
    set list_of_links set_links self

    ;print "finished list of links"

    ;; focus on a random KU
    set focused_ku one-of kus

    ;; individual vars
    if-else males = 0 and females = 0 [
      error "ERROR: 0:0 Male Female Ratio"
      stop
    ][
      ; type "males " print m_ctr
      ; type "females " print f_ctr
      ; type number_of_agents * mf_ratio type " males for " type number_of_agents - (number_of_agents * mf_ratio) print " females"

      ; too many males
      if-else m_ctr >= number_of_agents * mf_ratio [
        set gender "f"
        set label "♀"
        set f_ctr f_ctr + 1
      ][ ; too many females
        if-else f_ctr >= number_of_agents - (number_of_agents * mf_ratio) [

          set gender "m"
          set label "♂"
          set m_ctr m_ctr + 1
        ]
        [ ; hasnt reached limit, random
          if-else random-float 1 < mf_ratio[
            set gender "m"
            set label "♂"
            set m_ctr m_ctr + 1
          ][
            set gender "f"
            set label "♀"
            set f_ctr f_ctr + 1
          ]
        ]
      ]
    ]

    if-else gender = "m" [ set prob_exploit male_prob_exploit ]
    [ set prob_exploit female_prob_exploit ]

    set agent_ctr agent_ctr - 1
    type agent_ctr print " agents left"
  ]
end

to show-mf-ratio
  let gender-counts get-gender-count
  let f first gender-counts
  let m last gender-counts

  type "\nMF RATIO -> F - " type f type " | M - " print m
end

to-report get-gender-count
  let ts sort agents

  let counts []
  let f 0
  let m 0

  ;; random-walk for every agent
  foreach ts [ agent ->
    if-else [gender] of agent = "f" [
      set f (f + 1)
    ][
      set m (m + 1)
    ]
  ]
  set counts lput f counts
  set counts lput m counts
  report counts
end

to go
  tick
  random-walk
end

to go-500
  if-else ticks < 500 [
    tick
    random-walk
  ] [
    ; show-board-vars
    stop
  ]
end

to update-board-vars
  ask boards [

    ;print divergencies_from_first_ku

    ifelse curr_board = [] ; duplicate last board if current is empty
    [ set board_history lput (last board_history) board_history ] ; duplicate last board
    [ set board_history lput curr_board board_history ] ; add current board to end of history

    ; RESET VARS - this wasn't resetting...
    set compat_with_init_ctr 0
    set incompat_with_init_ctr 0

    foreach divergencies_from_first_ku [ d ->
      if-else d < c_threshold
      [ set compat_with_init_ctr compat_with_init_ctr + 1 ]
      [ set incompat_with_init_ctr incompat_with_init_ctr + 1 ]
    ]

    ; type "CTR COMPAT   - " print compat_with_init_ctr
    ; type "CTR INCOMPAT - " print incompat_with_init_ctr

    set ratio 1
    if (compat_with_init_ctr + incompat_with_init_ctr) != 0 [ ; prevent division by zero
      set ratio precision (compat_with_init_ctr / (compat_with_init_ctr + incompat_with_init_ctr)) 2
    ]

    ;if-else ratio >= 0.49 and ratio <= 0.51
    ;[
    ;  set compat_ratio 0
    ;] ; polarised
    ;[
      if-else ratio > 0.5
      [ set compat_ratio 1 ]
      [ set compat_ratio -1 ]
    ;]

    ; add to 'history' vars
    set all_compat_ratios lput compat_ratio all_compat_ratios
    set all_divergencies_from_first_ku lput divergencies_from_first_ku all_divergencies_from_first_ku
    set all_compatibilities lput sort compatibilities all_compatibilities

    set curr_agents sort remove-duplicates curr_agents ; sort before adding
    set agents_history lput curr_agents agents_history

    set male_participation 0
    set female_participation 0

    foreach curr_agents [ agent_number ->
      let a get-agent-from-who agent_number
      ifelse [gender] of a = "m" [
        set male_participation male_participation + 1
      ][
        set female_participation female_participation + 1
      ]
    ]

    ; reset 'curr' vars
    set curr_board []
    set curr_agents[]
    set compatibilities []
  ]
end

to-report get-agent-from-who [agent_number]
  let agent-to-report 0
  ask agents [
    if agent_number = who [
      set agent-to-report self
    ]
  ]
  report agent-to-report
end

to show-board-vars
  ask boards [
    ;; type "\nCurr burst  : " print curr_board
    type "All bursts  : " print board_history
    ;; type "Curr agents : " print curr_agents
    type "All agents  : " print agents_history

    type "All compats : " print all_compatibilities
  ]
end

; compats was this without report
to-report compats-report
  let string 0.0

  ask boards[
    foreach all_compatibilities [ c ->
      ;; type c print ","
      set string (sentence string c)
    ]
  ]
  report string
end

; report to python all compatibility ratios, to get average length before topic divergence
to-report compat-ratio-report
  let string 1
  let last_compat 1
  ask boards[
    foreach all_compat_ratios [ c ->

      if-else c = 0 [set string (sentence string last_compat)] ; report last compat if polarised
      [
        set string (sentence string c)
        set last_compat c ; update last when not polarised
      ]
    ]
  ]
  report string
end

to-report compat-ratio-report-with-polarisation
  let string 1
  ask boards[
    foreach all_compat_ratios [ c ->
      set string (sentence string c)
    ]
  ]
  report string
end

to-report burst-length-report
  let string 0

  ask boards[
    foreach board_history [ board_elements ->
      set string (sentence string length board_elements)
    ]
  ]
  report string
end

to-report get-all-compatibilities
  let string 0

  ask boards[
    foreach all_compatibilities [ c ->
      set string (sentence string c)
    ]
  ]
  report remove-item 0 string
end

to-report get-in-topic
  let string 1

  ask boards[
    foreach all_divergencies_from_first_ku [ divergency_burst ->
      foreach divergency_burst [ c ->
        print c
        if-else c >= c_threshold
        [ set string (sentence string 1) ] ; in-topic
        [ set string (sentence string 0) ] ; out-of-topic
      ]
    ]
  ]
  report string
end

to-report get-board-history
  let string 0

  ask boards[
    foreach board_history [ board_elements ->
      set string (sentence string board_elements)
    ]
  ]
  report remove-item 0 string
end

to random-walk
  let ts sort agents

  let male_exploit_ctr 0
  let female_exploit_ctr 0

  set divergencies_from_first_ku []

  foreach ts [ agent ->
    ;; change focused ku
    ifelse random-float 1 < [prob_exploit] of agent
    [
      exploit agent

      if-else [gender] of agent = "m" [
        set male_exploit_ctr male_exploit_ctr + 1
      ][
        set female_exploit_ctr female_exploit_ctr + 1
      ]
    ]
    [
      explore agent
    ]
  ]

  let gender_counts get-gender-count
  let f first gender_counts
  let m last gender_counts

  if Method = "Attention Norm" [
    ; sum agents exploiting / sum all agents
    set exploit_trend (male_exploit_ctr + female_exploit_ctr) / (f + m)

    ; type "Trends : Exploit " type precision exploit_trend 2 type " Explore " print precision explore_trend 2

    if-else exploit_trend >= 0.5
    [ set attention_norm "exploit" ]
    [ set attention_norm "explore" ]

    ; type "Attention norm is - to " print attention_norm
  ]

  foreach ts [agent ->
    if Method = "Compatibility" [ add-to-board-compatibility-method agent ]
    if Method = "Attention Norm" [ add-to-board-attention-norm-method-fix agent ]
  ]

  update-board-vars
end

to add-to-board-compatibility-method [agent]

  ask boards [
    ; get last board's kus
    let ku_on_board mean last board_history
    ;type "Mean  last burst " print ku_on_board
    ; calc compat focused_ku x ku_on_board
    let compat get-compat-as-decimal [focused_ku] of agent ku_on_board

    if compat > c_threshold [
      if not member? [focused_ku] of agent curr_board [
        set curr_board lput [focused_ku] of agent curr_board
        set curr_agents lput [who] of agent curr_agents
        set compatibilities lput compat compatibilities
        set divergencies_from_first_ku lput (1 - get-compat-as-decimal [focused_ku] of agent first_ku) divergencies_from_first_ku
      ]
    ]

    set curr_board remove-duplicates curr_board
    ;;type "KUs on Board:" print curr_board
  ]
end

to add-to-board-attention-norm-method-fix [agent]
  ; let posts false
  let compatible false
  let compat 0
  ; type "agent " print [who] of agent
  ask boards [
    let compat_list []

    foreach last board_history [ ku_on_board ->
      set compat_list lput ( get-compat-as-decimal [focused_ku] of agent ku_on_board ) compat_list
    ]

    set compat median compat_list ; median dá sort automaticamente
    ; print compat
    if compat > c_threshold [ set compatible true ]

    let chance ( 1 - posting_chance )

    if ((compatible)     and (attention_norm = "exploit")) [ set chance posting_chance ]
    if ((not compatible) and (attention_norm = "explore")) [ set chance posting_chance ]

    ;; type attention_norm type " ; compat - " type compat type " : " type chance print "%"
    let r random-float 1
    if r < chance [
      if not member? [focused_ku] of agent curr_board [
        set curr_board lput [focused_ku] of agent curr_board
        set curr_agents lput [who] of agent curr_agents
        set compatibilities lput compat compatibilities
        set divergencies_from_first_ku lput (1 - get-compat-as-decimal [focused_ku] of agent first_ku) divergencies_from_first_ku
      ]
    ]

    set curr_board remove-duplicates curr_board
    ;;type "KUs on Board:" print curr_board
  ]
end

;; switch focus to a directly connected KU
to exploit [agent]
  ;; check every tuple from list of links
  foreach [list_of_links] of agent [ tuple ->

    ;; if tuple has focused_ku the other element is going to be focused
    if member? [focused_ku] of agent tuple [

      ask agent[
        ;; we can switch tuples like this instead of having another condition
        let next_focused_ku abs(focused_ku - item 0 tuple - item 1 tuple)

        ;; compatibility
        let compare_compat get-compat-as-decimal focused_ku next_focused_ku

        ;; print
        ;; type self type " is now focusing on " type next_focused_ku
        ;; type ", " type compare_compat type "% compatible with " print focused_ku

        ;; switch focus
        set focused_ku next_focused_ku
        ;; exit loop
        stop
      ]
    ]
  ]
end

;; switch focus to a directly UNconnected KU
to explore [agent]
  ;; for each agent
  ask agent[
    ;; list of KUs not connected to the KU being focused on currently
    let not_connected_kus kus

    foreach list_of_links [ tuple ->
      ;; check if focused ku is part of tuple
      if member? focused_ku tuple [
        ;; remove connected kus
        set not_connected_kus remove item 0 tuple not_connected_kus
        set not_connected_kus remove item 1 tuple not_connected_kus
      ]
    ]

    ;; no KU to switch to
    if length not_connected_kus = 0 [
      ;; type "This KU is connected to all KUs, can't switch\n"
      stop
    ]

    ;; sort lists for cleaner output
    let k_kus sort filter [ ku -> not member? ku not_connected_kus ] kus
    set not_connected_kus sort not_connected_kus

    ;; type "KUs connected to " type focused_ku type ": " print k_kus
    ;; type "KUs NOT connected to " type focused_ku type ": " print not_connected_kus

    ;; next_focused_ku is a random ku that doesn't directly connect with focused_ku
    let next_focused_ku one-of not_connected_kus

    ;; compatibility
    let compare_compat get-compat-as-decimal focused_ku next_focused_ku

    ;; print
    ;; type self type " is now focusing on " type next_focused_ku
    ;; type ", " type compare_compat type "% compatible with " print focused_ku

    ;; switch focus
    set focused_ku next_focused_ku
  ]
end

to-report set_links [agent]
  ;; get copy of agent's kus
  let kus_list sort [kus] of agent

  let temp_list [list_of_links] of agent

  ;; for each pair of kus ( ku_a, ku_b )
  foreach kus_list [ ku_a ->
    let a decimal-to-binary ku_a

    foreach kus_list [ ku_b ->
      let b decimal-to-binary ku_b

      ;; are they different?
      if a != b [
        ;; are they more compatible than the compatibility threshold?
        if compatibility a b > c_threshold [
          ;; create tuple ( a, b )
          let tuple create_link ku_a ku_b agent

          ;; check for duplicates and add to temporary list
          if not member? tuple temp_list [
            ;; type a type " and " type b type " are compatible - " print (compatibility a b)
            set temp_list lput tuple temp_list
          ]
        ]
      ]
    ]
  ]
  ;; report temporary list, to add to agent
  report temp_list
end

to-report create_link [ a b agent ] ;; 2 KUs/

  if b < a [
    let temp b
    set b a
    set a temp
  ] ;; a is always the smallest number

  ;; create tuple [ a b ]
  let tuple list a b
  ;; type tuple

  ;; if [ a b ] is NOT in the list of links
  if not ( member? ([list_of_links] of agent) tuple) [
    report tuple
  ]
end

;; HELPERS

to-report decimal-to-binary [n]
  ;; array position
  let pos 0
  ;; current bit value
  let bit 0
  ;; all bits
  let arr []

  loop[
    (
      ;; if all positions of the array are filled
      ifelse pos = ku_len [
        report reverse arr ;; return
      ]
      ;; else
      [
        ;; get next bit
        ifelse (remainder n 2) = 1
        [
          set bit 1
        ]
        [
          set bit 0
        ]
        ;; add it to array
        set arr insert-item pos arr bit
        set pos pos + 1
        ;; update n
        set n floor(n / 2)
      ]
    )
  ]
end

to-report normalized-hamming-distance [ bit_arr_1 bit_arr_2 ]
  report (length remove true (map [[?1 ?2] -> ?1 = ?2] bit_arr_1 bit_arr_2)) / ku_len
end

to-report compatibility [ bit_arr_1 bit_arr_2 ]
  report 1 - (normalized-hamming-distance bit_arr_1 bit_arr_2)
end

to-report get-compat-as-decimal [ dec1 dec2 ]
  report 1 - (normalized-hamming-distance decimal-to-binary dec1 decimal-to-binary dec2)
end

; Profiler -> https://simulatingcomplexity.wordpress.com/2015/03/23/netlogo-profiler/
;; insert-item pos list item
;; lput item list (insert in last)
;; item pos list
;; ( first / last ) list
@#$#@#$#@
GRAPHICS-WINDOW
6
50
229
274
-1
-1
6.52
1
10
1
1
1
0
0
0
1
-16
16
-16
16
1
1
1
ticks
30.0

BUTTON
6
10
69
43
NIL
setup\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
77
11
140
44
NIL
go\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
7
321
176
354
ku_number
ku_number
0
250
150.0
10
1
NIL
HORIZONTAL

SLIDER
7
361
175
394
ku_len
ku_len
0
32
16.0
2
1
NIL
HORIZONTAL

SLIDER
7
401
176
434
c_threshold
c_threshold
0
1
0.5
0.05
1
NIL
HORIZONTAL

SLIDER
7
282
175
315
number_of_agents
number_of_agents
1
33
15.0
2
1
NIL
HORIZONTAL

BUTTON
149
11
231
44
NIL
go-500
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
8
480
100
513
males
males
0
5
1.0
1
1
NIL
HORIZONTAL

SLIDER
8
440
100
473
females
females
0
5
1.0
1
1
NIL
HORIZONTAL

SLIDER
107
480
289
513
male_prob_exploit
male_prob_exploit
0
1
0.6
0.05
1
NIL
HORIZONTAL

SLIDER
108
440
288
473
female_prob_exploit
female_prob_exploit
0
1
0.6
0.05
1
NIL
HORIZONTAL

PLOT
242
10
514
148
Compatibility of Posted KUs
tick
compat.
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"mean" 1.0 0 -7500403 true "" "plot mean last [all_compatibilities] of one-of boards"
"max" 1.0 2 -13791810 true "" "plot max last [all_compatibilities] of one-of boards"
"min" 1.0 2 -2674135 true "" "plot min last [all_compatibilities] of one-of boards"

PLOT
7
587
331
715
M / F Posting
tick
gender
0.0
10.0
0.0
1.0
true
true
"" ""
PENS
"male" 1.0 0 -987046 true "" "plot [male_participation] of one-of boards"
"female" 1.0 0 -955883 true "" "plot [female_participation] of one-of boards"

CHOOSER
9
518
289
563
Method
Method
"Compatibility" "Attention Norm"
1

PLOT
242
157
598
288
Attention Norm
ticks
Trends
0.0
10.0
0.0
1.0
true
true
"" ""
PENS
"Explore" 1.0 0 -8630108 true "" "plot ( 1 - exploit_trend )"
"Exploit" 1.0 0 -13840069 true "" "plot exploit_trend"
"Male Exploit" 1.0 0 -1184463 true "" "plot male_exploit_trend"
"Female Exploit" 1.0 0 -955883 true "" "plot female_exploit_trend"

PLOT
522
10
837
147
Initial KU Divergence
ticks
hamming
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"mean" 1.0 0 -9276814 true "" "plot mean divergencies_from_first_ku"
"max" 1.0 2 -13791810 true "" "plot max divergencies_from_first_ku"
"min" 1.0 2 -2674135 true "" "plot min divergencies_from_first_ku"

PLOT
303
441
841
562
Burst length
ticks
length
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot length last [board_history] of one-of boards"

PLOT
199
301
592
421
Topic Divergence
ticks
compat
0.0
10.0
-2.0
2.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot compat_ratio"

PLOT
605
156
837
421
% Compatible w/ First KU
Tick
Compatibility with First KU
0.0
500.0
0.35
0.8
false
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot [ratio] of one-of boards"

SLIDER
377
586
552
619
posting_chance
posting_chance
0
1
0.8
0.05
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
