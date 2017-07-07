#!/usr/bin/env python

import os
import vtk
import argparse

from mirtk.rendering.screenshots import slice_view, take_screenshot, auto_level_window


def read_image(fname):
    """Read image from file."""
    reader = vtk.vtkNIFTIImageReader()
    reader.SetFileName(fname)
    reader.UpdateWholeExtent()
    output = vtk.vtkImageData()
    output.DeepCopy(reader.GetOutput())
    qform = vtk.vtkMatrix4x4()
    qform.DeepCopy(reader.GetQFormMatrix())
    return (output, qform)


def save_slice_view(path, image, index, zdir=2, size=512, **kwargs):
    """Save screenshot of images slice."""
    if isinstance(size, int):
        size = (size, size)
    renderer = slice_view(image, index, width=0, height=0, zdir=zdir, **kwargs)
    window = vtk.vtkRenderWindow()
    window.SetSize(size)
    window.AddRenderer(renderer)
    take_screenshot(window, path)


def get_center_index(image):
    dims = image.GetDimensions()
    return (dims[0]/2, dims[1]/2, dims[2]/2)


def get_zdir_suffix(zdir):
    if zdir == 0:
        return "sagittal"
    if zdir == 1:
        return "coronal"
    if zdir == 2:
        return "axial"


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('image')
    parser.add_argument('output')
    parser.add_argument('postfix', nargs='?', default='')
    parser.add_argument('-i', '--index', type=int, action='append')
    parser.add_argument('-u', '--up', dest='zdir', type=int, action='append', choices=(0, 1, 2))
    parser.add_argument('-s', '--size', default=512, type=int)
    parser.add_argument('-l', '--level', type=float)
    parser.add_argument('-w', '--window', type=float)
    args = parser.parse_args()
    image, qform = read_image(args.image)
    image2world = vtk.vtkMatrixToLinearTransform()
    image2world.SetInput(qform)
    image2world.Update()
    world2image = image2world.GetLinearInverse()
    center = get_center_index(image)
    if not args.zdir:
        args.zdir = [2]
    if not args.index:
        args.index = [center[args.zdir[0]]]
    prefix, ext = os.path.splitext(args.output)
    postfix = args.postfix
    if not ext:
        postfix, ext = os.path.splitext(args.postfix)
        if not ext:
            ext = ".png"
    if postfix:
        postfix = "-" + postfix
    for n in range(len(args.index)):
        i = args.index[n]
        zdir = args.zdir[n] if len(args.zdir) > n else args.zdir[-1]
        index = list(center)
        if zdir == 2:
            index[zdir] = image.GetDimensions()[zdir] - i - 1
        else:
            index[zdir] = i
        if args.level and args.window:
            level_window = (args.level, args.window)
        else:
            level_window = list(auto_level_window(image))
            if args.level is not None:
                level_window[0] = args.level
            if args.window is not None:
                level_window[1] = args.window
        if len(args.index) > 1:
            path = "{prefix}{suffix}-{i:03d}{postfix}{ext}".format(prefix=prefix, suffix=get_zdir_suffix(zdir), postfix=postfix, i=i, ext=ext)
        else:
            path = args.output
        if n == 0:
            outdir = os.path.dirname(path)
            if outdir and outdir != '.' and not os.path.isdir(outdir):
                os.makedirs(outdir)
        save_slice_view(path, image, index=index, zdir=zdir, size=args.size, level_window=level_window, transform=world2image)
