;;; structure formula

(structure-formula

  (variant-duration 180.0)
  (number-of-instrument-groups 1)
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
      (performance (normal plucking))
      (dynamics    (ppp pp p mf f ff fff))
      (compass (1 01) (5 12)))

    (instrument marimba
      (chordsize 1 4) 
      (performance (normal bowing))
      (dynamics    (mf f ff fff))
      (compass (1 01) (5 12))))

  (instrument-table
    (0 3)
    (0 1)
    (2 3))

  (entrydelays (0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8))

  (entrydelay-table
    (0 1 2)
    (3 4 5)
    (0 1 2 3 4 5 6 7))

  (performance-table
    (0 1)
    (0 1 2 3 4)
    (0))

  (dynamics-table
    (0 1 2 3 4 5 6)
    (2 3 4)
    (0 6))

  ;; selection principles reference:
  ;;   alea
  ;;   series
  ;;   (sequence (0 1 2 3))
  ;;   (ratio (0 3) (1 2) (2 1))            -- (index weight) pairs
  ;;   (group (element    alea)             -- element selector: alea | series
  ;;          (repetition series)           -- repetition count selector: alea | series
  ;;          (repetitions 2 5))            -- min and max repetitions
  ;;   (tendency (section portion (start min max) (end min max)) ...)

  (principles
    (instrument alea)
    (entrydelay  alea)
    (performance alea)
    (dynamics (tendency
      ;;         portion  start-min start-max  end-min end-max
      (section   1.0      (start 0.5 0.5)      (end 0.0 1.0))
      (section   1.0      (start 0.5 1.0)      (end 0.5 0.0)))))

  (combination
    (entrydelay  none)
    (performance none)
    (dynamics    none))

  (union none)

  (density instrument-density)

  (hierarchy (Ins Dyn Per))

)
