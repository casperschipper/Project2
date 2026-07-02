;;; structure formula

(structure-formula

  (variant-duration 180.0)
  (number-of-instrument-groups 3)
  (octave-division 12)

  (instruments
    (instrument guitar
      (chordsize 1 2)
      (performance (normal plucking bowing overtone1 overtone2))
      (dynamics    (ppp pp p mf f ff fff))
      (compass (1 01) (5 12)))

    (instrument piano
      (chordsize 1 10)
      (performance (normal bowing pizzicato))
      (dynamics    (ppp pp p mf f ff fff))
      (compass (1 01) (5 12)))

    (instrument basedrum
      (chordsize 1 1)
      (performance (plucking bowing))
      (dynamics    (ppp pp p mf f ff fff))
      (compass (1 01) (5 12)))

    (instrument marimba
      (chordsize 1 4)
      (performance (normal))
      (dynamics    (mf f ff fff))
      (compass (1 01) (5 12))))

  (instrument-table
    (0 1 2 3)
    (0 1)
    (2 3))

  (entrydelays (0.1 0.2 0.3 1.0 2.0 3.0 2.0 5.0))

  (entrydelay-table
    (0 1 2)
    (3 4 5)
    (0 1 2 3 4 5 6 7))

  (performance-table
    (0 1 2)
    (0 2)
    (1 2))

  (dynamics-table
    (0 1 2 3 4 5 6)
    (0 1 2 3 4 5 6)
    (0 1 2 3 4 5 6))

  (principles
    (instrument alea)
    (entrydelay  series)
    (performance alea)
    (dynamics (tendency
      ;;         portion  start-min start-max  end-min end-max
      (section   1.0      (start 0.2 0.3)      (end 0.8 0.9))
      (section   1.0      (start 0.0 0.1)      (end 0.1 1.0))
      (section   1.0      (start 0.0 1.0)      (end 0.0 0.1))
      (section   1.0      (start 0.2 0.8)      (end 0.8 0.2)))))

  (combination
    (entrydelay  none)
    (performance combination)
    (dynamics    combination))

  (union none)

  (density (autonomous (low 1) (high 3) (tr 12) (principle series)))

  (hierarchy (Dyn Ins Per))

)
