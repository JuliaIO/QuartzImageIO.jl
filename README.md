# QuartzImageIO

[![CI][action-img]][action-url]
[![Code coverage][codecov-img]][codecov-url]

This package provides support for loading and saving images using
native libraries on macOS.  This package was split off from
[Images.jl](https://github.com/JuliaImages/Images.jl) to make image I/O
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
[ImageMagick](https://github.com/JuliaIO/ImageMagick.jl) and [ImageIO](https://github.com/JuliaIO/ImageIO.jl). You can have
both packages installed, and FileIO will manage their interaction.

[action-img]: https://github.com/JuliaIO/QuartzImageIO.jl/actions/workflows/CI.yml/badge.svg
[action-url]: https://github.com/JuliaIO/QuartzImageIO.jl/actions/workflows/CI.yml
[codecov-img]: https://codecov.io/gh/JuliaIO/QuartzImageIO.jl/branch/master/graph/badge.svg
[codecov-url]: https://codecov.io/gh/JuliaIO/QuartzImageIO.jl
