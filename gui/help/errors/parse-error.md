# The formula could not be read

Project Two could not make sense of the text of the [structure formula](concepts/structure-formula) at this point. The message quotes what it expected and what it found.

## Why this matters

The structure formula is the complete statement of a piece: its lists, its tables, its selection principles, its hierarchy. Before any of it can be checked for musical sense, it has to be readable as a structure. A parse error means the reading stopped, so nothing beyond this point has been examined yet, and fixing it will often reveal further diagnostics that were simply never reached.

The messages are mostly literal about what was expected. A field may be missing, a field may have the wrong number of values, a number may be where a name should be or vice versa, or a bracket may not close. When the message says a value is missing, the usual cause is a structural one: a closing parenthesis in the wrong place has swallowed a field into its neighbour, so the field is present in the text but not where the reader is looking.

## How to fix it

- Read the message's location path; it names the parameter and the field, so `duration.relation` points at the duration parameter's relation field, not at the durations themselves.
- Check the brackets around the region named. Most parse errors that look like missing fields are unbalanced parentheses one line earlier.
- Check the spelling of the value if a mode or principle name was expected. Names such as `per-note`, `equals-entry`, `alea` and `series` are matched exactly.
- Numbers accept decimals and fractions, so `0.25` and `1/4` are both fine, but a bare `.25` or a stray unit is not.
