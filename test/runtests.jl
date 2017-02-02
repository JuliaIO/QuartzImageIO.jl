using Base.Test, FileIO, QuartzImageIO, ColorTypes, FixedPointNumbers, TestImages

# Saving notes:
# autumn_leaves and toucan fail as of November 2015. The "edges" of the
# leaves are visibly different after a save+load cycle. Not sure if the
# reader or the writer is to blame. Probably an alpha channel issue.
# Mri-stack and multichannel timeseries OME are both image stacks,
# but the save code only saves the first frame at the moment.

@testset "Local" begin
    imagedir = joinpath(dirname(@__FILE__), "images")
    images = readdir(imagedir)
    @testset "$image" for image in images
        img = load(joinpath(imagedir, image))
        @test isa(img, Array)
    end
end

mydir = tempdir() * "/QuartzImages"
ispath(mydir) || mkdir(mydir)

@testset "TestImages" begin
    @testset "Autumn leaves" begin
        name = "autumn_leaves"
        img = testimage(name)
        @test ndims(img) == 2
        @test eltype(img) == RGBA{N0f16}
        out_name = joinpath(mydir, name * ".png")
        # Calling `save` relies on FileIO dispatching to us, so we
        # make the call explicit.
        QuartzImageIO.save_(out_name, img, "public.png")
        # Ideally, the `convert` would not be necessary, but the
        # saving step goes through a conversion, so we need to do it
        # in this test
        oimg = load(out_name)
        @test size(oimg) == size(img)
        @test eltype(oimg) == eltype(img)
        # Note: around 10% of pixel values are not identical. Precision?
        # @test oimg == img
    end
    @testset "Camerman" begin
        name = "cameraman"
        img = testimage(name)
        @test ndims(img) == 2
        @test eltype(img) == Gray{N0f8}
        out_name = joinpath(mydir, name * ".png")
        QuartzImageIO.save_(out_name, img, "public.png")
        oimg = load(out_name)
        @test size(oimg) == size(img)
        @test eltype(oimg) == eltype(img)
    end
    @testset "Earth Apollo" begin
        name = "earth_apollo17"
        img = testimage(name)
        @test ndims(img) == 2
        @test eltype(img) == RGB4{N0f8}
        out_name = joinpath(mydir, name * ".png")
        QuartzImageIO.save_(out_name, img, "public.png")
        oimg = load(out_name)
        @test size(oimg) == size(img)
        @test eltype(oimg) == eltype(img)
    end
    @testset "Fabio" begin
        name = "fabio"
        img = testimage(name)
        @test ndims(img) == 2
        @test eltype(img) == RGB4{N0f8}
        out_name = joinpath(mydir, name * ".png")
        QuartzImageIO.save_(out_name, img, "public.png")
        oimg = load(out_name)
        @test size(oimg) == size(img)
        @test eltype(oimg) == eltype(img)
    end
    @testset "House" begin
        name = "house"
        img = testimage(name)
        @test ndims(img) == 2
        @test eltype(img) == GrayA{N0f8}
        out_name = joinpath(mydir, name * ".png")
        QuartzImageIO.save_(out_name, img, "public.png")
        oimg = load(out_name)
        @test size(oimg) == size(img)
        @test eltype(oimg) == eltype(img)
    end
    @testset "Jetplane" begin
        name = "jetplane"
        img = testimage(name)
        @test ndims(img) == 2
        @test eltype(img) == GrayA{N0f8}
        out_name = joinpath(mydir, name * ".png")
        QuartzImageIO.save_(out_name, img, "public.png")
        oimg = load(out_name)
        @test size(oimg) == size(img)
        @test eltype(oimg) == eltype(img)
    end
    @testset "Lighthouse" begin
        name = "lighthouse"
        img = testimage(name)
        @test ndims(img) == 2
        @test eltype(img) == RGB4{N0f8}
        out_name = joinpath(mydir, name * ".png")
        QuartzImageIO.save_(out_name, img, "public.png")
        oimg = load(out_name)
        @test size(oimg) == size(img)
        @test eltype(oimg) == eltype(img)
    end
    @testset "Mandrill" begin
        name = "mandrill"
        img = testimage(name)
        @test ndims(img) == 2
        @test eltype(img) == RGB{N0f8}
        out_name = joinpath(mydir, name * ".png")
        QuartzImageIO.save_(out_name, img, "public.png")
        oimg = load(out_name)
        @test size(oimg) == size(img)
        # RGB4 vs. RGB problem
        #@test_skip eltype(oimg) == eltype(img)
    end
    @testset "Moonsurface" begin
        name = "moonsurface"
        img = testimage(name)
        @test ndims(img) == 2
        @test eltype(img) == Gray{N0f8}
        out_name = joinpath(mydir, name * ".png")
        QuartzImageIO.save_(out_name, img, "public.png")
        oimg = load(out_name)
        @test size(oimg) == size(img)
        @test eltype(oimg) == eltype(img)
    end
    @testset "Mountainstream" begin
        name = "mountainstream"
        img = testimage(name)
        @test ndims(img) == 2
        @test eltype(img) == RGB4{N0f8}
        out_name = joinpath(mydir, name * ".png")
        QuartzImageIO.save_(out_name, img, "public.png")
        oimg = load(out_name)
        @test size(oimg) == size(img)
        @test eltype(oimg) == eltype(img)
    end
    @testset "MRI Stack" begin
        name = "mri-stack"
        img = testimage(name)
        @test ndims(img) == 3
        @test eltype(img) == Gray{N0f8}
        out_name = joinpath(mydir, name * ".png")
#        QuartzImageIO.save_(out_name, img, "public.png")
        # Stack saving isn't implemented yet
#        @test_skip load(out_name) == convert(RGBA{N0f8}, img)
    end
    @testset "M51" begin
        name = "m51"
        img = testimage(name)
        @test ndims(img) == 2
        @test eltype(img) == Gray{N0f16}
        out_name = joinpath(mydir, name * ".png")
        QuartzImageIO.save_(out_name, img, "public.png")
        oimg = load(out_name)
        @test size(oimg) == size(img)
        @test eltype(oimg) == eltype(img)
    end
    @testset "HeLa cells" begin
        name = "hela-cells"
        img = testimage(name)
        @test ndims(img) == 2
        @test eltype(img) == RGB{N0f16}
        out_name = joinpath(mydir, name * ".png")
        QuartzImageIO.save_(out_name, img, "public.png")
        oimg = load(out_name)
        @test size(oimg) == size(img)
        @test eltype(oimg) == eltype(img)
    end
    @testset "Blobs GIF" begin
        name = "blobs"
        img = testimage(name)
        @test ndims(img) == 2
        @test eltype(img) == RGB4{N0f8}
        out_name = joinpath(mydir, name * ".png")
        QuartzImageIO.save_(out_name, img, "public.png")
        oimg = load(out_name)
        @test size(oimg) == size(img)
        @test eltype(oimg) == eltype(img)
    end
    @testset "Multichannel timeseries OME" begin
        name = "multi-channel-time-series.ome"
        img = testimage(name)
        @test ndims(img) == 3
        @test eltype(img) == Gray{N0f8}
        out_name = joinpath(mydir, name * ".png")
#        QuartzImageIO.save_(out_name, img, "public.png")
        # Stack saving isn't implemented yet
#        @test_skip load(out_name) == convert(RGBA{N0f8}, img)
    end
end

@testset "Streams" begin
    name = "lighthouse"
    img = testimage(name)
    out_name = joinpath(mydir, name * ".png")
    @testset "saving" begin
        open(out_name, "w") do io
            QuartzImageIO.save(Stream(format"PNG", io), img)
        end
        imgcmp = load(out_name)
        @test imgcmp == img
    end
    @testset "loading" begin
        imgcmp = open(out_name) do io
            QuartzImageIO.load(Stream(format"PNG", io))
        end
        @test imgcmp == img
    end
end

rm(mydir, recursive=true)
