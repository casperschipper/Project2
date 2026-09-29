# Observations while working on PR2, what makes PR2 different?

* Tendency masks in PR2 do not act on continuous ranges, they are moving boundaries over a list of predifined values. Therefor the name "mask"

* Although the order of values is highly automated in PR2, the actual values of parameters is fully controlled by the composer and never changed in the process.

* PR2 is an instrumental program: it thinks of music as instruments playing notes. But otherwise it allows for a lot of flexibility:
  * Non standard (/= 12) octave divisions
  * Any performance techniques defined to the composer
  * Arbitrary durations and metres, things may not line up to any quantization unless you force it to. (This also makes generating readable scores difficult).

* RATIO is not a weighted choice, but may better be understood as a series with repetitions already in the series. Also: the weights of RATIO always refer to the full list not the ensemble.

* Serial thinking is very present, however it also has generators that are the exact opposite (forced repetition, series with repeated elements, or even hand-composed sequences). The one exception is harmony, that is "protected" from the composers "attacks"

* Hierarchy, note events are build parameter by parameter, a selected parameter can limit what values another parameter can take. Mostly, this is due to a certain value only playable by a certain instrument. This instrument will not be able to play all values in another parameter.

* It has some Combination and Union concepts which are unique to PR2 and allow the composer to have multiple groups of material.
It allows a composer to construct vertical relationships. For example a group of durations and dynamics that may only occur together in one voice and not in the others.
  