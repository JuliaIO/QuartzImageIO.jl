using FactCheck, FileIO, QuartzImageIO, Images, Colors, FixedPointNumbers, TestImages

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
        img = testimage("autumn_leaves")
        @fact colorspace(img) --> "RGBA"
        @fact ndims(img) --> 2
        @fact colordim(img) --> 0
        @fact eltype(img) --> RGBA{Ufixed16}
    end
    context("Camerman") do
        img = testimage("cameraman")
        @fact colorspace(img) --> "Gray"
        @fact ndims(img) --> 2
        @fact colordim(img) --> 0
        @fact eltype(img) --> Gray{Ufixed8}
    end
    context("Earth Apollo") do
        img = testimage("earth_apollo17")
        @fact colorspace(img) --> "RGB4"
        @fact ndims(img) --> 2
        @fact colordim(img) --> 0
        @fact eltype(img) --> RGB4{Ufixed8}
    end
    context("Fabio") do
    img = testimage("fabio")
        @fact colorspace(img) --> "Gray"
        @fact ndims(img) --> 2
        @fact colordim(img) --> 0
        @fact eltype(img) --> Gray{Ufixed8}
    end
    context("House") do
        img = testimage("house")
        @fact colorspace(img) --> "GrayA"
        @fact ndims(img) --> 2
        @fact colordim(img) --> 0
        @fact eltype(img) --> GrayA{Ufixed8}
    end
    context("Jetplane") do
        img = testimage("jetplane")
        @fact colorspace(img) --> "GrayA"
        @fact ndims(img) --> 2
        @fact colordim(img) --> 0
        @fact eltype(img) --> GrayA{Ufixed8}
    end
    context("Lighthouse") do
        img = testimage("lighthouse")
        @fact colorspace(img) --> "RGB4"
        @fact ndims(img) --> 2
        @fact colordim(img) --> 0
        @fact eltype(img) --> RGB4{Ufixed8}
    end
    context("Mandrill") do
        img = testimage("mandrill")
        @fact colorspace(img) --> "RGB"
        @fact ndims(img) --> 2
        @fact colordim(img) --> 0
        @fact eltype(img) --> RGB{Ufixed8}
    end
    context("Moonsurface") do
        img = testimage("moonsurface")
        @fact colorspace(img) --> "Gray"
        @fact ndims(img) --> 2
        @fact colordim(img) --> 0
        @fact eltype(img) --> Gray{Ufixed8}
    end
    context("Mountainstream") do
        img = testimage("mountainstream")
        @fact colorspace(img) --> "RGB4"
        @fact ndims(img) --> 2
        @fact colordim(img) --> 0
        @fact eltype(img) --> RGB4{Ufixed8}
    end
end

FactCheck.exitstatus()
