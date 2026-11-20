# Data

Put the OptiSystem CSV outputs used for the report here (they are the input of the Python pipeline).
Files named in the report: `alice_signal_record.csv`, `bob_signal_record.csv`,
`charlie_record_z.csv`, `charlie_record_x.csv`, plus the remaining file of the five-file set.

One row per window, common window index. Large files: consider Git LFS or a release asset.
Generated files `python/stim.txt` and `python/golden.json` are not stored (see `.gitignore`);
`make golden` recreates them.
