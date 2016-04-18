using FactCheck, FileIO, QuartzImageIO, Images, Colors, FixedPointNumbers, TestImages

# Saving notes:
# autumn_leaves and toucan fail as of November 2015. The "edges" of the
# leaves are visibly different after a save+load cycle. Not sure if the
# reader or the writer is to blame. Probably an alpha channel issue.
# Mri-stack and multichannel timeseries OME are both image stacks,
# but the save code only saves the first frame at the moment.

facts("FileIO default") do
    imagedir = Pkg.dir("QuartzImageIO", "test", "images")
    images = readdir(imagedir)
    for image in images
    	context(image) do
	    	img = load(joinpath(imagedir, image))
	    	@fact isa(img, Image) --> true
    	end
    end
end

facts("OS X reader") do
    context("Autumn leaves") do
        name = "autumn_leaves"
        img = testimage(name)
        @fact colorspace(img) --> "RGBA"
        @fact ndims(img) --> 2
        @fact colordim(img) --> 0
        @fact eltype(img) --> RGBA{UFixed16}
        out_name = joinpath(tempdir(), name * ".png")
        # Calling `save` relies on FileIO dispatching to us, so we
        # make the call explicit.
        QuartzImageIO.save_(out_name, img, "public.png")
        # Ideally, the `convert` would not be necessary, but the
        # saving step goes through a conversion, so we need to do it
        # in this test
        @pending load(out_name) --> convert(Image{RGBA{UFixed8}}, img)
    end
    context("Camerman") do
        name = "cameraman"
        img = testimage(name)
        @fact colorspace(img) --> "Gray"
        @fact ndims(img) --> 2
        @fact colordim(img) --> 0
        @fact eltype(img) --> Gray{UFixed8}
        out_name = joinpath(tempdir(), name * ".png")
        QuartzImageIO.save_(out_name, img, "public.png")
        @fact load(out_name) --> convert(Image{RGBA{UFixed8}}, img)
    end
    context("Earth Apollo") do
        name = "earth_apollo17"
        img = testimage(name)
        @fact colorspace(img) --> "RGB4"
        @fact ndims(img) --> 2
        @fact colordim(img) --> 0
        @fact eltype(img) --> RGB4{UFixed8}
        out_name = joinpath(tempdir(), name * ".png")
        QuartzImageIO.save_(out_name, img, "public.png")
        @fact load(out_name) --> convert(Image{RGBA{UFixed8}}, img)
    end
    context("Fabio") do
        name = "fabio"
        img = testimage(name)
        @fact colorspace(img) --> "Gray"
        @fact ndims(img) --> 2
        @fact colordim(img) --> 0
        @fact eltype(img) --> Gray{UFixed8}
        out_name = joinpath(tempdir(), name * ".png")
        QuartzImageIO.save_(out_name, img, "public.png")
        @fact load(out_name) --> convert(Image{RGBA{UFixed8}}, img)
    end
    context("House") do
        name = "house"
        img = testimage(name)
        @fact colorspace(img) --> "GrayA"
        @fact ndims(img) --> 2
        @fact colordim(img) --> 0
        @fact eltype(img) --> GrayA{UFixed8}
        out_name = joinpath(tempdir(), name * ".png")
        QuartzImageIO.save_(out_name, img, "public.png")
        @fact load(out_name) --> convert(Image{RGBA{UFixed8}}, img)
    end
    context("Jetplane") do
        name = "jetplane"
        img = testimage(name)
        @fact colorspace(img) --> "GrayA"
        @fact ndims(img) --> 2
        @fact colordim(img) --> 0
        @fact eltype(img) --> GrayA{UFixed8}
        out_name = joinpath(tempdir(), name * ".png")
        QuartzImageIO.save_(out_name, img, "public.png")
        @fact load(out_name) --> convert(Image{RGBA{UFixed8}}, img)
    end
    context("Lighthouse") do
        name = "lighthouse"
        img = testimage(name)
        @fact colorspace(img) --> "RGB4"
        @fact ndims(img) --> 2
        @fact colordim(img) --> 0
        @fact eltype(img) --> RGB4{UFixed8}
        out_name = joinpath(tempdir(), name * ".png")
        QuartzImageIO.save_(out_name, img, "public.png")
        @fact load(out_name) --> convert(Image{RGBA{UFixed8}}, img)
    end
    context("Mandrill") do
        name = "mandrill"
        img = testimage(name)
        @fact colorspace(img) --> "RGB"
        @fact ndims(img) --> 2
        @fact colordim(img) --> 0
        @fact eltype(img) --> RGB{UFixed8}
        out_name = joinpath(tempdir(), name * ".png")
        QuartzImageIO.save_(out_name, img, "public.png")
        @fact load(out_name) --> convert(Image{RGBA{UFixed8}}, img)
    end
    context("Moonsurface") do
        name = "moonsurface"
        img = testimage(name)
        @fact colorspace(img) --> "Gray"
        @fact ndims(img) --> 2
        @fact colordim(img) --> 0
        @fact eltype(img) --> Gray{UFixed8}
        out_name = joinpath(tempdir(), name * ".png")
        QuartzImageIO.save_(out_name, img, "public.png")
        @fact load(out_name) --> convert(Image{RGBA{UFixed8}}, img)
    end
    context("Mountainstream") do
        name = "mountainstream"
        img = testimage(name)
        @fact colorspace(img) --> "RGB4"
        @fact ndims(img) --> 2
        @fact colordim(img) --> 0
        @fact eltype(img) --> RGB4{UFixed8}
        out_name = joinpath(tempdir(), name * ".png")
        QuartzImageIO.save_(out_name, img, "public.png")
        @fact load(out_name) --> convert(Image{RGBA{UFixed8}}, img)
    end
    context("MRI Stack") do
        name = "mri-stack"
        img = testimage(name)
        @fact colorspace(img) --> "Gray"
        @fact ndims(img) --> 3
        @fact colordim(img) --> 0
        @fact eltype(img) --> Gray{UFixed8}
        out_name = joinpath(tempdir(), name * ".png")
        QuartzImageIO.save_(out_name, img, "public.png")
        # Stack saving isn't implemented yet
        @pending load(out_name) --> convert(Image{RGBA{UFixed8}}, img)
    end
    context("M51") do
        name = "m51"
        img = testimage(name)
        @fact colorspace(img) --> "Gray"
        @fact ndims(img) --> 2
        @fact colordim(img) --> 0
        @fact eltype(img) --> Gray{UFixed16}
        out_name = joinpath(tempdir(), name * ".png")
        QuartzImageIO.save_(out_name, img, "public.png")
        @fact load(out_name) --> convert(Image{RGBA{UFixed8}}, img)
    end
    context("HeLa cells") do
        name = "hela-cells"
        img = testimage(name)
        @fact colorspace(img) --> "RGB"
        @fact ndims(img) --> 2
        @fact colordim(img) --> 0
        @fact eltype(img) --> RGB{UFixed16}
        out_name = joinpath(tempdir(), name * ".png")
        QuartzImageIO.save_(out_name, img, "public.png")
        @fact load(out_name) --> convert(Image{RGBA{UFixed8}}, img)
    end
    context("Blobs GIF") do
        name = "blobs"
        img = testimage(name)
        @fact colorspace(img) --> "RGB4"
        @fact ndims(img) --> 2
        @fact colordim(img) --> 0
        @fact eltype(img) --> RGB4{UFixed8}
        out_name = joinpath(tempdir(), name * ".png")
        QuartzImageIO.save_(out_name, img, "public.png")
        @fact load(out_name) --> convert(Image{RGBA{UFixed8}}, img)
    end
    context("Multichannel timeseries OME") do
        name = "multi-channel-time-series.ome"
        img = testimage(name)
        @fact colorspace(img) --> "Gray"
        @fact ndims(img) --> 3
        @fact colordim(img) --> 0
        @fact eltype(img) --> Gray{UFixed8}
        out_name = joinpath(tempdir(), name * ".png")
        QuartzImageIO.save_(out_name, img, "public.png")
        # Stack saving isn't implemented yet
        @pending load(out_name) --> convert(Image{RGBA{UFixed8}}, img)
    end
end

facts("Streams") do
    name = "lighthouse"
    img = testimage(name)
    out_name = joinpath(tempdir(), name * ".png")
    context("saving") do
        open(out_name, "w") do io
            QuartzImageIO.save(Stream(format"PNG", io), img)
        end
        imgcmp = load(out_name)
        @fact convert(Image{RGB4}, imgcmp) --> img
    end
    context("loading") do
        imgcmp = open(out_name) do io
            QuartzImageIO.load(Stream(format"PNG", io))
        end
        @fact convert(Image{RGB4}, imgcmp) --> img
    end
end

FactCheck.exitstatus()
