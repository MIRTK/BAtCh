#!/usr/bin/env python

import os
import vtk
import argparse

from mirtk.rendering.screenshots import slice_axes, slice_view, take_screenshot, auto_level_window


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


def inverse_color_map():
    lut = vtk.vtkColorTransferFunction()
    lut.AddRGBPoint(0., 1., 1., 1.)
    lut.AddRGBPoint(1., 0., 0., 0.)
    lut.ClampingOn()
    lut.SetRange(0, 1)
    lut.Build()
    return lut


def linear_color_map(min_color, max_color):
    lut = vtk.vtkColorTransferFunction()
    lut.AddRGBPoint(0., min_color[0], min_color[1], min_color[2])
    lut.AddRGBPoint(1., max_color[0], max_color[1], max_color[2])
    lut.ClampingOn()
    lut.SetRange(0, 1)
    lut.Build()
    return lut


def hot_color_map():
    lut = vtk.vtkColorTransferFunction()
    lut.AddRGBPoint(0., 0., 0., 0.)
    lut.AddRGBPoint(.3, 0., 0., 0.)
    lut.AddRGBPoint(.35, .847, 0., 0.)
    lut.AddRGBPoint(.44, 1., .227, 0.)
    lut.AddRGBPoint(.76, 1., 1., 0.)
    lut.AddRGBPoint(1., 1., 1., 1.)
    lut.ClampingOff()
    lut.SetBelowRangeColor(1., 1., 1.)
    lut.UseBelowRangeColorOn()
    lut.SetAboveRangeColor(1., 1., 1.)
    lut.UseAboveRangeColorOn()
    lut.SetRange(0, 1)
    lut.Build()
    return lut


def jet_color_map():
    lut = vtk.vtkColorTransferFunction()
    lut.AddRGBPoint(0., 0., 0., .5)
    lut.AddRGBPoint(.1, 0., 0., 1.)
    lut.AddRGBPoint(.4, 0., 1., 1.)
    lut.AddRGBPoint(.6, 1., 1., 0.)
    lut.AddRGBPoint(.9, 1., 0., 0.)
    lut.AddRGBPoint(1., .5, 0., 0.)
    lut.ClampingOff()
    lut.SetBelowRangeColor(1., 1., 1.)
    lut.UseBelowRangeColorOn()
    lut.SetAboveRangeColor(1., 1., 1.)
    lut.UseAboveRangeColorOn()
    lut.SetRange(0, 1)
    lut.Build()
    return lut


def jet_with_white_background_color_map():
    lut = vtk.vtkColorTransferFunction()
    lut.AddRGBPoint(0., 1., 1., 1.)
    #lut.AddRGBPoint(.1, 0., 0., .1)
    lut.AddRGBPoint(.4, 0., 1., 1.)
    lut.AddRGBPoint(.6, 1., 1., 0.)
    lut.AddRGBPoint(.9, 1., 0., 0.)
    lut.AddRGBPoint(1., .5, 0., 0.)
    lut.ClampingOn()
    lut.SetRange(0, 1)
    lut.Build()
    return lut


def color_map(control_points, colors_lut=None):
    """Map image intensities to [0, 1] using vtkKochanekSpline as done by ITK-SNAP."""
    spline = vtk.vtkKochanekSpline()
    spline.SetLeftConstraint(2)
    spline.SetRightConstraint(2)
    spline.SetDefaultContinuity(-1)
    spline.SetDefaultTension(0)
    spline.SetDefaultBias(0)
    min_value = 1000.
    max_value = -1000.
    for control_point in control_points:
        spline.AddPoint(control_point[0], control_point[1])
        if control_point[0] < min_value:
            min_value = control_point[0]
        if control_point[0] > max_value:
            max_value = control_point[0]
    spline.Compute()
    n = 2048
    lut = vtk.vtkLookupTable()
    lut.SetRampToLinear()
    lut.SetNumberOfTableValues(n)
    lut.SetRange(min_value, max_value)
    t = 0.
    dt = (max_value - min_value) / float(n - 1)
    for i in range(n):
        s = spline.Evaluate(t)
        if colors_lut:
            r, g, b = colors_lut.GetColor(s)
            lut.SetTableValue(i, r, g, b)
        else:
            lut.SetTableValue(i, s, s, s)
        t += dt
    return lut


def save_slice_view(path, image, index, zdir=2, size=0, **kwargs):
    """Save screenshot of images slice."""
    if isinstance(size, int):
        size = (size, size)
    if size[0] <= 0 or size[1] <= 0:
        size = list(size)
        xdir, ydir = slice_axes(zdir)
        if size[0] <= 0:
            size[0] = image.GetDimensions()[xdir]
        if size[1] <= 0:
            size[1] = image.GetDimensions()[ydir]
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
    parser.add_argument('-s', '--size', default=0, type=int)
    parser.add_argument('-l', '--level', type=float)
    parser.add_argument('-w', '--window', type=float)
    parser.add_argument('--interp', default="nearest")
    parser.add_argument('--map', type=float, default=[], nargs=2, action='append')
    parser.add_argument('--colors', default="grey")
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
    if args.colors == "grey":
        lut = None
    elif args.colors == "jet":
        lut = jet_color_map()
    elif args.colors == "jet+white":
        lut = jet_with_white_background_color_map()
    elif args.colors == "hot":
        lut = hot_color_map()
    elif args.colors == "inverse":
        lut = inverse_color_map()
    else:
        values = [float(x) for x in args.colors.split(" ")]
        lut = linear_color_map((values[0:3]), (values[3:6]))
    if args.map:
        lut = color_map(args.map, lut)
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
        save_slice_view(path, image,
                        transform=world2image,
                        index=index,
                        zdir=zdir,
                        size=args.size,
                        level_window=level_window,
                        interpolation=args.interp,
                        image_lut=lut)
