This directory contains the output files of the `global_normalization` workflow, with `restore_brain` input images (DrawEM mask instead of BET)
and likely initially wrong BS+CB masks used (labels extracted from `_all_labels` segmentations instead of `_tissue_labels`).

Input files for `mirtk construct-atlas`:
```
mkdir -p global/dhcp-2019 && cd global/dhcp-2019
mkdir avg
cp /vol/dhcp-derived-data/volumetric-atlases/workspace/scripts/pairwise/out/global_normalization/atlas/average/t2w/linear.nii.gz avg/t2w.nii.gz
cp -r /vol/dhcp-derived-data/volumetric-atlases/workspace/scripts/pairwise/out/global_normalization/dofs/1.4_inv dof
for t in {28..44}; do
  cp /vol/dhcp-derived-data/volumetric-atlases/workspace/scripts/pairwise/out/adaptive-sigma-noavgdof/atlas/dofs/t*.dof dof/t$t.00.dof
done
```
