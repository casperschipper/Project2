# Debug Mode

We would like to be able to track the functioning of the program better, so that we get, in parallel to the normal output and the "entries" output, a machine readable "debug" output. This could be used to verify the program is working as expected, and visualise the state to the composer. The aim is not for humans to read this output directly, it would form the input of a visualisation program.

I want to balance easy processing with a reasonable verbosity. By definition it should give a complete context for why a value was picked, but we want to avoid just repeating the same static information for each parameter. We can compute other values that we need later "in the moment".

I see the following things are important:
- The normal output should have a unique identifier for each note. I suggest we identify by variant, layer, entry & note. Note that I merge the concept of chord due to the harmony chord principle or a multiple events at the same timepoint due to vertical density. 
- Follow state of the selection principle, See when a SERIES is restarted, when RATIO refreshes.
- Visualise the GROUP state, when a new repetition group is started.
- Between multiple variants/layers, check that a variant correctly continues a previous variant state of the generators.
- State which restrictions apply to the selection of a value. For this we might want to have an efficient way of doing that (we don't have to show which elements were excluded). I imagine we can just point "restricted by instrument x", restricted by "duration". 
- If a tendency mask is used, I want to know the current boundaries.

I think as a first step, I would like to hear what is technically needed, and if any major restructering is required.
I would like a clean implementation, that keeps the functions as readable as possible, while not affecting performance too much. 