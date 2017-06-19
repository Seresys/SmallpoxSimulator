breed [airports airport]
breed [ports port]
breed [ground-patches ground-patch]
breed [planes plane]
breed [boats boat]

breed [waypoints waypoint]

undirected-link-breed [ airways airway ]
undirected-link-breed [ waterways waterway ]

turtles-own [
  name
]

patches-own [
  ground
  sane-population
  immune-population
  dead-population
  vaccinated-population
  contagious-population
  injected-by-click
  infected-list
  infected-population
  death-by-day-list
]

globals [
  max-population
  min-population
  start-incubation
  end-incubation
  start-contagious
  end-contagious
  start-lethality
  end-lethality
  start-remission
  end-remission
  mouse-was-down?
]

planes-own [
  departure
  arrival
  infected
  transport-ratio
]

boats-own [
  departure
  arrival
  infected
  transport-ratio
  current-waypoint
  last-waypoint
  arrival-waypoint
]

waypoints-own [
  id
  neighbor-list
]

to setup
  clear-all
  clear-turtles
  clear-patches
  reset-ticks
  constants-setup
  sea-setup
  ground-setup
  airports-setup
  ports-setup
  waypoints-setup
  if (allow-air-traffic) [
    planes-setup
  ]
  if (allow-water-traffic) [
    boats-setup
  ]
end

to go
  mouse-manager
  ask planes [ plane-go ]
  if (allow-air-traffic) [
    respawn-planes
  ]
  ask boats [ boat-go ]
  if (allow-water-traffic) [
    respawn-boats
  ]
  ask grounds [ ground-go ]
  tick
end

to-report mouse-clicked?
  report (mouse-was-down? = true and not mouse-down?)
end

to constants-setup
  set max-population 1000000
  set min-population 200000
  set start-incubation 0
  set end-incubation 12
  set start-contagious 19
  set end-contagious 21
  set start-lethality 22
  set end-lethality 28
  set start-remission 29
  set end-remission 42
end

to mouse-manager
  let mouse-is-down? mouse-down?
  if mouse-clicked? [
    if (action-on-click = "infect") [
      infect-ground mouse-xcor mouse-ycor
    ]
    if (action-on-click = "vaccinate") [
      vaccinate-ground mouse-xcor mouse-ycor
    ]
    if (action-on-click = "information") [
      display-ground mouse-xcor mouse-ycor
    ]
  ]
  set mouse-was-down? mouse-is-down?
end

to infect-ground [ x y ]
  ask patches with [pxcor = round x and pycor = round y and ground = true] [
    set injected-by-click infected-number-by-click
  ]
end

to display-ground [ x y ]
  ask patches with [pxcor = round x and pycor = round y and ground = true] [
    output-type "Information for patch on " output-type pxcor output-type ", " output-print pycor
    output-type "Total population : "  output-print round(get-total-population)
    output-type "Sane population : "  output-type round(sane-population) output-type " (" output-type round(get-ratio-sane-patch * 100) output-print "%)"
    output-type "Infected population : "  output-type round(get-infected-population) output-type " (" output-type round(get-ratio-infected-patch * 100) output-print "%)"
    output-type "Immune population : "  output-type round(immune-population) output-type " (" output-type round(get-ratio-immune-patch * 100) output-print "%)"
    output-type "Vaccinated population : "  output-type round(vaccinated-population) output-type " (" output-type round(get-ratio-vaccinated-patch * 100) output-print "%)"
    output-type "Dead population : "  output-type round(dead-population) output-type " (" output-type round(get-ratio-dead-patch * 100) output-print "%)"
    output-print "============="
  ]
end

to vaccinate-ground [ x y ]
  ask patches with [((((pxcor - x) * (pxcor - x)) + ((pycor - y) * (pycor - y))) <= (vaccin-radius * vaccin-radius)) and ground = true] [
    let nb-vaccinated round(sane-population * vaccinated-percentage / 100)
    set sane-population sane-population - nb-vaccinated
    set vaccinated-population vaccinated-population + nb-vaccinated
  ]
end

to-report grounds
  report patches with [ground = true]
end

to sea-setup
  ask patches [set pcolor blue]
  ask patches [set ground false]
end

to ground-setup
  import-pcolors "worldmap_foreground.png"
  ask patches [
    if pcolor != blue [
      set pcolor white
      set ground true
      init-patch
    ]
  ]
end

to init-patch
  set sane-population population-setup
  set immune-population 0
  set contagious-population 0
  set dead-population 0
  set infected-population 0
  set vaccinated-population 0
  set infected-list (list)
  set death-by-day-list (list)
end

to ground-go
  let number-infected get-infected-today ;; new infected number
  let duration-lethality end-lethality - start-lethality + 1 ;; duration of lethality period

  set sane-population sane-population - number-infected ;; new number of sane population
  set infected-list fput number-infected infected-list ;; switch list to right by introducing new number of infected
  set infected-population infected-population + number-infected

  ;; Adding new immune population + delete last element of infected
  if (length infected-list > end-remission + 1) [
    set immune-population immune-population + last infected-list
    set infected-population infected-population - last infected-list
    set infected-list but-last infected-list
  ]

  ;; Adding contagious population
  if (length infected-list >= start-contagious + 1) [
    set contagious-population contagious-population + item start-contagious infected-list
  ]

  ;; Deleting contagious population
  if (length infected-list >= end-contagious + 1) [
    set contagious-population contagious-population - item end-contagious infected-list
  ]

  ;; Adding death by day
  if (length infected-list > start-lethality + 1) [
    let total-number-death (item start-lethality infected-list) / 100 * lethality-percent
    set death-by-day-list fput (total-number-death / duration-lethality) death-by-day-list
  ]

  if (length death-by-day-list > duration-lethality) [
    set death-by-day-list but-last death-by-day-list
  ]

  ;; Make people die
  let index 0
  while[ index < length death-by-day-list][
    let death-by-day item index death-by-day-list
    let new-infected-number item (start-lethality + index) infected-list - death-by-day
    set infected-population infected-population - death-by-day
    set dead-population dead-population + death-by-day

    if new-infected-number < 0 [
      set new-infected-number 0
    ]
    set infected-list replace-item (start-lethality + index) infected-list new-infected-number
    set index index + 1
  ]

  update-color

end

to-report get-uninfected-population
  report sane-population + immune-population
end

to-report get-infected-population
  report infected-population
end

to-report get-contagious-population
  report contagious-population
end

to update-color
  if(population-type-to-show = "infected")[
    let color-value round(255 - (55 + (200 * get-ratio-infected-patch)))
    if (color-value = 200)[
      set color-value 255
    ]
    set pcolor rgb 255 color-value color-value
  ]

  if(population-type-to-show = "dead")[
    let color-value 255 - round(255 * get-ratio-dead-patch)
    set pcolor rgb color-value color-value color-value
  ]

  if(population-type-to-show = "immune")[
    let color-value round(255 - (55 + (200 * get-ratio-immune-patch)))
    if (color-value = 200)[
      set color-value 255
    ]
    set pcolor rgb color-value 255 color-value
  ]
  if(population-type-to-show = "vaccinated")[
    let color-value round(255 - (55 + (200 * get-ratio-vaccinated-patch)))
    if (color-value = 200)[
      set color-value 255
    ]
    set pcolor rgb color-value color-value 255
  ]
end

to-report get-ratio-infected-patch
  report infected-population / get-total-population
end

to-report get-ratio-dead-patch
  report dead-population / get-total-population
end

to-report get-ratio-immune-patch
  report immune-population / get-total-population
end

to-report get-ratio-sane-patch
  report sane-population / get-total-population
end

to-report get-ratio-vaccinated-patch
  report vaccinated-population / get-total-population
end

to-report get-total-population
  report infected-population + get-uninfected-population + dead-population + vaccinated-population
end

to-report get-infected-today
  if (sane-population <= 0 )[
    report 0
  ]

  let injected 0

  if (injected-by-click != 0)[
    set injected injected-by-click
    set injected-by-click 0
  ]

  let infected-today get-infected-by-neighbours * sane-population + injected

  if(sane-population - infected-today < 0)[
    set infected-today sane-population
  ]

  report infected-today
end

to-report get-infected-by-neighbours
  let neighbours get-neighbors
  let population-neighbor get-uninfected-population + dead-population + vaccinated-population
  let contagious-neighbor get-contagious-population

  ask neighbours [
    set population-neighbor population-neighbor + get-uninfected-population + dead-population + vaccinated-population
    set contagious-neighbor contagious-neighbor + get-contagious-population
  ]

  let density (get-infected-population + get-uninfected-population + dead-population + vaccinated-population) / max-population

  report (contagion-rate / 100) * (contagious-neighbor / population-neighbor) * density
end

to-report population-setup
  report rand min-population max-population
end

to-report get-neighbors
  report (patch-set neighbors with [ground = true])
end

to planes-setup
  create-planes plane-max-number [ plane-setup ]
end

to plane-setup
  set shape "airplane"
  set color black
  set size 3

  set departure one-of airports
  set arrival one-of airports

  while [ [xcor] of departure = [xcor] of arrival and  [ycor] of departure = [ycor] of arrival ] [
    set arrival one-of airports
  ]
  set infected false
  move-to departure
  set heading towards arrival
  infect-transport plane-contagion-threshold
end

to infect-transport [threshold]
  let ratio 0
  let x xcor
  let y ycor
  ask patches with [pxcor = round x and pycor = round y] [
    set ratio get-contagious-population / (get-uninfected-population + vaccinated-population)* 100
  ]
  if ( ratio > threshold) [
    set infected true
    set color rgb round (255 * ratio) 0 0
    set transport-ratio ratio
  ]
end

to infect-arrival
  let x [xcor] of arrival
  let y [ycor] of arrival
  let ratio transport-ratio

  ask patches with [pxcor = round x and pycor = round y] [
    set injected-by-click ratio / 100 * sane-population
  ]
end

to plane-go
  fd plane-speed
  if distance arrival < 1 [
    infect-arrival
    die
  ]
end

to respawn-planes
  if count(planes) < plane-max-number [
    create-planes plane-max-number - count(planes) [ plane-setup ]
  ]
end

to boats-setup
  create-boats boat-max-number [ boat-setup ]
end

to boat-setup
  set shape "boat"
  set color black
  set size 3

  set departure one-of ports
  set arrival one-of ports

  while [ [xcor] of departure = [xcor] of arrival and  [ycor] of departure = [ycor] of arrival ] [
    set arrival one-of ports
  ]

  set current-waypoint get-nearest-waypoint-from departure
  set arrival-waypoint get-nearest-waypoint-from arrival
  set last-waypoint 0
  move-to departure
  infect-transport boat-contagion-threshold
end

to-report get-nearest-waypoint-from [turtle-point]
  report min-one-of waypoints [distance turtle-point]
end

to boat-go
  ;; constantly move the boat
  fd boat-speed
  if current-waypoint = 0 [ set current-waypoint get-nearest-waypoint-from last-waypoint ]
  set heading towards current-waypoint
  let distance-to-arrival distance arrival
  ;; check if boat is on the nearest waypoint to destination
  if current-waypoint != arrival-waypoint and current-waypoint != arrival and distance current-waypoint < 1 [
    let waypoint-to-go 0
    let arrival-to-go arrival
    let min-distance 10000
    let supposed-last last-waypoint
    ;; for each neighbor of the current waypoint
    foreach [neighbor-list] of current-waypoint [ neighbor ->
      ask one-of waypoints with [id = neighbor][
        ;; if the destination differs from the last-waypoint (no loops)
        if supposed-last = 0 or [id] of supposed-last != neighbor [
          ;; we select the nearest to the arrival (most-likely the best road)
          if (distance arrival-to-go < min-distance) [
            set min-distance distance arrival-to-go
            set waypoint-to-go one-of waypoints with [id = neighbor]
          ]
        ]
      ]
    ]
    set last-waypoint current-waypoint
    set current-waypoint waypoint-to-go
  ]
  if current-waypoint = arrival-waypoint and distance current-waypoint < 1 [
    set current-waypoint arrival
  ]
  ;; launch arrival procedure
  if distance-to-arrival < 1 [
    infect-arrival
    die
  ]
end

to respawn-boats
  if count(boats) < boat-max-number [
    create-boats boat-max-number - count(boats) [ boat-setup ]
  ]
end

to-report rand [min-value max-value]
  report random (max-value - min-value) + min-value
end

to ports-setup
  create-ports 1 [ port-setup "Vancouver" 41 -24 ]
  create-ports 1 [ port-setup "Valparaiso" 75 -104 ]
  create-ports 1 [ port-setup "Vigo" 125 -32 ]
  create-ports 1 [ port-setup "Rotterdam" 135 -24 ]
  create-ports 1 [ port-setup "Kobe" 235 -41 ]
  create-ports 1 [ port-setup "Halifax" 85 -30 ]
  create-ports 1 [ port-setup "Houston" 54 -45 ]
  create-ports 1 [ port-setup "Los Angeles" 39 -42 ]
  create-ports 1 [ port-setup "Singapour" 222 -71 ]
  create-ports 1 [ port-setup "South Louisiana" 61 -44 ]
  create-ports 1 [ port-setup "Charleston" 66 -42 ]
  create-ports 1 [ port-setup "Durban" 156 -97 ]
  create-ports 1 [ port-setup "Dubai" 174 -50 ]
  create-ports 1 [ port-setup "Seattle" 41 -30 ]
  create-ports 1 [ port-setup "Le Pirée" 148 -37 ]
  create-ports 1 [ port-setup "Erdemir" 156 -34 ]
  create-ports 1 [ port-setup "Mundra" 187 -52 ]
  create-ports 1 [ port-setup "Kaohsiung" 228 -51 ]
  create-ports 1 [ port-setup "Inch'On" 229 -38 ]
  create-ports 1 [ port-setup "Hong-Kong" 221 -51 ]
  create-ports 1 [ port-setup "Shanghai" 226 -45 ]
  create-ports 1 [ port-setup "Hambourg" 140 -23 ]
  create-ports 1 [ port-setup "Felixstowe" 131 -24 ]
  create-ports 1 [ port-setup "Buenos Aires" 86 -104 ]
  create-ports 1 [ port-setup "Melbourne" 242 -108 ]
  create-ports 1 [ port-setup "Brisbane" 252 -97 ]
  create-ports 1 [ port-setup "Sidney" 248 -104 ]
  create-ports 1 [ port-setup "Auckland" 266 -108 ]
  create-ports 1 [ port-setup "Lagos" 135 -68 ]
  create-ports 1 [ port-setup "Dakar" 117 -52 ]
  create-ports 1 [ port-setup "Le Cap" 146 -103 ]
  create-ports 1 [ port-setup "Jakarta" 221 -80 ]
  create-ports 1 [ port-setup "Colombo" 197 -66 ]
  create-ports 1 [ port-setup "Port Saïd" 155 -44 ]
  create-ports 1 [ port-setup "Alexandrie" 151 -43 ]
  create-ports 1 [ port-setup "Reykjavik" 118 -14 ]
  create-ports 1 [ port-setup "Murmansk" 152 -10 ]
  create-ports 1 [ port-setup "Karachi" 182 -48 ]
  create-ports 1 [ port-setup "Porklang" 212 -70 ]
  create-ports 1 [ port-setup "Port Gentil" 138 -74 ]
  create-ports 1 [ port-setup "Rabat" 124 -42 ]
  create-ports 1 [ port-setup "Port Saïd" 155 -44 ]
  create-ports 1 [ port-setup "Salvador" 97 -84 ]
  create-ports 1 [ port-setup "Recife" 100 -80 ]
  create-ports 1 [ port-setup "Belem" 93 -76 ]
  create-ports 1 [ port-setup "Cartagena" 70 -63 ]
  create-ports 1 [ port-setup "Acapulco" 49 -56 ]
  create-ports 1 [ port-setup "Anchorage" 37 -17 ]
  create-ports 1 [ port-setup "Toamasina" 169 -90 ]
  create-ports 1 [ port-setup "Port Saïd" 155 -44 ]
  create-ports 1 [ port-setup "La Havane" 66 -52 ]
  create-ports 1 [ port-setup "Port Moresby" 253 -82 ]
end

to airports-setup
  create-airports 1 [ airport-setup "Paris" 133 -29 ]
  create-airports 1 [ port-setup "Montréal" 76 -27 ]
  create-airports 1 [ airport-setup "New-York" 71 -38 ]
  create-airports 1 [ airport-setup "Los Angeles" 39 -42 ]
  create-airports 1 [ airport-setup "Rio de Janeiro" 95 -92 ]
  create-airports 1 [ airport-setup "Buenos Aires" 86 -104 ]
  create-airports 1 [ airport-setup "Dakar" 117 -52 ]
  create-airports 1 [ airport-setup "Madrid" 127 -35 ]
  create-airports 1 [ airport-setup "Rome" 141 -34 ]
  create-airports 1 [ airport-setup "Berlin" 140 -25 ]
  create-airports 1 [ airport-setup "Stockholm" 143 -17 ]
  create-airports 1 [ airport-setup "Moscou" 165 -22 ]
  create-airports 1 [ airport-setup "Istanbul" 152 -35 ]
  create-airports 1 [ airport-setup "Londres" 131 -25 ]
  create-airports 1 [ airport-setup "Dublin" 126 -23 ]
  create-airports 1 [ airport-setup "Mumbai" 190 -55 ]
  create-airports 1 [ airport-setup "New Delhi" 194 -47 ]
  create-airports 1 [ airport-setup "Le Caire" 155 -44 ]
  create-airports 1 [ airport-setup "Dubai" 174 -50 ]
  create-airports 1 [ airport-setup "Hong-Kong" 221 -51 ]
  create-airports 1 [ airport-setup "Tokyo" 239 -39 ]
  create-airports 1 [ airport-setup "Sidney" 248 -104 ]
  create-airports 1 [ airport-setup "Le Cap" 146 -103 ]
  create-airports 1 [ airport-setup "Johannesbourg" 154 -95 ]
  create-airports 1 [ airport-setup "Nairobi" 162 -69 ]
  create-airports 1 [ airport-setup "Accra" 132 -66 ]
  create-airports 1 [ airport-setup "Perth" 223 -102 ]
  create-airports 1 [ airport-setup "Wellington" 265 -109 ]
  create-airports 1 [ airport-setup "Ulan Bator" 209 -30 ]
  create-airports 1 [ airport-setup "Pékin" 220 -36 ]
  create-airports 1 [ airport-setup "Shanghai" 226 -45 ]
  create-airports 1 [ airport-setup "Melbourne" 242 -108 ]
  create-airports 1 [ airport-setup "Brisbane" 252 -97 ]
  create-airports 1 [ airport-setup "Bali" 226 -81 ]
  create-airports 1 [ airport-setup "Singapour" 222 -71 ]
  create-airports 1 [ airport-setup "Bangkok" 213 -60 ]
  create-airports 1 [ airport-setup "Los Angeles" 39 -42 ]
  create-airports 1 [ airport-setup "Manille" 229 -59 ]
  create-airports 1 [ airport-setup "Panama" 61 -63 ]
  create-airports 1 [ airport-setup "Mexico" 49 -55 ]
  create-airports 1 [ airport-setup "Brasilia" 92 -82 ]
  create-airports 1 [ airport-setup "Santiago" 75 -98 ]
  create-airports 1 [ airport-setup "La Paz" 78 -84 ]
  create-airports 1 [ airport-setup "Honolulu" 3 -55 ]
  create-airports 1 [ airport-setup "Seattle" 41 -30 ]
  create-airports 1 [ airport-setup "Toronto" 74 -30 ]
  create-airports 1 [ airport-setup "Denver" 47 -36 ]
  create-airports 1 [ airport-setup "Houston" 54 -45 ]
  create-airports 1 [ airport-setup "Miami" 65 -47 ]
  create-airports 1 [ airport-setup "Detroit" 67 -35 ]
  create-airports 1 [ airport-setup "Caracas" 79 -64 ]
  create-airports 1 [ airport-setup "Bogota" 71 -70 ]
  create-airports 1 [ airport-setup "Vienne" 144 -27 ]
  create-airports 1 [ airport-setup "Jeddah" 163 -52 ]
  create-airports 1 [ airport-setup "Los Angeles" 39 -42 ]
end

to waypoints-setup
  create-waypoints 1 [ waypoint-setup 1 33 -23 [2] ]
  create-waypoints 1 [ waypoint-setup 2 30 -33 [1 3] ]
  create-waypoints 1 [ waypoint-setup 3 33 -46 [2 4 6] ]
  create-waypoints 1 [ waypoint-setup 4 18 -46 [3 5] ]
  create-waypoints 1 [ waypoint-setup 5 6 -46 [107 4] ]
  create-waypoints 1 [ waypoint-setup 6 39 -57 [3 7] ]
  create-waypoints 1 [ waypoint-setup 7 50 -65 [6 8] ]
  create-waypoints 1 [ waypoint-setup 8 60 -72 [30 7 9] ]
  create-waypoints 1 [ waypoint-setup 9 60 -83 [8 10] ]
  create-waypoints 1 [ waypoint-setup 10 66 -90 [9 15 16] ]
  create-waypoints 1 [ waypoint-setup 11 3 -94 [86 12] ]
  create-waypoints 1 [ waypoint-setup 12 14 -94 [11 13] ]
  create-waypoints 1 [ waypoint-setup 13 28 -94 [12 14] ]
  create-waypoints 1 [ waypoint-setup 14 40 -94 [13 15] ]
  create-waypoints 1 [ waypoint-setup 15 54 -94 [9 16] ]
  create-waypoints 1 [ waypoint-setup 16 71 -99 [10 17] ]
  create-waypoints 1 [ waypoint-setup 17 70 -109 [16 18] ]
  create-waypoints 1 [ waypoint-setup 18 72 -118 [17 19] ]
  create-waypoints 1 [ waypoint-setup 19 78 -124 [18 20] ]
  create-waypoints 1 [ waypoint-setup 20 89 -124 [19 21] ]
  create-waypoints 1 [ waypoint-setup 21 88 -118 [20 22] ]
  create-waypoints 1 [ waypoint-setup 22 93 -109 [21 23] ]
  create-waypoints 1 [ waypoint-setup 23 100 -103 [22 24] ]
  create-waypoints 1 [ waypoint-setup 24 104 -94 [23 25] ]
  create-waypoints 1 [ waypoint-setup 25 108 -84 [26 24] ]
  create-waypoints 1 [ waypoint-setup 26 106 -75 [57 58 25 27] ]
  create-waypoints 1 [ waypoint-setup 27 98 -69 [26 28] ]
  create-waypoints 1 [ waypoint-setup 28 89 -63 [27 29] ]
  create-waypoints 1 [ waypoint-setup 29 82 -60 [28 30 33] ]
  create-waypoints 1 [ waypoint-setup 30 68 -58 [29 31] ]
  create-waypoints 1 [ waypoint-setup 31 59 -50 [32 30] ]
  create-waypoints 1 [ waypoint-setup 32 71 -50 [33 31 29] ]
  create-waypoints 1 [ waypoint-setup 33 80 -42 [32 34 29] ]
  create-waypoints 1 [ waypoint-setup 34 89 -36 [33 35] ]
  create-waypoints 1 [ waypoint-setup 35 99 -35 [34 36] ]
  create-waypoints 1 [ waypoint-setup 36 108 -34 [35 37] ]
  create-waypoints 1 [ waypoint-setup 37 117 -33 [38 47] ]
  create-waypoints 1 [ waypoint-setup 38 124 -28 [37 39] ]
  create-waypoints 1 [ waypoint-setup 39 130 -26 [38 40] ]
  create-waypoints 1 [ waypoint-setup 40 136 -23 [39 43] ]
  create-waypoints 1 [ waypoint-setup 43 135 -13 [40 44] ]
  create-waypoints 1 [ waypoint-setup 44 142 -8 [43 45] ]
  create-waypoints 1 [ waypoint-setup 45 151 -7 [44] ]
  create-waypoints 1 [ waypoint-setup 47 123 -38 [48 55] ]
  create-waypoints 1 [ waypoint-setup 48 131 -38 [47 49] ]
  create-waypoints 1 [ waypoint-setup 49 138 -37 [48 50] ]
  create-waypoints 1 [ waypoint-setup 50 145 -40 [49 51] ]
  create-waypoints 1 [ waypoint-setup 51 153 -41 [50 52] ]
  create-waypoints 1 [ waypoint-setup 52 159 -48 [51 53] ]
  create-waypoints 1 [ waypoint-setup 53 163 -55 [52 54] ]
  create-waypoints 1 [ waypoint-setup 54 169 -60 [53 71] ]
  create-waypoints 1 [ waypoint-setup 55 115 -45 [47 56] ]
  create-waypoints 1 [ waypoint-setup 56 111 -54 [55 57] ]
  create-waypoints 1 [ waypoint-setup 57 113 -65 [56 58 26] ]
  create-waypoints 1 [ waypoint-setup 58 121 -72 [57 59] ]
  create-waypoints 1 [ waypoint-setup 59 131 -72 [58 60] ]
  create-waypoints 1 [ waypoint-setup 60 136 -80 [59 61] ]
  create-waypoints 1 [ waypoint-setup 61 136 -90 [60 62] ]
  create-waypoints 1 [ waypoint-setup 62 139 -99 [61 63] ]
  create-waypoints 1 [ waypoint-setup 63 142 -107 [62 64] ]
  create-waypoints 1 [ waypoint-setup 64 152 -110 [63 65] ]
  create-waypoints 1 [ waypoint-setup 65 161 -104 [64 66] ]
  create-waypoints 1 [ waypoint-setup 66 164 -97 [65 67] ]
  create-waypoints 1 [ waypoint-setup 67 165 -88 [66 68] ]
  create-waypoints 1 [ waypoint-setup 68 168 -79 [67 69 68] ]
  create-waypoints 1 [ waypoint-setup 69 173 -73 [68 70] ]
  create-waypoints 1 [ waypoint-setup 70 177 -65 [69 71 54] ]
  create-waypoints 1 [ waypoint-setup 71 180 -58 [70 72] ]
  create-waypoints 1 [ waypoint-setup 72 189 -58 [71 73] ]
  create-waypoints 1 [ waypoint-setup 73 191 -65 [72 74] ]
  create-waypoints 1 [ waypoint-setup 74 196 -72 [73 75] ]
  create-waypoints 1 [ waypoint-setup 75 202 -66 [76 77 74] ]
  create-waypoints 1 [ waypoint-setup 76 207 -61 [75] ]
  create-waypoints 1 [ waypoint-setup 77 209 -74 [75 78] ]
  create-waypoints 1 [ waypoint-setup 78 216 -81 [77 79] ]
  create-waypoints 1 [ waypoint-setup 79 222 -84 [78 80] ]
  create-waypoints 1 [ waypoint-setup 80 230 -86 [79 81] ]
  create-waypoints 1 [ waypoint-setup 81 237 -83 [80 82 96] ]
  create-waypoints 1 [ waypoint-setup 82 243 -83 [81 83] ]
  create-waypoints 1 [ waypoint-setup 83 252 -85 [82 84] ]
  create-waypoints 1 [ waypoint-setup 84 259 -94 [83 85 87] ]
  create-waypoints 1 [ waypoint-setup 85 272 -92 [84 86] ]
  create-waypoints 1 [ waypoint-setup 86 282 -91 [11 85] ]
  create-waypoints 1 [ waypoint-setup 87 257 -102 [86 88] ]
  create-waypoints 1 [ waypoint-setup 88 251 -109 [87 89] ]
  create-waypoints 1 [ waypoint-setup 89 245 -116 [88 90] ]
  create-waypoints 1 [ waypoint-setup 90 236 -113 [89 91] ]
  create-waypoints 1 [ waypoint-setup 91 219 -109 [90 92] ]
  create-waypoints 1 [ waypoint-setup 92 211 -96 [79 91 93] ]
  create-waypoints 1 [ waypoint-setup 93 201 -94 [92 94] ]
  create-waypoints 1 [ waypoint-setup 94 192 -92 [93 95] ]
  create-waypoints 1 [ waypoint-setup 95 182 -89 [68 94] ]
  create-waypoints 1 [ waypoint-setup 96 226 -79 [81 97] ]
  create-waypoints 1 [ waypoint-setup 97 220 -75 [96 98] ]
  create-waypoints 1 [ waypoint-setup 98 220 -67 [97 99] ]
  create-waypoints 1 [ waypoint-setup 99 224 -60 [98 100] ]
  create-waypoints 1 [ waypoint-setup 100 227 -54 [101 99] ]
  create-waypoints 1 [ waypoint-setup 101 235 -50 [100 102 104] ]
  create-waypoints 1 [ waypoint-setup 102 232 -41 [101 103] ]
  create-waypoints 1 [ waypoint-setup 103 234 -34 [102] ]
  create-waypoints 1 [ waypoint-setup 104 242 -44 [101 105] ]
  create-waypoints 1 [ waypoint-setup 105 252 -44 [104 106] ]
  create-waypoints 1 [ waypoint-setup 106 263 -43 [105 107] ]
  create-waypoints 1 [ waypoint-setup 107 276 -44 [5 106] ]
  ask one-of waypoints with [id = 14] [ create-waterways-with other waypoints with [id = 15] [hide-link] ]
  ask one-of waypoints with [id = 36] [ create-waterways-with other waypoints with [id = 37] [hide-link] ]
  ask one-of waypoints with [id = 15] [ create-waterways-with other waypoints with [id = 10] [hide-link] ]
  ask one-of waypoints with [id = 26] [ create-waterways-with other waypoints with [id = 58] [hide-link] ]
end

to airport-setup [airportName x y]
  set xcor x
  set ycor y
  set name airportName
  set shape "star"
  set color grey
  set size 3
  create-airways-with other airports [ hide-link ]
end

to port-setup [portName x y]
  set xcor x
  set ycor y
  set name portName
  set shape "triangle"
  set color black
  set size 3

end

to waypoint-setup [waypointId x y neighborList]
  set xcor x
  set ycor y
  set id waypointId
  set label id
  set neighbor-list neighborList
  set hidden? true
  foreach neighbor-list [neighbor -> create-waterways-with other waypoints with [ id = neighbor] [ hide-link ]]
end

@#$#@#$#@
GRAPHICS-WINDOW
418
16
1856
655
-1
-1
5.0
1
10
1
1
1
0
1
1
1
0
285
-125
0
1
1
1
ticks
30.0

BUTTON
24
119
87
152
Start
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SLIDER
145
570
270
603
boat-speed
boat-speed
0.1
0.5
0.45
0.05
1
NIL
HORIZONTAL

SLIDER
16
570
140
603
boat-max-number
boat-max-number
0
100
82.0
1
1
NIL
HORIZONTAL

SLIDER
16
607
140
640
plane-max-number
plane-max-number
0
100
56.0
1
1
NIL
HORIZONTAL

SLIDER
145
607
270
640
plane-speed
plane-speed
0.1
0.5
0.5
0.05
1
NIL
HORIZONTAL

BUTTON
99
120
163
153
Setup
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

SWITCH
276
607
415
640
allow-air-traffic
allow-air-traffic
1
1
-1000

SWITCH
276
570
415
603
allow-water-traffic
allow-water-traffic
1
1
-1000

BUTTON
23
80
163
113
Hide/Show Airways
ask airways [set hidden? not hidden?]
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
23
41
180
74
Hide/Show Waterways
ask waterways [ set hidden? not hidden? ]
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
19
345
273
378
infected-number-by-click
infected-number-by-click
1
200000
200000.0
1
1
persons
HORIZONTAL

SLIDER
20
411
192
444
contagion-rate
contagion-rate
0
100
100.0
1
1
%
HORIZONTAL

SLIDER
233
680
450
713
plane-contagion-threshold
plane-contagion-threshold
0
100
0.0
1
1
%
HORIZONTAL

SLIDER
14
680
226
713
boat-contagion-threshold
boat-contagion-threshold
0
100
0.0
1
1
%
HORIZONTAL

CHOOSER
203
41
365
86
population-type-to-show
population-type-to-show
"infected" "dead" "immune" "vaccinated"
0

TEXTBOX
27
10
177
29
Setup buttons
15
0.0
1

TEXTBOX
22
299
205
337
Infection setup buttons
15
0.0
1

TEXTBOX
19
527
169
546
Solutions buttons
15
0.0
1

SLIDER
19
477
191
510
lethality-percent
lethality-percent
0
100
38.0
1
1
%
HORIZONTAL

TEXTBOX
22
327
275
355
Number of person to infect when clicking on a patch
11
0.0
1

TEXTBOX
22
394
172
412
Contagiousness of the disease
11
0.0
1

TEXTBOX
21
461
290
479
Percentage of people infected dying from the disease
11
0.0
1

CHOOSER
203
94
341
139
action-on-click
action-on-click
"infect" "vaccinate" "information"
0

OUTPUT
24
187
363
288
11

SLIDER
233
734
450
767
vaccin-radius
vaccin-radius
1
20
10.0
1
1
patches
HORIZONTAL

SLIDER
14
734
227
767
vaccinated-percentage
vaccinated-percentage
0
100
49.0
1
1
%
HORIZONTAL

TEXTBOX
25
163
175
182
Patch information
15
0.0
1

TEXTBOX
17
551
167
569
Water and air traffic
11
0.0
1

TEXTBOX
15
719
165
737
Vaccination
11
0.0
1

TEXTBOX
16
663
477
681
Boat and plane are considered infected above this threshold of population on departure patch
11
0.0
1

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

boat
true
0
Polygon -7500403 true true 150 0 135 30 120 60 105 120 105 150 105 180 120 240 135 270 150 300 165 270 180 240 195 180 195 150 195 120 180 60 165 30

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
NetLogo 6.0.1
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
