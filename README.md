# QuartzImageIO

[![Build Status](https://travis-ci.org/JuliaIO/QuartzImageIO.jl.svg?branch=master)](https://travis-ci.org/JuliaIO/QuartzImageIO.jl)
[![codecov](https://codecov.io/gh/JuliaIO/QuartzImageIO.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/JuliaIO/QuartzImageIO.jl)

This package provides support for loading and saving images using
native libraries on macOS.  This package was split off from
[Images.jl](https://github.com/timholy/Images.jl) to make image I/O
more modular.

# Installation

Add the package with

```jl
Pkg.add("QuartzImageIO")
```

# Usage

QuartzImageIO will be used as needed if you've said

```
using FileIO
```

in your session or module. You should **not** generally say `using
QuartzImageIO`.  See [FileIO](https://github.com/JuliaIO/FileIO.jl) for
further details.

It's worth pointing out that packages such as Images load FileIO.

# Alternatives

If QuartzImageIO does not provide the functionality you need, an
alternative is
[ImageMagick](https://github.com/JuliaIO/ImageMagick.jl). You can have
both packages installed, and FileIO will manage their interaction.
