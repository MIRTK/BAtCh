- Adjust scale of atlas images by performing a kernel regression of the
  affine reference-to-subject transformation computed during the global
  normalization of the input images.
- Compute spatio-temporal deformation field (growth model) from pairwise
  transformations by considering that each image may contribute to more
  than one atlas time point.
