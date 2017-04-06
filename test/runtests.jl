using Base.Test, FileIO, QuartzImageIO, ColorTypes
using FixedPointNumbers, TestImages, ImageAxes
using Images  # For ImageMeta

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
        @test size(img) == (105, 140)
        out_name = joinpath(mydir, name * ".png")
        save(out_name, img)
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
        @test size(img) == (512, 512)
        out_name = joinpath(mydir, name * ".tif")
        save(out_name, img)
        oimg = load(out_name)
        @test size(oimg) == size(img)
        @test eltype(oimg) == eltype(img)
        @test oimg == img
    end
    @testset "Earth Apollo" begin
        name = "earth_apollo17"
        img = testimage(name)
        @test ndims(img) == 2
        @test eltype(img) == RGB4{N0f8}
        @test size(img) == (3002, 3000)
        out_name = joinpath(mydir, name * ".png")
        save(out_name, img)
        oimg = load(out_name)
        @test size(oimg) == size(img)
        @test eltype(oimg) == eltype(img)
        @test oimg == img
    end
    @testset "Fabio" begin
        name = "fabio"
        img = testimage(name)
        @test ndims(img) == 2
        @test eltype(img) == RGB4{N0f8}
        @test size(img) == (256, 256)
        out_name = joinpath(mydir, name * ".png")
        save(out_name, img)
        oimg = load(out_name)
        @test size(oimg) == size(img)
        @test eltype(oimg) == eltype(img)
        @test oimg == img
    end
    @testset "House" begin
        name = "house"
        img = testimage(name)
        @test ndims(img) == 2
        @test eltype(img) == GrayA{N0f8}
        @test size(img) == (512, 512)
        out_name = joinpath(mydir, name * ".png")
#        save(out_name, img)
#        oimg = load(out_name)
#        @test size(oimg) == size(img)
#        @test eltype(oimg) == eltype(img)
#        @test oimg == img
    end
    @testset "Jetplane" begin
        name = "jetplane"
        img = testimage(name)
        @test ndims(img) == 2
        @test eltype(img) == GrayA{N0f8}
        @test size(img) == (512, 512)
        out_name = joinpath(mydir, name * ".png")
#        save(out_name, img)
#        oimg = load(out_name)
#        @test size(oimg) == size(img)
#        @test eltype(oimg) == eltype(img)
#        @test oimg == img
    end
    @testset "Lighthouse" begin
        name = "lighthouse"
        img = testimage(name)
        @test ndims(img) == 2
        @test eltype(img) == RGB4{N0f8}
        @test size(img) == (512, 768)
        out_name = joinpath(mydir, name * ".png")
        save(out_name, img)
        oimg = load(out_name)
        @test size(oimg) == size(img)
        @test eltype(oimg) == eltype(img)
        @test oimg == img
    end
    @testset "Mandrill" begin
        name = "mandrill"
        img = testimage(name)
        @test ndims(img) == 2
        @test eltype(img) == RGB{N0f8}
        @test size(img) == (512, 512)
        out_name = joinpath(mydir, name * ".png")
        save(out_name, img)
        oimg = load(out_name)
        @test size(oimg) == size(img)
        # RGB4 vs. RGB problem
#        @test_skip eltype(oimg) == eltype(img)
#        @test oimg == img
    end
    @testset "Moonsurface" begin
        name = "moonsurface"
        img = testimage(name)
        @test ndims(img) == 2
        @test eltype(img) == Gray{N0f8}
        @test size(img) == (256, 256)
        out_name = joinpath(mydir, name * ".png")
        save(out_name, img)
        oimg = load(out_name)
        @test size(oimg) == size(img)
        @test eltype(oimg) == eltype(img)
        @test oimg == img
    end
    @testset "Mountainstream" begin
        name = "mountainstream"
        img = testimage(name)
        @test ndims(img) == 2
        @test eltype(img) == RGB4{N0f8}
        @test size(img) == (512, 768)
        out_name = joinpath(mydir, name * ".png")
        save(out_name, img)
        oimg = load(out_name)
        @test size(oimg) == size(img)
        @test eltype(oimg) == eltype(img)
        @test oimg == img
    end
    @testset "MRI Stack" begin
        name = "mri-stack"
        img = testimage(name)
        @test isa(img, AxisArray)
        @test map(step, axisvalues(img)) == (1, 1, 5)
        @test ndims(img) == 3
        @test eltype(img) == Gray{N0f8}
        @test size(img) == (226, 186, 27)
        out_name = joinpath(mydir, name * ".png")
        # This TestImage has a special case, labeling the axes.  Pop it out.
        save(out_name, img.data)
        oimg = load(out_name)
        @test size(oimg) == size(img)
        @test eltype(oimg) == eltype(img)
        @test oimg == img
    end
    @testset "M51" begin
        name = "m51"
        img = testimage(name)
        @test ndims(img) == 2
        @test eltype(img) == Gray{N0f16}
        @test size(img) == (510, 320)
        out_name = joinpath(mydir, name * ".png")
        save(out_name, img)
        oimg = load(out_name)
        @test size(oimg) == size(img)
        @test eltype(oimg) == eltype(img)
        @test oimg == img
    end
    @testset "HeLa cells" begin
        name = "hela-cells"
        img = testimage(name)
        @test ndims(img) == 2
        @test eltype(img) == RGB{N0f16}
        @test size(img) == (512, 672)
        out_name = joinpath(mydir, name * ".png")
        save(out_name, img)
        oimg = load(out_name)
        @test size(oimg) == size(img)
        @test eltype(oimg) == eltype(img)
        @test oimg == img
    end
    @testset "Blobs GIF" begin
        name = "blobs"
        img = testimage(name)
        @test ndims(img) == 2
        @test eltype(img) == RGB4{N0f8}
        @test size(img) == (254, 256)
        out_name = joinpath(mydir, name * ".png")
        save(out_name, img)
        oimg = load(out_name)
        @test oimg == img
    end
    @testset "Multichannel timeseries OME" begin
        name = "multi-channel-time-series.ome"
        img = testimage(name)
        @test ndims(img) == 3
        @test eltype(img) == Gray{N0f8}
        @test size(img) == (167, 439, 21)
        out_name = joinpath(mydir, name * ".png")
        save(out_name, img)
        oimg = load(out_name)
        @test size(oimg) == size(img)
        @test eltype(oimg) == eltype(img)
        @test oimg == img
    end
end

@testset "ImageMeta" begin
    # https://github.com/sisl/PGFPlots.jl/issues/5
    img = ImageMeta(rand(RGB{N0f8}, 3, 5))
    out_name = joinpath(mydir, "imagemeta.png")
    save(out_name, img)
    oimg = load(out_name)
    @test oimg == img
end

@testset "Saving" begin
    imgc = rand(RGB{Float32}, 40, 30)
    out_name = joinpath(mydir, "float32.png")
    save(out_name, imgc)
    inimg = load(out_name)
    @test size(imgc) == size(inimg)
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
