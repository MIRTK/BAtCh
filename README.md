# Groupwise spatio-temporal atlas construction

This branch contains auxiliary scripts and configuration files for the new "groupwise" spatio-temporal atlas
construction described in [Schuh et al. (2018)](https://doi.org/10.1101/251512) and
[Schuh (2017)](https://doi.org/10.25560/58880).

The commands to construct and evaluate an atlas with these configuration files is included in MIRTK.

To construct an atlas:
```
mirtk construct-atlas config.json
```

To evaluate the quality measures:
```
mirtk evaluate-atlas config.json
```


## Unbiased global normalization

The affine transformations for global alignment of brain scans prior to the non-rigid atlas construction
can be computed using the "pairwise" approach that is implemented by the HTCondor workflow of the original
"pairwise" method described in [Schuh et al. (2014)](http://andreasschuh.com/wp-content/uploads/2015/09/miccai2014-stia.pdf)
and [Schuh (2017)](https://doi.org/10.25560/58880).

The Bash scripts can be found in Git tag [dhcp-v2.0](https://github.com/MIRTK/BAtCh/releases/tag/dhcp-v2.0).
