# Debug Mode

We would like to be able to track the state of the "order" generators better, so that we get, in parallel to the normal output and the "entries" output, a machine readable output that includes the state of the selection principles. The aim is not for humans to read, but to later visualise or analyse why elements are "filtered" out, and see the hierarchy in action.

I imagine, that we would be able to for instance:
- Follow state of the selection principle, See when a SERIES is restarted.
- Visualise the GROUP state, when a new group is 
- Check that that a variant correctly continues a previous variant state of the generators.
- Show which elements are excluded, and the conditions which caused it. 
- Project the boundaries of a tendency mask over the ensemble
- Completed, or when the SERIES of the element or group size have completed. 

I want to balance easy processing with a reasonable verbosity. By definition it should be complete, but we want to avoid just repeating the same static information for each parameter. We can compute values that we need "in the moment".

I think as a first step, I would like to hear what is technically needed, and if any major restructering is required.