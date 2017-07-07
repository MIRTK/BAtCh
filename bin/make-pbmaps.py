#!/usr/bin/python

import os
import sys
import json
import argparse

from mirtk.atlas.spatiotemporal import SpatioTemporalAtlas


if __name__ == "__main__":
    # parse command arguments
    parser = argparse.ArgumentParser()
    parser.add_argument("config", help="JSON file with atlas configuration.")
    parser.add_argument("-w", "--workdir", "--tmpdir", dest="tmpdir",
                        help="Working directory for intermediate files.")
    parser.add_argument("-a", "--age", "--ages", dest="ages", type=float, nargs="+",
                        help="Atlas construction steps.")
    parser.add_argument("-c", "--channel", "--channels", dest="channels", type=str, nargs="+",
                        help="Name(s) of segmentation images.")
    parser.add_argument("-i", "--step", "--steps", dest="steps", type=int, nargs="+",
                        help="Atlas construction steps.", required=True)
    parser.add_argument("-q", "--queue", "--long-queue", dest="longqueue",
                        help="Name of batch system queue. Use 'condor' for HTCondor. Otherwise, the argument is assumed to be the name of a SLURM partition.")
    parser.add_argument("--short-queue", dest="shortqueue",
                        help="Name of batch system queue to use for short running jobs (about 1-30 min). Use --long-queue by default.")
    parser.add_argument("-t", "--threads", type=int,
                        help="Maximum number of CPU cores/threads to use.")
    parser.add_argument("-v", "--verbose", default=1, type=int,
                        help="Verbosity level of output messages: 0) no output, 1) report progress, 2) print command arguments.")
    args = parser.parse_args()
    # read configuration file
    args.config = os.path.abspath(args.config)
    root = os.path.dirname(args.config)
    with open(args.config, "rt") as f:
        config = json.load(f)
    # override paths
    if "paths" not in config:
        config["paths"] = {"topdir": os.getcwd()}
    if args.tmpdir:
        config["paths"]["tmpdir"] = os.path.abspath(args.tmpdir)
    # override environment
    if "environment" not in config:
        config["environment"] = {}
    if "queue" not in config["environment"]:
        config["environment"]["queue"] = {"short": "local", "long": "local"}
    if args.threads:
        config["environment"]["threads"] = args.threads
    if not args.shortqueue and args.longqueue:
        args.shortqueue = args.longqueue
    if args.shortqueue:
        config["environment"]["queue"]["short"] = args.shortqueue
    if args.longqueue:
        config["environment"]["queue"]["long"] = args.longqueue
    # instantiate atlas
    atlas = SpatioTemporalAtlas(config=config, root=root, verbose=args.verbose, exit_on_error=True)
    # generate probability maps
    if not args.ages:
        args.ages = atlas.means
    if not args.channels:
        args.channels = ["tissues", "structures"]
    for channel in args.channels:
        for step in args.steps:
            job, imgs = atlas.defimgs(channels=channel, ages=args.ages, step=step)
            atlas.wait(job, interval=30, verbose=1)
            job, avgs = atlas.avgimgs(channels=channel, labels="all", ages=args.ages, step=step)
            atlas.wait(job, interval=60, verbose=2)
