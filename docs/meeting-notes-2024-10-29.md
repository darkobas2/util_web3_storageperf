## Notes from meeting with Marko Zidaric, 2024-10-29

- What we are doing is all part of one big experiment, but it could make sense to break it up temporarily into smaller pieces (e.g., all Swarm runs in one part, and all other platforms in another). Should we keep the script in a form that allows a user to run everything all at once?

  Longer-term suggestion: maybe re-implement benchmarking using K6.io and Grafana? Those are better tools for continuous integration and testing than the Python script. For now: we should have one single Python script that performs all experiments. To run just part of the experiment (e.g., only Swarm without IPFS and Arweave), we should remove the factor levels IPFS and Arweave before running the script. This way they are easy to add back and recover the full experiment if needed.

- Results: currently we have just one result file that we keep appending. Should we instead create a dedicated `/data` folder with all results, including upload speeds for Swarm and download results from each run of the experiment? The files could then be properly labeled for traceability.

  We'll create a `/data` folder and have config files, results, and references in there, with descriptive names and time tags.

- Repo: old or new?

  We will keep to the tried and true repo.

- Swarm tests: should they be done with pinned content on one node?

  Marko disagrees. We are not just testing AWS speeds; retrieval is more complicated due to servers having to communicate with one another to first reach the file (on Pinata or elsewhere). Also, what we are testing right now corresponds to how most users actually use these services. So in conclusion, since we are working with small files anyway, let's not implement this right now.

- 100MB files: only for Swarm and nonzero erasure coding?

  Actually, let's use 100MB files for *all* platforms and factor combinations.

- Checkbook ON/OFF: how to deal with it?

  This isn't something easy to control with a script, because the individual nodes themselves may be paid for (or not). Right now the checkbooks have been funded by Marko. So checkbook is effectively ON. For now, let's just keep it that way. Maybe later we can change that.

- Related to the above: do we need different timeout options?

  Still waiting on input from others on this. Sent the question to Esad; let's see what he says. In any case, there is probably no point in applying erasure codes to files 10MB or smaller, in case the 30s timeout rule is true.

- Strategies: only NONE and RACE?

  Yes, only these two are needed.

- How many servers to use, and how?

  All downloads should be done on a single server. If multiple servers are used, then the whole experiment should be replicated on each, so that server identity becomes its own experimental factor. (Also, for IPFS only: uploads should be from a different server.) In fact, this is all already implemented.

- `size_kb`: is this field obsolete in the `results.json` data files?

  Marko will double-check this.

- `replicate`: let's strive for 30 replicates per factor combination, which allows for better statistics when alanyzing the data later on.

  In latest runs there were 15 replicates per factor combination, but this will be trivial to increase to 30.
