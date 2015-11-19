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
        @fact eltype(img) --> RGBA{UFixed16}
    end
    context("Camerman") do
        img = testimage("cameraman")
        @fact colorspace(img) --> "Gray"
        @fact ndims(img) --> 2
        @fact colordim(img) --> 0
        @fact eltype(img) --> Gray{UFixed8}
    end
    context("Earth Apollo") do
        img = testimage("earth_apollo17")
        @fact colorspace(img) --> "RGB4"
        @fact ndims(img) --> 2
        @fact colordim(img) --> 0
        @fact eltype(img) --> RGB4{UFixed8}
    end
    context("Fabio") do
    img = testimage("fabio")
        @fact colorspace(img) --> "Gray"
        @fact ndims(img) --> 2
        @fact colordim(img) --> 0
        @fact eltype(img) --> Gray{UFixed8}
    end
    context("House") do
        img = testimage("house")
        @fact colorspace(img) --> "GrayA"
        @fact ndims(img) --> 2
        @fact colordim(img) --> 0
        @fact eltype(img) --> GrayA{UFixed8}
    end
    context("Jetplane") do
        img = testimage("jetplane")
        @fact colorspace(img) --> "GrayA"
        @fact ndims(img) --> 2
        @fact colordim(img) --> 0
        @fact eltype(img) --> GrayA{UFixed8}
    end
    context("Lighthouse") do
        img = testimage("lighthouse")
        @fact colorspace(img) --> "RGB4"
        @fact ndims(img) --> 2
        @fact colordim(img) --> 0
        @fact eltype(img) --> RGB4{UFixed8}
    end
    context("Mandrill") do
        img = testimage("mandrill")
        @fact colorspace(img) --> "RGB"
        @fact ndims(img) --> 2
        @fact colordim(img) --> 0
        @fact eltype(img) --> RGB{UFixed8}
    end
    context("Moonsurface") do
        img = testimage("moonsurface")
        @fact colorspace(img) --> "Gray"
        @fact ndims(img) --> 2
        @fact colordim(img) --> 0
        @fact eltype(img) --> Gray{UFixed8}
    end
    context("Mountainstream") do
        img = testimage("mountainstream")
        @fact colorspace(img) --> "RGB4"
        @fact ndims(img) --> 2
        @fact colordim(img) --> 0
        @fact eltype(img) --> RGB4{UFixed8}
    end
    context("MRI Stack") do
        img = testimage("mri-stack")
        @fact colorspace(img) --> "Gray"
        @fact ndims(img) --> 3
        @fact colordim(img) --> 0
        @fact eltype(img) --> Gray{UFixed8}
    end
    context("M51") do
        img = testimage("m51")
        @fact colorspace(img) --> "Gray"
        @fact ndims(img) --> 2
        @fact colordim(img) --> 0
        @fact eltype(img) --> Gray{UFixed16}
    end
    context("HeLa cells") do
        img = testimage("hela-cells")
        @fact colorspace(img) --> "RGB"
        @fact ndims(img) --> 2
        @fact colordim(img) --> 0
        @fact eltype(img) --> RGB{UFixed16}
    end
    context("Blobs GIF") do
        img = testimage("blobs")
        @fact colorspace(img) --> "RGB4"
        @fact ndims(img) --> 2
        @fact colordim(img) --> 0
        @fact eltype(img) --> RGB4{UFixed8}
    end
    context("Multichannel timeseries OME") do
        img = testimage("multi-channel-time-series.ome")
        @fact colorspace(img) --> "Gray"
        @fact ndims(img) --> 3
        @fact colordim(img) --> 0
        @fact eltype(img) --> Gray{UFixed8}
    end
end

facts("OS X writer") do
    # autumn_leaves and toucan fail as of November 2015. The "edges" of the
    # leaves are visibly different after a save+load cycle. Not sure if the
    # reader or the writer is to blame. Probably an alpha channel issue.
    # For mri-stack, I don't know why it fails. Also note that it's a grayscale
    # image that somehow doesn't show up in IJulia (it seems that writemime
    # calls another function - maybe that's not this package's fault)
    for img_name in readdir(TestImages.imagedir)
        if !startswith(img_name, "peppers") # not supported yet by the reader
            context("Saving $img_name (as png)") do
                img = testimage(img_name)
                fname = "/tmp/test.png" # lossless format
                save(fname, img)
                # Ideally, the `convert` would not be necessary, but the
                # saving step goes through a conversion, so we need to do it 
                # in this test
                @fact load(fname) --> convert(Image{RGBA{UFixed8}}, img)
            end
        end
    end
end


FactCheck.exitstatus()
