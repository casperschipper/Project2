# Ways in which PR2 is different

* Tendency masks in PR2 do not act on continuous ranges, they are moving boundaries over a list of predifined values. Therefor the name "mask".
* PR2 is very instrumental: it thinks of music as instruments playing notes. But otherwise it allows for a lot of flexibility:
  * Non-12 octave divisions
  * Non-standard performance techniques completely open to composer
  * Arbitrary durations and metres, things may not line up to any quantization unless you force it to.
* Serial thinking is very present, however it also has generators that are the exact opposite (forced repetition, or weighted choice generations, or even composed sequences). The one exception is harmony, that is "protected" from the composers "attacks".
* Hierarchy, note events are build parameter by parameter, a selected parameter can limit what values another parameter can take. Mostly, this is due to a certain value only playable by a certain instrument. This instrument will not be able to play all values in another parameter.
* It has some Combination and Union concepts which are unique to PR2 and allow the composer to have multiple groups of material.
  