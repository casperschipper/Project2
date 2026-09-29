# Observations while working on PR2, what makes PR2 different?

* Although the order of values is highly automated in PR2, the actual values of parameters are provided by the composer as a list and never modified, only "organized".

* Tendency masks in PR2 do not act on continuous ranges, they are moving boundaries over the list. Therefore the name "mask"

* PR2 is an instrumental program: it thinks of music as instruments playing notes. 
  
* But otherwise it allows for a lot of flexibility:
  * Non standard (/= 12) octave divisions
  * Any performance techniques defined to the composer
  * Percussion (specifically as non-pitched) instruments
  * Arbitrary durations and metres, things may not line up to any quantization unless you force it to. (This also makes generating readable scores difficult).

* RATIO is not a weighted choice, but may better be understood as a series with repetitions int its seed-row. Also: the weights of RATIO always refer to the full list not the ensemble.

* Serial thinking is very present, however Pr2 also has generators that are the exact opposite (forced repetition, series with repeated elements, or even hand-composed sequences). 

* Hierarchy, note events are build parameter by parameter, a selected parameter can limit what values another parameter can take. Mostly, this is due to a certain value only playable by a certain instrument. This instrument will not be able to play all values in another parameter.

* It has some Combination and Union concepts which are unique to PR2 and allow the composer to have multiple groups of material.
It allows a composer to construct vertical relationships. For example a group of durations and dynamics that may only occur together in one voice and not in the others.
  