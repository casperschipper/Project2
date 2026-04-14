# Union and Combination
 
Union and combination control the coordination between the selection of
instrument groups and the selection of groups for all other parameters. They
operate at the level of table groups — the stockpiles from which the selection
principles draw when assembling the final parameter values for the score.
Through union and combination, the composer controls how these stockpiles
(ensembles) are formed from table groups.
 
The number of INSTRUMENT groups entering the
ensemble is always determined by #13 (Number of Instrument Groups). The
question is always whether the other parameters follow that multiplicity
(combination) and whether the resulting multiplicity produces one or several
layers (union).
 
**Combination** means that the group indices selected for the non-instrument
parameters follow those selected for the INSTRUMENT parameter. Tables of
combined parameters must contain the same number of groups as the INSTRUMENT
table. The group selection principles declared for the non-instrument
parameters are overridden; only their score-level selection principles (for
ordering values within the ensemble) remain active.
 
**Union** determines whether the groups in the ensemble are treated as a single
pool (one layer) or kept separate (one layer per group).
 
## The four cases
 
**(a) Combination, union.** One layer is produced. The ensemble for each
combined parameter is built by merging several groups whose indices match
those selected for INSTRUMENT. Since union is active, these merged groups form
a single pool. Non-combined parameters have one group per variant. A possible
compositional motivation: the full set of available instruments is treated as
one ensemble while maintaining some statistical correlation between
instrumental groups and corresponding parameter values (e.g., certain pitch or
duration values are more likely to co-occur with certain instruments because
they share group indices, even though the groups are merged into a single
pool).
 
**(b) Combination, no union.** One layer per selected INSTRUMENT group. The
group indices for all combined parameters are determined by the INSTRUMENT
parameter. Non-combined parameters receive one group per variant. This is the
most strongly differentiated case: each layer has its own instrumental group
with correspondingly matched parameter groups. A typical compositional
motivation: assigning distinct pitch sets, duration ranges, or dynamic
vocabularies to distinct instrumental groups, so that each layer has a
characteristic musical profile.
 
**(c) No combination, union.** One layer is produced. The INSTRUMENT ensemble
is formed by merging however many groups #13 selects, but since there is no
combination, all other parameters contribute only one group to their
respective ensembles. A possible motivation: the composer wants the full
instrumental palette available as one pool but does not need parameter
differentiation tied to instrumental groups — for instance, a uniform rhythmic
or dynamic vocabulary applied across all instruments. Changes to parameter
vocabularies can only occur per variant, not within a variant.
 
**(d) No combination, no union.** One layer per selected INSTRUMENT group.
Since there is no combination, the non-instrument parameters are each assigned
one group per layer. Each layer has its own group for each of the parameters. 
