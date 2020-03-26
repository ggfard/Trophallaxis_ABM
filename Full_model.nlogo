; changes: The model used the amount of food that needs to be exchanged as a trophallaxis duration instead of setting this variable beforehand
;; Our assumption is that at each encounter bees will give exchange (delta_food/2) units of their food 
;; We experimentally set the maximum time for food transfer is equal to 50 ticks in which the bees can transfer (1-0)/2 units of food

extensions [ Nw vid array table csv GIS array csv]
globals
[
  tro_counter         ; counts the number of trophallaxis events
  all_counter
  n1_counter          ; counts every neighboring event if the neighbors have different food values
  n2_counter          ; counts every neighboring event if the neighbors are not occupied
  n3_counter          ; counts all the neighboring event
  u_counter           ; counts all unique encounters
  target              ; the id of the bee who is doing the food exchange
  delta_food          ; the difference between the amount of food in the full bee's stomach and her hungry neighbor
  epsilon             ; decides when the model stops
  hungry_counter      ; counts the number of hungry bees
  var                 ; the previous value of the variance of the food of all bees
  newvar              ; the new value of the variance of the food of all bees
  deltavar            ; the difference between the variance of food (used to set our stopping condition)
  hungry_left         ; Number of agents who still have zero food
  food_transfer_rate  ; the constant rate of food exchange
  max_transfer_t      ; the constant to show the maximum time (in ticks) that two bees need to stop for exchanging food
  rand_delta_food     ; Set if you want to implement random values of food exchange/durations
  rad
  clusters
  run-seed
  donor_list
  target_list
  foods_list
  xcor_list
  ycor_list
  donor
  attr
  attr_rad
  step-size
  neighbor_count
  block-count
  L
]

breed [fulls full]           ; red full bees
breed [hungries hungry]      ; blue hungry bees

turtles-own
[
  hungry?       ; true if it is a hungry bee (initially true for all hungries)
  occupied?     ; true if the bee is busy with a food exchange operation (initially false for all bees)
  neighborhood  ; an agenset containing all the existing neighbors of a bee at each tick
  times         ; number of times that a bee experienced trophallaxis
  food          ; amount of food currently stored in a bee
  goal          ; the id of the last bee that gives/takes food
  delta_t       ; the duration left of the trophallaxis event
  counts
  unique?
  distance_traveled
  dist_arr
  initial_pos
  x0
  y0
  n_count
  d
  old-xcor
  old-ycor
  distance-to-block
  my-neighbors
  moved?
  blocks
  dist_traveled
  wrong?
  small?
  ok?
  zero?
  leader
  followers

]
patches-own
[
  agents_here
  double_agents?
]

to setup

  clear-all

  set run-seed new-seed
  random-seed run-seed

  ask patches [ set pcolor white ]
  ask n-of Number_of_bees patches [ sprout 1 ]

  set-default-shape fulls "circle"
  set-default-shape hungries "circle"
  set max_transfer_t 50 ; should be set experimentally
  set food_transfer_rate ( 0.5 / max_transfer_t) ; ~0.01 units of food at each time step
  set tro_counter 0
  set rand_delta_food 0
  set n3_counter 0
  set n2_counter 0
  set n1_counter 0
  set newvar 0.1
  set var 0
  set rad 1.1
  set donor_list [0]
  set target_list [0]
  set foods_list [0]
  set xcor_list [0]
  set ycor_list [0]
  set L max-pxcor - min-pxcor
  set attr_rad attraction_radius
  set step-size 1


  ask turtles
  [

    set breed hungries
    set size 1 ;; A turtle is the same size as a patch
    ;setxy random-pxcor random-pycor
    set x0 pxcor
    set y0 pycor
    set food 0
    set hungry? true
    set color 2
    set heading random 360
    set times 0
    set delta_t 0
    set occupied? false
    set counts 0
    set unique? true
    set agents_here 1
    set initial_pos sqrt (xcor ^ 2 + ycor ^ 2 )
    set n_count count (other turtles) in-radius attr_rad
    set neighborhood no-turtles
    set moved? false
    set distance-to-block 0
    set dist_traveled 0
    set ok? false
    set wrong? false
    set small? false
    set zero? false
    set leader self

  ]

  ask n-of ( (fraction_of_fed_bees) * Number_of_bees / 100 ) turtles
  [

    set breed fulls
    set size 1 ;; A turtle is the same size as a patch
    set food 1
    set times 0
    set x0 pxcor
    set y0 pycor
    set heading random 360
    set hungry? false
    set color red
    set delta_t 0
    set occupied? false
    set counts 0
    set unique? true
    set dist_arr array:from-list n-values 1000 [0]
  ]

  reset-ticks

end

to go

  set epsilon 10 ^ (-8)
  set deltavar abs (newvar - var)
  if (  deltavar  <  epsilon and newvar < 0.0008  ) ;  stopping condition
   [
     stop
   ]

  ask turtles
  [ ;pd
    set old-xcor xcor
    set old-ycor ycor
    check-clusters

    ;; if they are currently occupied and their timer is not zero,
    ;; then don't move, and just decrease their timer until it's zero

    ifelse ( occupied? = true )
    [
      ifelse (counts) != 0
        [
          set counts  ( counts - 1 )
        ]
        [
          ;; o.w. if they are occupied but their timer reached zero (end of food exchange),
          ;; change the status to not occupied, and continue moving

          set occupied? false
          attempt-move
      ]
    ]
    ;; if they are not currently occupied,
    ;; search for hungry neighbors that are also not currently occupied
    ;; The distance to or a from a patch is measured from the center of the patch using [distance myself]

    ;if (occupied? = false )
    [
      set neighborhood other turtles in-radius rad
      ; choose your closest neighbor
      set target min-one-of neighborhood [distance myself]

      ifelse target != nobody
        [
          set n3_counter n3_counter + 1
          ifelse ( [occupied?] of target = false ) ; make sure that the target is also free
            [
              set n2_counter n2_counter + 1
              set delta_food food - [food] of target
              ;set rand_delta_food random-float (delta_food)
              if (delta_food != 0 )
              [
                set n1_counter n1_counter + 1
              ]
              ifelse ( delta_food > 0)
                [
                   create-link-with target
                   set donor who
                   ask my-links
                   [
                     hide-link
                     ;set color gray
                     ;set thickness delta_food
                   ]

                  ;set delta_food abs(delta_food)
                  set tro_counter tro_counter + 1
                  ;face target
                  set occupied? true

                  ; set the time for transfering delta_food/2
                  set delta_t round ((delta_food / 2 ) / food_transfer_rate )
                  ;set delta_food food - [food] of target
                  set counts delta_t
                  ;set agents_here agents_here + 1
                  exchange_food

                ]
            [ ;; o.w. if you don't have more food, continue searching
              attempt-move ]
          ]

          [ ;; o.w. if your hungry neighbor is occupied, continue searching
            attempt-move ]
        ]
        [  ;; o.w. if there are no hungry neighbors that are not occupied,
           ;; continue moving and searching for one
           attempt-move ]
      ]
  ;update neighbors
  set n_count count (other turtles) in-radius attr_rad
  ]
 ; count the unique encounters
 set u_counter count links

 ; count the hungries at the end of each tick
 set hungry_left count turtles with [food = 0] 


 tick
end

to attempt-move

  update-heading theta
  if attr_rad >= 1 [check-attraction]

  ; identify all potential blocks
  set my-neighbors other turtles in-radius 2
  set blocks other turtles-on my-neighbors in-cone 2 180 
  set block-count count blocks
  set distance-to-block 0

  ;if there is a blocking neighbors:
  ifelse block-count != 0
  [
    check-blockers
    continue_based_on_block_
  ]

 ;if no blocking neighbors:
  [ ;pd
    set dist_traveled 1
    fd dist_traveled
    set d distancexy old-xcor old-ycor
  ]

end

to update-heading [th]
  let h1 heading
  let coin random-float 1
  ifelse coin > 0.5
  [ set heading heading + random-float th ]
  [ set heading heading - random-float th ]
  let h2 heading
end

To check-blockers
  ask blocks
      [
        set distance-to-block distance myself
        if (distance-to-block > 0 and distance-to-block < 0.9)
        [ set wrong? true ] ; should not happen (brown)
        if (distance-to-block <= 1.1 and distance-to-block > 0.9 )
        [ set zero? true ] ; should choose another direction to move (pink)
        if (distance-to-block > 1 and distance-to-block < 2 )
        [ set small? true ] ; should take a small step (blue)
        if (distance-to-block = 2) [
          set ok? true] ; can move one whole step (yellow)
      ]
end

To continue_based_on_block_type

  ifelse any? blocks with [wrong? = true]
  [set dist_traveled 0]

    [ifelse any? blocks with [zero? = true]
      [ update-heading 180
        let new-neighbors other turtles in-radius 2 * step-size
        set blocks other turtles-on new-neighbors in-cone (2 * step-size) 180
        let n_block-count count blocks

        ;if there is a blocking neighbors:
        ifelse n_block-count != 0
        [
        check-blockers
        set dist_traveled (min ([distance-to-block] of blocks) - 1) ]
        [set dist_traveled 1]
      ]

    [ifelse any? blocks with [small? = true]
      [set dist_traveled (min ([distance-to-block] of blocks) - 1) ]

    [if any? blocks with [ok? = true]
        [set dist_traveled 1]
      ]

    ]
    ]
 fd dist_traveled
 set d distancexy old-xcor old-ycor
end

To check-attraction
  if any? other turtles in-radius ( attr_rad )
  [
    let buddy one-of other turtles in-radius ( attr_rad  )
    face buddy
  ]

end

to check-clusters
  set followers count turtles with [leader = myself]

  if any? turtles in-radius attr_rad [
    let budds turtles in-radius attr_rad with [leader != myself]
    ask budds[
      set followers followers + (count budds)
      set leader [leader] of myself
    ]
  ]
end

;; for turtles that are not occupied and found hungry neighbores,
;; have changed their status to occupied, and will start giving food

to exchange_food

  set donor_list lput donor donor_list
  set foods_list lput delta_food foods_list
  set xcor_list lput xcor xcor_list
  set ycor_list lput ycor ycor_list

  ;show target
  let transfer_amount delta_food / 2
  set times times + 1
  set food food - transfer_amount

  set color scale-color 15 food  0.9 0
  set hungry? false

  ask target
  [
    set occupied? true
    set hungry? false
    set target_list lput [who] of target target_list

    set food food + transfer_amount
    set counts abs ( round (transfer_amount / food_transfer_rate ))
    set color scale-color 15 food  0.9 0 
    set times times + 1
  ]

;; update the value of variances if and only if the food exchange happens

  set var newvar
  set newvar variance [food] of turtles

end
@#$#@#$#@
GRAPHICS-WINDOW
290
39
809
559
-1
-1
13.91
1
10
1
1
1
0
1
1
1
-16
16
-16
16
0
0
1
ticks
30.0

BUTTON
115
119
185
152
SETUP
setup
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
52
208
248
241
Number_of_bees
Number_of_bees
0
2000
110.0
10
1
NIL
HORIZONTAL

BUTTON
115
162
185
195
GO
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
52
286
247
331
theta
theta
0 3 5 7 10 12 15 20 30 45 60 90 100 120 140 180
15

SLIDER
52
246
248
279
fraction_of_fed_bees
fraction_of_fed_bees
0
100
10.0
10
1
NIL
HORIZONTAL

MONITOR
80
490
207
536
Recording Status
vid:recorder-status
17
1
11

PLOT
842
46
1144
230
OVERALL FOOD DISTRIBUTION
food
Number of bees
0.0
1.0
0.0
50.0
false
false
"set-plot-x-range min [food] of turtles max [food] of turtles + 0.05\nset-plot-y-range 0 count turtles" ""
PENS
"default" 0.025 1 -16448764 true "" "histogram [food] of turtles\n"

MONITOR
347
570
511
616
Trophallaxis Encounters
tro_counter
17
1
11

MONITOR
518
572
625
617
All Encounters
n3_counter
17
1
11

MONITOR
842
496
994
542
Max exchange duration
max [delta_t] of turtles
17
1
11

MONITOR
1003
496
1085
541
NIL
hungry_left
17
1
11

MONITOR
634
572
764
618
Unique Encounters
u_counter
2
1
11

PLOT
1159
495
1512
627
Number of agents with food > 0.1
NIL
# of bees
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count turtles with [food > 0.1]"

MONITOR
117
66
185
108
Time
ticks
18
1
10

MONITOR
82
438
207
483
Number of Patches
count patches
17
1
11

MONITOR
113
386
172
432
Density
precision (Number_of_bees / (count patches)) 2
17
1
11

PLOT
1158
47
1508
232
Average distance traveled
Time
Average Distance
0.0
50.0
0.0
1.0
true
true
"" ""
PENS
"Fed" 1.0 0 -5298144 true "" "if ticks > 0 [plot mean [d] of turtles with [breed = fulls]]"
"All" 1.0 0 -16777216 true "" "if ticks > 0 [plot mean [d] of turtles]"

SLIDER
50
338
246
371
attraction_radius
attraction_radius
0
10
2.5
0.5
1
NIL
HORIZONTAL

PLOT
842
238
1146
487
AVERAGE FOOD LEVEL
Time
Food
0.0
10.0
0.0
1.0
true
true
"" ""
PENS
"Deprived" 1.0 0 -16448764 true "" "plot mean [food] of hungries"
"Fed" 1.0 0 -5298144 true "" "plot mean [food] of fulls"

PLOT
1159
240
1509
486
Cluster size
time
Number of bees in clusters
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot length remove-duplicates [followers] of turtles "

@#$#@#$#@
## WHAT IS IT?

This is a simplified model of the honey bee trophallaxis behavior.
In this version we added excluded volume so agents are not allowed to overlap at all.
Also, if they are attracted to each other and there is no room to move forward towards each other they don't move! 

## HOW IT WORKS

Initially there are two breeds of full and hungry bees. The full bees start the trophallaxis process as soon as they find hungry bees present in their neighborhood patches. The trophallaxis is done by adding/subtracting  0.1 to/from the amount of food in the stomach of the hungry/full bees at each tick untill both bees have nearly the same amount of food in their stomach and then they become regular (yellow) bees. The model stops when all the bees are regular and there are no hungry bees.


## HOW TO USE IT

1. Choose a number of bees between 10 to 200 using the number_of_bees slider. 
2. Choose a theta as an angle for the random walk ( i.e. choosing 7.5 is equal to allowing the bees to change the angle of the random walk in each step using a random number in range of (-pi/24, pi/24))

## THINGS TO NOTICE

This version of the model use the amount of food that needs to be exchanged as a trophallaxis time instead of setting this variable beforehand. Full bees start from the center pf the arena. The model stops when the difference between the variance of the food of the full and hungry bees is less than a very small epsilon. All bees change/scale their color related to how much food they have in them. lighter colors represent lower amount of food.


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

bee
true
0
Polygon -1184463 true false 152 149 77 163 67 195 67 211 74 234 85 252 100 264 116 276 134 286 151 300 167 285 182 278 206 260 220 242 226 218 226 195 222 166
Polygon -16777216 true false 150 149 128 151 114 151 98 145 80 122 80 103 81 83 95 67 117 58 141 54 151 53 177 55 195 66 207 82 211 94 211 116 204 139 189 149 171 152
Polygon -7500403 true true 151 54 119 59 96 60 81 50 78 39 87 25 103 18 115 23 121 13 150 1 180 14 189 23 197 17 210 19 222 30 222 44 212 57 192 58
Polygon -16777216 true false 70 185 74 171 223 172 224 186
Polygon -16777216 true false 67 211 71 226 224 226 225 211 67 211
Polygon -16777216 true false 91 257 106 269 195 269 211 255
Line -1 false 144 100 70 87
Line -1 false 70 87 45 87
Line -1 false 45 86 26 97
Line -1 false 26 96 22 115
Line -1 false 22 115 25 130
Line -1 false 26 131 37 141
Line -1 false 37 141 55 144
Line -1 false 55 143 143 101
Line -1 false 141 100 227 138
Line -1 false 227 138 241 137
Line -1 false 241 137 249 129
Line -1 false 249 129 254 110
Line -1 false 253 108 248 97
Line -1 false 249 95 235 82
Line -1 false 235 82 144 100

bee 2
true
0
Polygon -1184463 true false 195 150 105 150 90 165 90 225 105 270 135 300 165 300 195 270 210 225 210 165 195 150
Rectangle -16777216 true false 90 165 212 185
Polygon -16777216 true false 90 207 90 226 210 226 210 207
Polygon -16777216 true false 103 266 198 266 203 246 96 246
Polygon -6459832 true false 120 150 105 135 105 75 120 60 180 60 195 75 195 135 180 150
Polygon -6459832 true false 150 15 120 30 120 60 180 60 180 30
Circle -16777216 true false 105 30 30
Circle -16777216 true false 165 30 30
Polygon -7500403 true true 120 90 75 105 15 90 30 75 120 75
Polygon -16777216 false false 120 75 30 75 15 90 75 105 120 90
Polygon -7500403 true true 180 75 180 90 225 105 285 90 270 75
Polygon -16777216 false false 180 75 270 75 285 90 225 105 180 90
Polygon -7500403 true true 180 75 180 90 195 105 240 195 270 210 285 210 285 150 255 105
Polygon -16777216 false false 180 75 255 105 285 150 285 210 270 210 240 195 195 105 180 90
Polygon -7500403 true true 120 75 45 105 15 150 15 210 30 210 60 195 105 105 120 90
Polygon -16777216 false false 120 75 45 105 15 150 15 210 30 210 60 195 105 105 120 90
Polygon -16777216 true false 135 300 165 300 180 285 120 285

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
14
Circle -16777216 true true 0 0 300
Circle -1 true false 15 15 270

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

mybee
true
14
Polygon -16777216 true true 152 149 77 163 67 195 67 211 74 234 85 252 100 264 116 276 134 286 151 300 167 285 182 278 206 260 220 242 226 218 226 195 222 166
Polygon -16777216 true true 150 149 128 151 114 151 98 145 80 122 80 103 81 83 95 67 117 58 141 54 151 53 177 55 195 66 207 82 211 94 211 116 204 139 189 149 171 152
Polygon -16777216 true true 151 54 119 59 96 60 81 50 78 39 87 25 103 18 115 23 121 13 150 1 180 14 189 23 197 17 210 19 222 30 222 44 212 57 192 58
Polygon -16777216 true true 70 185 74 171 223 172 224 186
Polygon -16777216 true true 67 211 71 226 224 226 225 211 67 211
Polygon -16777216 true true 91 257 106 269 195 269 211 255
Line -1 false 144 100 70 87
Line -1 false 70 87 45 87
Line -1 false 45 86 26 97
Line -1 false 26 96 22 115
Line -1 false 22 115 25 130
Line -1 false 26 131 37 141
Line -1 false 37 141 55 144
Line -1 false 55 143 143 101
Line -1 false 141 100 227 138
Line -1 false 227 138 241 137
Line -1 false 241 137 249 129
Line -1 false 249 129 254 110
Line -1 false 253 108 248 97
Line -1 false 249 95 235 82
Line -1 false 235 82 144 100

mycircle
false
14
Circle -16777216 true true 0 0 300
Circle -1 true false 105 105 90

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
NetLogo 6.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment1" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles with [hungry? = true]</metric>
    <metric>ticks</metric>
    <metric>mean [food] of fulls</metric>
    <metric>mean [food] of hungries</metric>
    <enumeratedValueSet variable="Number_of_bees">
      <value value="50"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="theta">
      <value value="180"/>
      <value value="18"/>
      <value value="7.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="trophallaxis_time">
      <value value="1"/>
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment5" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>tro_counter</metric>
    <metric>n_counter</metric>
    <enumeratedValueSet variable="Number_of_bees">
      <value value="10"/>
      <value value="50"/>
      <value value="100"/>
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fraction_of_fulls">
      <value value="10"/>
      <value value="30"/>
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="trophallaxis_time">
      <value value="3"/>
      <value value="7"/>
      <value value="10"/>
      <value value="15"/>
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="theta">
      <value value="20"/>
      <value value="60"/>
      <value value="80"/>
      <value value="120"/>
      <value value="180"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment3" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>tro_counter</metric>
    <metric>n_counter</metric>
    <metric>count turtles with [hungry? = true]</metric>
    <enumeratedValueSet variable="fraction_of_fulls">
      <value value="10"/>
      <value value="20"/>
      <value value="30"/>
      <value value="40"/>
      <value value="50"/>
      <value value="60"/>
      <value value="70"/>
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number_of_bees">
      <value value="10"/>
      <value value="20"/>
      <value value="30"/>
      <value value="40"/>
      <value value="50"/>
      <value value="70"/>
      <value value="90"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="trophallaxis_time">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="theta">
      <value value="80"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles with [food = 0 ]</metric>
    <metric>count turtles with [food = 1 ]</metric>
    <metric>full_food</metric>
    <metric>hungry_food</metric>
    <metric>tro_counter</metric>
    <enumeratedValueSet variable="fraction_of_fulls">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number_of_bees">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="trophallaxis_time">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="theta">
      <value value="20"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles with [food = 0 ]</metric>
    <metric>count turtles with [food = 1 ]</metric>
    <metric>full_food</metric>
    <metric>hungry_food</metric>
    <metric>tro_counter</metric>
    <enumeratedValueSet variable="fraction_of_fulls">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number_of_bees">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="trophallaxis_time">
      <value value="3"/>
      <value value="7"/>
      <value value="10"/>
      <value value="15"/>
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="theta">
      <value value="20"/>
      <value value="60"/>
      <value value="80"/>
      <value value="120"/>
      <value value="180"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>allfoods</metric>
    <enumeratedValueSet variable="fraction_of_fulls">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number_of_bees">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="trophallaxis_time">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="theta">
      <value value="20"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>a</metric>
    <enumeratedValueSet variable="fraction_of_fulls">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number_of_bees">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="trophallaxis_time">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="theta">
      <value value="20"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="timeless" repetitions="50" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="5000"/>
    <metric>tro_counter</metric>
    <metric>variance [food] of turtles</metric>
    <enumeratedValueSet variable="fraction_of_fulls">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number_of_bees">
      <value value="10"/>
      <value value="20"/>
      <value value="30"/>
      <value value="40"/>
      <value value="50"/>
      <value value="70"/>
      <value value="100"/>
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="theta">
      <value value="0"/>
      <value value="10"/>
      <value value="20"/>
      <value value="40"/>
      <value value="60"/>
      <value value="100"/>
      <value value="120"/>
      <value value="140"/>
      <value value="180"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="newlarge" repetitions="50" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="3000"/>
    <metric>tro_counter</metric>
    <metric>newvar</metric>
    <metric>deltavar</metric>
    <metric>tro_counter</metric>
    <enumeratedValueSet variable="fraction_of_fulls">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number_of_bees">
      <value value="100"/>
      <value value="500"/>
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="theta">
      <value value="0"/>
      <value value="5"/>
      <value value="10"/>
      <value value="20"/>
      <value value="40"/>
      <value value="60"/>
      <value value="100"/>
      <value value="120"/>
      <value value="180"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="TorusRAfoodtransfer" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="10000"/>
    <metric>tro_counter</metric>
    <metric>food_transfer</metric>
    <metric>variance [food] of turtles</metric>
    <metric>max [delta_t] of turtles</metric>
    <enumeratedValueSet variable="fraction_of_fulls">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number_of_bees">
      <value value="10"/>
      <value value="25"/>
      <value value="50"/>
      <value value="100"/>
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="theta">
      <value value="0"/>
      <value value="3"/>
      <value value="5"/>
      <value value="7"/>
      <value value="10"/>
      <value value="12"/>
      <value value="15"/>
      <value value="20"/>
      <value value="40"/>
      <value value="60"/>
      <value value="100"/>
      <value value="120"/>
      <value value="140"/>
      <value value="180"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="counters" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="5000"/>
    <metric>tro_counter</metric>
    <metric>variance [food] of turtles</metric>
    <metric>food_transfer</metric>
    <metric>tro_counter</metric>
    <metric>n1_counter</metric>
    <metric>n2_counter</metric>
    <metric>n3_counter</metric>
    <enumeratedValueSet variable="fraction_of_fulls">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number_of_bees">
      <value value="10"/>
      <value value="25"/>
      <value value="50"/>
      <value value="100"/>
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="theta">
      <value value="0"/>
      <value value="10"/>
      <value value="20"/>
      <value value="40"/>
      <value value="90"/>
      <value value="120"/>
      <value value="180"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="non-trophallaxis" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>n3_counter</metric>
    <enumeratedValueSet variable="fraction_of_fulls">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number_of_bees">
      <value value="10"/>
      <value value="25"/>
      <value value="50"/>
      <value value="100"/>
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="theta">
      <value value="0"/>
      <value value="3"/>
      <value value="5"/>
      <value value="7"/>
      <value value="10"/>
      <value value="12"/>
      <value value="15"/>
      <value value="20"/>
      <value value="40"/>
      <value value="60"/>
      <value value="100"/>
      <value value="120"/>
      <value value="140"/>
      <value value="180"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="large-non-tro" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="10000"/>
    <metric>n3_counter</metric>
    <enumeratedValueSet variable="fraction_of_fulls">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number_of_bees">
      <value value="10"/>
      <value value="25"/>
      <value value="50"/>
      <value value="100"/>
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="theta">
      <value value="0"/>
      <value value="3"/>
      <value value="7"/>
      <value value="10"/>
      <value value="15"/>
      <value value="20"/>
      <value value="60"/>
      <value value="100"/>
      <value value="140"/>
      <value value="180"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="10000"/>
    <metric>n3_counter</metric>
    <enumeratedValueSet variable="fraction_of_fulls">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number_of_bees">
      <value value="10"/>
      <value value="25"/>
      <value value="50"/>
      <value value="100"/>
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="theta">
      <value value="0"/>
      <value value="3"/>
      <value value="7"/>
      <value value="10"/>
      <value value="15"/>
      <value value="20"/>
      <value value="60"/>
      <value value="100"/>
      <value value="140"/>
      <value value="180"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="fraction_of_fulls">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number_of_bees">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="theta">
      <value value="180"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="TDA" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="5000"/>
    <metric>get-locations</metric>
    <metric>variance [food] of turtles</metric>
    <metric>n3_counter</metric>
    <enumeratedValueSet variable="fraction_of_fulls">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number_of_bees">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="theta">
      <value value="180"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="unique_count" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="5000"/>
    <metric>n3_counter</metric>
    <metric>tro_counter</metric>
    <metric>u_counter</metric>
    <metric>u_counter / tro_counter</metric>
    <metric>steps</metric>
    <enumeratedValueSet variable="fraction_of_fulls">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number_of_bees">
      <value value="10"/>
      <value value="25"/>
      <value value="50"/>
      <value value="100"/>
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="theta">
      <value value="0"/>
      <value value="5"/>
      <value value="10"/>
      <value value="15"/>
      <value value="20"/>
      <value value="40"/>
      <value value="60"/>
      <value value="100"/>
      <value value="120"/>
      <value value="140"/>
      <value value="180"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MSD1" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="5000"/>
    <metric>msd</metric>
    <metric>variance [food] of turtles</metric>
    <enumeratedValueSet variable="fraction_of_fulls">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number_of_bees">
      <value value="10"/>
      <value value="25"/>
      <value value="50"/>
      <value value="100"/>
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="theta">
      <value value="0"/>
      <value value="5"/>
      <value value="10"/>
      <value value="15"/>
      <value value="20"/>
      <value value="40"/>
      <value value="60"/>
      <value value="90"/>
      <value value="120"/>
      <value value="180"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MSD2" repetitions="50" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="5000"/>
    <metric>tro_counter</metric>
    <metric>msd</metric>
    <enumeratedValueSet variable="fraction_of_fulls">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number_of_bees">
      <value value="10"/>
      <value value="25"/>
      <value value="50"/>
      <value value="100"/>
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="theta">
      <value value="0"/>
      <value value="10"/>
      <value value="20"/>
      <value value="40"/>
      <value value="90"/>
      <value value="120"/>
      <value value="180"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MSD3" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="5000"/>
    <metric>msd</metric>
    <metric>tro_counter</metric>
    <metric>n3_counter</metric>
    <enumeratedValueSet variable="fraction_of_fulls">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number_of_bees">
      <value value="10"/>
      <value value="25"/>
      <value value="50"/>
      <value value="100"/>
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="theta">
      <value value="0"/>
      <value value="20"/>
      <value value="40"/>
      <value value="90"/>
      <value value="180"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MSD-single" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="5000"/>
    <metric>msd</metric>
    <metric>tro_counter</metric>
    <metric>n3_counter</metric>
    <enumeratedValueSet variable="fraction_of_fulls">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number_of_bees">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="theta">
      <value value="0"/>
      <value value="20"/>
      <value value="40"/>
      <value value="90"/>
      <value value="180"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MSD-large" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="5000"/>
    <metric>msd</metric>
    <metric>tro_counter</metric>
    <metric>n3_counter</metric>
    <metric>hungry_left</metric>
    <enumeratedValueSet variable="fraction_of_fulls">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number_of_bees">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="theta">
      <value value="0"/>
      <value value="20"/>
      <value value="40"/>
      <value value="90"/>
      <value value="180"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MSD1000-large" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="5000"/>
    <metric>msd</metric>
    <metric>tro_counter</metric>
    <metric>n3_counter</metric>
    <metric>hungry_left</metric>
    <enumeratedValueSet variable="fraction_of_fulls">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number_of_bees">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="theta">
      <value value="0"/>
      <value value="20"/>
      <value value="40"/>
      <value value="90"/>
      <value value="180"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MSD250-large" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="5000"/>
    <metric>msd</metric>
    <metric>tro_counter</metric>
    <metric>n3_counter</metric>
    <enumeratedValueSet variable="fraction_of_fulls">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number_of_bees">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="theta">
      <value value="0"/>
      <value value="20"/>
      <value value="40"/>
      <value value="90"/>
      <value value="180"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="stationary" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>run-seed</metric>
    <metric>newvar</metric>
    <metric>u_counter</metric>
    <metric>tro_counter</metric>
    <metric>n3_counter</metric>
    <enumeratedValueSet variable="fraction_of_fulls">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number_of_bees">
      <value value="75"/>
      <value value="150"/>
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="theta">
      <value value="0"/>
      <value value="10"/>
      <value value="30"/>
      <value value="60"/>
      <value value="90"/>
      <value value="120"/>
      <value value="180"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="newlarge1000" repetitions="50" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="3000"/>
    <metric>tro_counter</metric>
    <metric>newvar</metric>
    <metric>deltavar</metric>
    <metric>tro_counter</metric>
    <metric>hungry_left</metric>
    <enumeratedValueSet variable="fraction_of_fulls">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number_of_bees">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="theta">
      <value value="0"/>
      <value value="5"/>
      <value value="10"/>
      <value value="20"/>
      <value value="40"/>
      <value value="60"/>
      <value value="100"/>
      <value value="120"/>
      <value value="180"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="final-wall25-paper-" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="5000"/>
    <metric>tro_counter</metric>
    <metric>u_counter</metric>
    <metric>n3_counter</metric>
    <metric>hungry_left</metric>
    <enumeratedValueSet variable="fraction_of_fulls">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number_of_bees">
      <value value="100"/>
      <value value="250"/>
      <value value="500"/>
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="theta">
      <value value="0"/>
      <value value="10"/>
      <value value="20"/>
      <value value="40"/>
      <value value="60"/>
      <value value="100"/>
      <value value="120"/>
      <value value="180"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="compare" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>giant-component-size</metric>
    <metric>mean [nw:betweenness-centrality] of turtles</metric>
    <metric>mean [nw:eigenvector-centrality] of turtles</metric>
    <metric>mean [nw:clustering-coefficient] of turtles</metric>
    <metric>closeness_center</metric>
    <metric>nw:mean-path-length</metric>
    <enumeratedValueSet variable="fraction_of_fulls">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number_of_bees">
      <value value="225"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="theta">
      <value value="0"/>
      <value value="45"/>
      <value value="90"/>
      <value value="120"/>
      <value value="180"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Charlotte" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>get-locations</metric>
    <metric>variance [food] of turtles</metric>
    <metric>n3_counter</metric>
    <metric>donor_list</metric>
    <enumeratedValueSet variable="fraction_of_fulls">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number_of_bees">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="theta">
      <value value="180"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="updated" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2000"/>
    <metric>length remove-duplicates [followers] of turtles</metric>
    <enumeratedValueSet variable="fraction_of_fulls">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number_of_bees">
      <value value="50"/>
      <value value="110"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="theta">
      <value value="180"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="attraction" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>length remove-duplicates [followers] of turtles</metric>
    <enumeratedValueSet variable="fraction_of_fulls">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attraction_bar">
      <value value="0"/>
      <value value="1"/>
      <value value="2"/>
      <value value="2.5"/>
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number_of_bees">
      <value value="30"/>
      <value value="40"/>
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="theta">
      <value value="60"/>
      <value value="180"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>tro_counter</metric>
    <metric>n3_counter</metric>
    <metric>u_counter</metric>
    <enumeratedValueSet variable="fraction_of_fulls">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attraction_bar">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number_of_bees">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="theta">
      <value value="180"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="fraction_of_fulls">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="attraction_bar">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number_of_bees">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="theta">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
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
1
@#$#@#$#@
