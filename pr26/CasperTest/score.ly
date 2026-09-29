\version "2.24.0"
\header { title = "formula" tagline = ##f }
global = { \time 4/4 \tempo 4 = 60 }
\score {
<<
  \new StaffGroup \with { instrumentName = "Layer 0" } <<
    \new Staff \with { instrumentName = "guitar2" } <<
    { \global \clef bass }
    \new Voice { \voiceOne
      c,16\p r16 r8 r4 \tuplet 5/4 { r8. b,8\f } r4 |
      \tuplet 5/4 { r8 c,8\p r16 } \tuplet 5/4 { r8 gis,16\f r8 } r8 r16 \tweak NoteHead.style #'cross b'16\mf r4 |
      r16 e,16\f r8 b,8\p r8 \tuplet 5/4 { \tweak NoteHead.style #'cross b'16\mf r4 } r4 |
      r8 fis,16\f r16 \tuplet 5/4 { r8. dis,8 } r4 \tuplet 3/2 { r8 <cis, d,>16.\mf r32 \tweak NoteHead.style #'cross b'8\f } |
      r4 \tuplet 5/4 { r8. b,16\p r16 } r2 |
      r8 r16 gis,16 \tuplet 5/4 { r8. b,16\f~ b,64 r32. } r4 \tuplet 5/4 { r4 fis,16\mf~ } |
      \tuplet 5/4 { fis,64 r16.. r8. } r8 r16 \tweak NoteHead.style #'cross b'16\p r4 \tuplet 5/4 { c,8\mf r8. } |
      \tuplet 5/4 { r8 \tweak NoteHead.style #'cross b'16\f r8 } r4 r2 |
    }
    \new Voice { \voiceTwo
      s2 \tuplet 5/4 { s8. dis,16\f s16 } s4 |
      s1*1/1 |
      s4 ais,16\p s16 s8 s2 |
      s4 \tuplet 5/4 { s8. b,16\f s16 } s2 |
      s1*1/1 |
      s4 \tuplet 5/4 { s8. dis,16 s16 } s4 \tuplet 5/4 { s4 e,16\mf } |
      s2 s4 \tuplet 5/4 { d,16 s4 } |
      s1*1/1 |
    }
    >>
    \new Staff \with { instrumentName = "piano" } <<
    { \global \clef bass }
    \new Voice { \voiceOne
      r8 \tweak NoteHead.style #'cross b'16\f r16 r4 \tuplet 5/4 { \tweak NoteHead.style #'cross b'16\mf r4 } r8 a,8 |
      \tuplet 5/4 { r4 \tweak NoteHead.style #'cross b'16\f } r4 r16 g,16\p r8 r4 |
      r16 c,16\f r16 \tweak NoteHead.style #'cross b'16\mf r4 \tuplet 5/4 { r8 c,8\p r16 } r16 \tweak NoteHead.style #'cross b'16\f r8 |
      r2 \tuplet 5/4 { r8 g,16\p r8 } \tuplet 3/2 { \tweak NoteHead.style #'cross b'8 r4 } |
      \tuplet 3/2 { r4 \tweak NoteHead.style #'cross b'8 } r4 \tuplet 5/4 { r4 <a, c,>16\f } r16 \tweak NoteHead.style #'cross b'16\p r8 |
      r2 \tweak NoteHead.style #'cross b'8 r8 \tuplet 5/4 { \tweak NoteHead.style #'cross b'16~ \tweak NoteHead.style #'cross b'64 r16.. r8 } |
      r4 r16 dis,16\f r8 r8 \tweak NoteHead.style #'cross b'16\mf r16 \tuplet 5/4 { r8. \tweak NoteHead.style #'cross b'16\p r16 } |
      R1*1/1 |
    }
    \new Voice { \voiceTwo
      s2 s4 s8 c,16\mf s16 |
      s1*1/1 |
      s1*1/1 |
      s1*1/1 |
      s1*1/1 |
      s2 \tweak NoteHead.style #'cross b'16\p s16 s8 \tuplet 5/4 { \tweak NoteHead.style #'cross b'16 s4 } |
      s1*1/1 |
      s1*1/1 |
    }
    >>
    \new Staff \with { instrumentName = "guitar1" } <<
    { \global \clef bass }
    \new Voice { \voiceOne
      r4 \tuplet 3/2 { <c, e,>16.\mf r32 r4 } r4 r16 \tweak NoteHead.style #'cross b'16\p r8 |
      \tuplet 5/4 { \tweak NoteHead.style #'cross b'16\mf~ \tweak NoteHead.style #'cross b'64 r16.. r8 } \tuplet 5/4 { r4 \tweak NoteHead.style #'cross b'16 } r4 \tuplet 5/4 { r16 c,16\f r16 \tweak NoteHead.style #'cross b'16\p r16 } |
      r4 r8 \tweak NoteHead.style #'cross b'16\f r16 \tuplet 5/4 { r4 cis,16\p } r4 |
      e,8 r8 \tuplet 5/4 { \tweak NoteHead.style #'cross b'8\mf r8. } r4 \tuplet 3/2 { \tweak NoteHead.style #'cross b'16.\p r32 r4 } |
      \tuplet 3/2 { fis,8\mf r4 } r4 \tuplet 5/4 { r8 \tweak NoteHead.style #'cross b'8\f r16 } r8 r16 \tweak NoteHead.style #'cross b'16\mf |
      r4 \tuplet 5/4 { r16 \tweak NoteHead.style #'cross b'16 r8. } r4 \tuplet 5/4 { r8 \tweak NoteHead.style #'cross b'16\f r8 } |
      \tuplet 5/4 { r16 ais,16\p r8. } r4 a,16\f r16 r8 r4 |
      \tuplet 5/4 { ais,16~ ais,64 r16.. r8 } \tuplet 5/4 { r8 \tweak NoteHead.style #'cross b'16\mf r8 } r2 |
    }
    \new Voice { \voiceTwo
      s1*1/1 |
      \tuplet 5/4 { \tweak NoteHead.style #'cross b'16\mf s4 } s4 s2 |
      s1*1/1 |
      s4 \tuplet 5/4 { \tweak NoteHead.style #'cross b'16 s4 } s2 |
      s2 \tuplet 5/4 { s8 \tweak NoteHead.style #'cross b'16\f s8 } s4 |
      s1*1/1 |
      s1*1/1 |
      \tuplet 5/4 { gis,16 s4 } s4 s2 |
    }
    >>
    \new Staff \with { instrumentName = "basedrum" } {
      \global \clef bass
      r4 \tuplet 3/2 { r8 \tweak NoteHead.style #'cross b'8\p gis,8\f } r2 |
      \tuplet 5/4 { r4 \tweak NoteHead.style #'cross b'16 } \tuplet 5/4 { r8 ais,8 r16 } r16 f,16\p r8 r4 |
      r8 r16 \tweak NoteHead.style #'cross b'16\mf r8 \tweak NoteHead.style #'cross b'16\f r16 \tuplet 5/4 { \tweak NoteHead.style #'cross b'16\mf~ \tweak NoteHead.style #'cross b'64 r16.. r8 } r8 r16 \tweak NoteHead.style #'cross b'16 |
      r2 \tuplet 5/4 { \tweak NoteHead.style #'cross b'16 r4 } \tuplet 3/2 { r4 \tweak NoteHead.style #'cross b'8\f } |
      r4 \tuplet 5/4 { r16 \tweak NoteHead.style #'cross b'16 r8. } \tuplet 5/4 { dis,16\mf r4 } r4 |
      r16 fis,16\f r8 r4 r8 a,16\mf r16 r4 |
      \tuplet 5/4 { r16 gis,16\p r8 \tweak NoteHead.style #'cross b'16\mf~ } \tweak NoteHead.style #'cross b'128~ r32 r64 r16 r8 g,16\f r16 r8 \tuplet 5/4 { r8. \tweak NoteHead.style #'cross b'16\p~ \tweak NoteHead.style #'cross b'64 r32. } |
      \tuplet 5/4 { r4 dis,16~ } \tuplet 5/4 { dis,64 r16.. r8. } r2 |
    }
  >>
  \new StaffGroup \with { instrumentName = "Layer 1" } <<
    \new Staff \with { instrumentName = "guitar1" } <<
    { \global \clef bass }
    \new Voice { \voiceOne
      g,8\mf~ g,16 r16 \tuplet 5/4 { r16 cis,16\f~ cis,64 r32. d,,,8\ppp } \tuplet 5/4 { r8 e,,,8\pp r16 } \tuplet 5/4 { r8 ais,8.\fff~ } |
      \tuplet 5/4 { ais,16 b,,,16\ppp r8 dis,16\mf } r16 f,,,16\p~ f,,,16 g,,,16\f~ g,,,8 d,16\pp c,,,16\ff \tuplet 3/2 { e,,,8\mf r4 } |
      \tuplet 5/4 { <fis, gis,>16\f r8. ais,,,16\ppp } r8 b,8\pp \tuplet 7/4 { r8 dis,,,4.\ff g,,,4.\fff } |
      \tuplet 5/4 { cis,16\f~ cis,64 r16.. r8 } c,16\mf e,,,16\p~ e,,,8 fis,16\pp r16 gis,16\ff r16 \tuplet 3/2 { r8 ais,,,16.\fff r32 r8 } |
      \tuplet 7/4 { b,,,8\mf r4 f,4\ppp r4 } \tuplet 7/4 { c,,,8\fff r8 d,4.\ff gis,,,4\f } |
      \tuplet 3/2 { b,8\ppp r8 dis,8\p } r8 f,,,8\fff~ f,,,16 r16 r16 a,16\ff~ a,16 r16 cis,8\f~ |
      \tuplet 7/4 { cis,8 r8 b,4\ppp r8 dis,,,4\fff~ } \tuplet 5/4 { dis,,,16 g,4\ff } c,16\f r16 r16 cis,,,16\p~ |
      \tuplet 5/4 { cis,,,8 r16 c,8\ppp } fis,8\mf~ fis,16 r16 r2 |
    }
    \new Voice { \voiceTwo
      a,8\mf s8 s4 \tuplet 5/4 { s8 c,,,16\pp fis,8\ff~ } \tuplet 5/4 { fis,16 s4 } |
      s4 s8 s16 a,,,16\f c,4\fff s4 |
      s2 \tuplet 7/4 { s8 f,,,4\ff s8 a,,,8\fff s4 } |
      \tuplet 5/4 { c,16\f d,,,8\ppp s8 } s4 s2 |
      \tuplet 7/4 { s4. dis,8 g,4.\f } \tuplet 7/4 { a,,,16..\p s64 s8 cis,8\ff c,4\pp fis,,,16..\f s64 ais,,,8\mf } |
      s2 g,,,16\pp s16 s16 c,16\ff s8 d,16\f s16 |
      \tuplet 7/4 { e,,,8\mf s8 <ais, gis,,,>8\p s4 f,,,16..\fff s64 s8 } \tuplet 5/4 { s8. a,,,16\pp s16 } s8 s16 d,,,16\p |
      \tuplet 5/4 { s8. e,16\ppp s16 } gis,16\mf s16 <ais,,, b,,,>16\ff s16 s2 |
    }
    \new Voice { \voiceThree
      s16 c,,,16\p s8 s4 \tuplet 5/4 { s8. gis,16\ff s16 } s4 |
      s2 cis,8\fff s8 s4 |
      s1*1/1 |
      s1*1/1 |
      s2 \tuplet 7/4 { s4. e,8\pp s4. } |
      s1*1/1 |
      \tuplet 7/4 { c,,,16..\mf s64 s8 fis,,,16..\p s64 s2 } s2 |
      s1*1/1 |
    }
    >>
  >>
>>
  \layout { }
}
