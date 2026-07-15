;;; structure formula
;;; evaluate this sexp with:
;;; dune exec bin/main_sexp.exe
(structure-formula

  (seed 1) ;; random seed; same seed + same formula always produces the same score
  (variant-duration 30.0)
  (octave-division 12) ;; ignored for the moment

  (dynamics (ppp pp p mf f ff fff))

  ;; master list of every performance mode used by any instrument below;
  ;; each instrument's own (performance (...)) must be a subset of this
  (performance (normal muted overtone1 pizzicato bowing))

;; Note that we are using the direct names of the list above
  (performance-table
    (normal normal muted overtone1 pizzicato bowing)
    (normal muted overtone1)
    (normal bowing))

  (instruments
    (instrument guitar
      (chordsize 1 6)
      (performance (normal muted overtone1))
      (dynamics    (p mf f))
      (compass (1 01) (5 12))
      (durations 0.1 4.0))

    (instrument piano
      (chordsize 1 10)
      (performance (normal pizzicato))
      (dynamics    (ppp pp p mf f ff fff))
      (compass (1 01) (5 12))
      (durations 0.1 4.0))

    (instrument basedrum
      (chordsize 1 1)
      (performance (normal bowing))
      (dynamics    (ppp pp p mf f ff fff))
      (compass (1 01) (1 01))
      (durations 0.1 4.0))

    (instrument marimba
      (chordsize 1 4)
      (performance (normal bowing))
      (dynamics    (mf f ff fff))
      (compass (1 01) (5 12))
      (durations 0.1 4.0)))

  (instrument-table
    (0 1 2 3)
    (0)
    (2 3))

  (entrydelays (0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8))


  (entrydelay-table
    (0 1 2)
    (3 4 5)
    (0 1 2 3 4 5 6 7))

  (durations (0.1 0.2 0.3 0.5 0.8))

  (duration-table
    (0 1 2)
    (3 4)
    (0 1 2 3 4))


  (dynamics-table
    (0 1 2 3 4 5 6)
    (2 3 4)
    (0 6))

  ;; selection principles reference:
  ;;   alea
  ;;   series
  ;;   (sequence (0 1 2 3))
  ;;   (ratio ((0 3) (1 2) (2 1)))          -- (index-or-value weight) pairs;
  ;;                                           the first slot is a LIST index
  ;;                                           (position in this parameter's own
  ;;                                           list, e.g. entrydelays/performance/
  ;;                                           dynamics/instruments below) - or,
  ;;                                           equivalently, the element's own
  ;;                                           value/name (e.g. 0.2 or normal).
  ;;                                           any list index not given a weight
  ;;                                           defaults to 0 (blocked).
  ;;   (group (element    alea)             -- element selector: alea | series
  ;;          (repetition series)           -- repetition count selector: alea | series
  ;;          (repetitions 2 5))            -- min and max repetitions
  ;;   (tendency (section portion (start min max) (end min max)) ...)

  ;;(tendency
      ;;         portion  start-min start-max  end-min end-max
      ;;(section   1.0      (start 0.5 0.5)      (end 0.0 1.0))
        ;;(section   1.0      (start 0.5 1.0)      (end 0.5 0.0)))


  (number-of-instrument-groups 1) ;; this is a main parameter to handle the number of groups selected.


  (principles
    (instrument (ensemble series) (sample series)) ;; two selection principles, one for the ensemble, one for the actual score constructions from the ensemble
    ;; entrydelay list is (0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8); ratio pairs may
    ;; give either the list index or the actual value (mixed here to
    ;; demonstrate both) - every index must get a nonzero weight in at
    ;; least one of each entrydelay-table row's elements, or that row could
    ;; never produce a value once selected
    (entrydelay
      (ensemble series)
      (sample
        ;; 0   1   2   3   4   5   6   7
        ;;(0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8)
        (ratio ((0 1) (1 3) (2 1) (3 5) (4 2) (5 1) (6 1) (7 1)))))
    ;; performance is per-tone here: within a multi-note chord, each tone
    ;; gets its own independently-drawn performance mode (MOD-PERF = 1)
    (performance
      (ensemble alea)
      (sample alea)
      (mode per-tone))
    ;; dynamics stays chord-wide: one dynamic shared by every tone in the
    ;; chord (MOD-DYN = 0)
    (dynamics (ensemble series) (sample series) (mode per-chord))
    (duration (ensemble series) (sample series)))

  (combination
    (entrydelay  none)
    (performance combination)
    (dynamics    none)
    (duration    none))

  ;; DUR-ENTRY = 2 (duration <= entry delay), MOD-DUR = per-tone: every tone
  ;; in a chord gets its own duration, each independently constrained to be
  ;; no longer than the entry's (already-resolved, see hierarchy below) entry
  ;; delay
  (duration-relation (shorter-than-entry per-tone))

;; none means a layer per instrument group!
  (union none)

;; you can either have autonomous density, using a principle, or density defined by the instrument chord size.
;; If instrument is the density generator, it also becomes primary parameter in the hierarchy
  (density (autonomous (low 1) (high 6) (principle series)))

;; Ins precedes Per (per-tone) and Dur (per-tone, shorter-than-entry) so
;; chord size is known before either resolves; Ent precedes Dur so DUR-ENTRY
;; has an entry delay to constrain duration against.
  (hierarchy (Ins Per Dyn Ent Dur))

)
