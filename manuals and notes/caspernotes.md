# Combination and Union

Combination means that the group selection of one parameter, is duplicated for other parameters.
So if for example Instrument is Combined with entry delay, it means that in forming the ensemble, the 
It requires all parameters to have the same number of groups and ideally, for the values within the groups to be "compatible".

- How does this interact with "normal" hierarchy?
- Why do we need "combination", if we already have hierarchy?
- When should we want to use one or the other method?
- Should the system check if groups are compatible?
- Is the table based interface still the best choice for this?

Polyphony can only be achieved with "combination", it seems that "union" is always a single layer.
The idea is that "combination" is a way of guaranteeing vertical coherence? But, strangely enough, the pitch parameter doesn't have an ensemble or group?

Important historical change:
in the original version of PR2, only instrument parameter allowed selection of several groups into one ensemble.
But latter, one could also make sure that based on the instrument selected, it would also use the appropriate groups from other parameters. 

# Timing:

ENTRY POINTS
The duration of a variant is divided up into entry points, which are produced by the continuous addition of the entry delays.

Each entry
point is characterized by the entry of a tone or chord; to keep things simple we refer to the entry of a chord, indicating at the same time the number of tones in the chord (which may be a minimum of 1 or a maximum of tr). Percussive sounds of indeterminate pitch also count as chord tones • Every entry point is given one or more durations: one duration if it is a single tone or a chord with equal durations, several durations if it is a chord with independent durations. A durations can be said to be selected either per tone or per entry point. The end point of a tone results accordingly from the sum of entry point and duration.
Rests ("pseudo rests") occur automatically when the duration is shorter than the entry delay; duration and entry delay of a tone or chord are calculated starting from the same time point. If a previous tone is still sustained the "pseudo rest" is "concealed". Additional
"autonomous" rests due to the REST parameter modify the sequence of entry points (durations are unaffected). All entry points following the entry point of a autonomous rest are increased by the duration of the rest.
Owing to the fact that the durations in a chord can be independent of another, the chord with more than one tone can be defined in two
ways:
(a)
(b)
chord tones begin and end simultaneously, chord tones begin simultaneously and end one after the other.

It is not possible to have chord tones starting one after the other.

The ideas have not changed, only the technical possibilities of presenting them. The composer should be able to tell the program his wishes, limited of course to those which the program could fulfil. To save the composer from having to leaf through the manual, and once the punched tape had been replaced by a text monitor, the range of executable actions was shown on the screen in the form of menus in which one could scroll through and finally answer questions, i.e. type in the data. The graphical interface allows the user to work in a different way, more conveniently, versatilely and faster than calling up menus on a text-oriented monitor. The memory of PR3, where the number of parameters used should be optional, gave me the idea to allow the PR2 user to be free in the number of parameters, so that – maybe just for experimenting or studying the program – he no longer needs to define all parameters. Typing as such is not important. In all cases where the user has to decide among a fixed number of alternatives, he only needs to click on a check button or radio button anyway. Data, on the other hand, which are unpredictable in type and number, can best be entered by typing text. For fast and comfortable data entry, it is best to keep both hands in the same position on the keyboard. I see the monitor screen as a kind of notepad on which the user takes notes, deletes them, changes them, because this is the place where the composition takes place.


DB:
he given definitions take place over a number of distinct and clear steps. The first and most complicated step is the validation of the input data. This process needs to ensure that everything entered can produce a valid output and has no conflicting information, before any calculation or processing takes place.

Verifying that this is done in the right way has been complicated for various reasons, not in the least because of Koenig’s decision to keep every input data-type as text. This is one of such idiosyncratic features that I mentioned before.

To understand why that complicates things quite a bit let us imagine we are trying to check if a certain number is in the valid range for a given input. Say that the acceptable range for that input are numbers from 1 to 5. The user enters ‘3’. In order to perform this check, that input must first be converted to a numeric value, since its inputted as a string data-type. However, that input has an extra space after the three, inputted perhaps by accident, so the program also has to strip down invalid characters before it can convert it to a number, and check if the entered value is valid.

As we can see, such a simple check involved some labour already. This increases drastically if the task becomes more complicated, or if the input possibilities are larger. If the input would be numeric already to start with, as it is the case with every modern set of user-interface tools, we could have saved us quite some work. However, the specification for Project 2 says that every input must be a string. That decision was kept because of how Koenig wishes to interact with the program.

So, in order to achieve full verification of core principles we needed to be quite thorough with every single input, since I could not rely on pre-made number boxes or matrices to make all the checking for us. It became quite important to have a rather robust error-checking mechanism. Koenig provided a set of checklists for that purpose, which I tested against test inputs for every object and used in detail to write all the data validation algorithms. A great amount of time has been devoted to this particular aspect, and we are still working on some details.

When a parameter is lower in the hierarchy is it always using SERIAL?