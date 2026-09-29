# Ways in which PR2 is different

* Tendency masks in PR2 do not act on continuous ranges, they are moving boundaries over a list of predifined values. Therefor the name "mask".
* PR2 is an instrumental program: it thinks of music as instruments playing notes. But otherwise it allows for a lot of flexibility:
  * Non standard (/= 12) octave divisions
  * Non-standard performance techniques open to composer
  * Arbitrary durations and metres, things may not line up to any quantization unless you force it to.
* Serial thinking is very present, however it also has generators that are the exact opposite (forced repetition, or weighted choice generations, or even composed sequences). The one exception is harmony, that is "protected" from the composers "attacks".
* The generators are more "diverse" than in PR1, which only had a spectrum from irregular to regular. There are different ways to achieve the spectrum of randomness to regular patterns. The Tendency mask is a thing on its own. 
* Hierarchy, note events are build parameter by parameter, a selected parameter can limit what values another parameter can take. Mostly, this is due to a certain value only playable by a certain instrument. This instrument will not be able to play all values in another parameter.
* It has some Combination and Union concepts which are unique to PR2 and allow the composer to have multiple groups of material.
  