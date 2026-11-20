# Python key-rate pipeline (Stage 2)

Put the pipeline scripts here.

Suggested contents:

```
python/pipeline/
  sns_pipeline.py     sync, basis separation, phase post-selection, decoy estimate, key rate R
  requirements.txt    e.g. numpy, pandas
```

Pipeline stages (report Figure 3.1): 5 CSV files, sync on window index, basis separation,
X post-selection (equal intensity, non-vacuum, equal phase slice), decoy-state estimate, Z gain and
QBER, key rate R (Wang, Yu and Hu, Phys. Rev. A 98, 062323). Every rate from a finite count carries a
95% Wilson interval. Stages 2 and 3 and all counters are what the FPGA core in `../../rtl/sifter.v` implements.

Reference results for the report's dataset (32,768 windows): Q_X 0.189, E_X 0.559, Q_Z 0.154,
QBER 0.581, s_1 0.508, e_1^ph 0.638, R = -0.166 per window.
