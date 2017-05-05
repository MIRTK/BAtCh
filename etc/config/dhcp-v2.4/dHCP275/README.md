# Notes from Antonios Makropolous (email 15 Mar 2017)

The used segmentations are in:
`/vol/dhcp-derived-data/structural-pipeline/dhcp-v2.4`

The atlas is based on 275 scans:
`/vol/dhcp-derived-data/structural-pipeline/BrainAtlas/subject_selection/subjs.csv`

These were selected from in total 504 scans using the following exclusion criteria:
- surface recon failed: 6
- dont have T1-weighted scan: 82
- with image quality score 1 or 2 (considerable motion): 29
- follow up scans (only first timepoint included): 22
- with excess CSF: 11
- time between birth and scan is more than 4 weeks, age at scan is less than 35 weeks: 53
- removed some extra scans from 41 weeks because there are too many at this time point
  (according to difference of the scan age to the age at birth): 26

I have tried 2 versions of kernels for the atlas construction:
- fixed (the σ remains the same, the number of subject varies)
- adaptive (the σ varies, the number of subject remains the same)

For the adaptive kernels I derive the target number of subjects as follows:
- I define a target kernel σ that I want to approximately have
- I measure the median number of subjects included per age at this given σ
- I then adjust the σ at each age in order to reach this target number of subjects

I tried fixed and adaptive kernels with different target σ (0.25, 0.5, 0.75, 1.0).
The final decision was to use the atlas constructed with adaptive kernels and target σ=0.5.

You can find the atlas in:
`/vol/dhcp-derived-data/structural-pipeline/BrainAtlas/v3_final_275/sigma0.5`

The templates are in the templates dir, the probability maps in pbmaps and the maximum probability templates in `hard_labels`.

The subject weights for the different ages are in:
`/vol/dhcp-derived-data/structural-pipeline/BrainAtlas/workflow_final_275/etc/kernel_sigma\=0.5`


# Notes from Andreas Schuh

Adaptive kernel weights created by Antonis, copied to `weights_adaptive_sigma=?.??/t??.tsv` files.

# Term subjects

The term subjects were selected using the following command:

```
for subid in $(../../../../bin/query-subjects sessions.csv --min-ga 37 --max-ga 42 --max-time-to-scan 0.15 | tail -n+2 | tr , -); do
  grep $subid subjects.lst > /dev/null && echo $subid
done > term-subjects.lst
```