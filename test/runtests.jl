using Test, Random, FileIO, QuartzImageIO, ColorTypes
using FixedPointNumbers, TestImages, ImageAxes
using ImageMetadata
using OffsetArrays

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
        # Note: this is a GrayA image, not supported by Apple
        # So saving as a Gray for now.
        name = "house"
        img = testimage(name)
        @test ndims(img) == 2
        @test eltype(img) == GrayA{N0f8}
        @test size(img) == (512, 512)
        out_name = joinpath(mydir, name * ".tif")
        save(out_name, img)
        oimg = load(out_name)
        @test size(oimg) == size(img)
        @test eltype(oimg) == Gray{N0f8}
        @test oimg == Gray.(img)
    end
    @testset "Jetplane" begin
        # Note: this is a GrayA image, not supported by Apple
        # So saving as a Gray for now.
        name = "jetplane"
        img = testimage(name)
        @test ndims(img) == 2
        @test eltype(img) == GrayA{N0f8}
        @test size(img) == (512, 512)
        out_name = joinpath(mydir, name * ".tif")
        save(out_name, img)
        oimg = load(out_name)
        @test size(oimg) == size(img)
        @test eltype(oimg) == Gray{N0f8}
        @test oimg == Gray.(img)
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
        out_name = joinpath(mydir, name * ".tiff")
        save(out_name, img)
        oimg = load(out_name)
        @test size(oimg) == size(img)
        @test eltype(oimg) == eltype(img)
        @test oimg == img
    end
    @testset "Moonsurface" begin
        name = "moonsurface"
        img = testimage(name)
        @test ndims(img) == 2
        @test eltype(img) == Gray{N0f8}
        @test size(img) == (256, 256)
        out_name = joinpath(mydir, name * ".tif")
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
        out_name = joinpath(mydir, name * ".tif")
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
        out_name = joinpath(mydir, name * ".tif")
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
        out_name = joinpath(mydir, name * ".tif")
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
        # Unclear why this needs to be a .png
        out_name = joinpath(mydir, name * ".png")
        save(out_name, img)
        oimg = load(out_name)
        @test oimg == img
    end
    @testset "Multichannel timeseries OME" begin
        # Note: the existence of OMETIFF.jl breaks this test,
        # even though we don't explicitly import it here.
        # So, we need to do some extra work to call the image
        # with our specific loader here.
        mcifile = "multi-channel-time-series.ome.tif"
        name = joinpath(TestImages.imagedir, mcifile)
        if !isfile(name)
            REPO_URL = "https://github.com/JuliaImages/TestImages.jl/blob/gh-pages/images/"
            download(REPO_URL*mcifile*"?raw=true", name)
        end
        img = QuartzImageIO.load(name)
        @test ndims(img) == 3
        @test eltype(img) == Gray{N0f8}
        @test size(img) == (167, 439, 21)
        out_name = joinpath(mydir, name * ".tif")
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
    @testset "RGB" begin
        imgc = rand(RGB{Float32}, 40, 30)
        out_name = joinpath(mydir, "float32.png")
        save(out_name, imgc)
        inimg = load(out_name)
        @test size(imgc) == size(inimg)
    end

    @testset "HSV" begin
        # issue 37
        Random.seed!(42)
        img = rand(HSV{Float32}, 8, 10)
        out_name = joinpath(mydir, "hsv.png")
        save(out_name, img)
        oimg = load(out_name)
        @test HSV.(oimg)[1].h ≈ img[1].h rtol=0.02 atol=0.003
        @test HSV.(oimg)[1].s ≈ img[1].s rtol=0.02 atol=0.003
        @test HSV.(oimg)[1].v ≈ img[1].v rtol=0.02 atol=0.003
    end

    @testset "HSL" begin
        Random.seed!(42)
        img = rand(HSL{Float32}, 8, 10)
        out_name = joinpath(mydir, "hsl.png")
        save(out_name, img)
        oimg = load(out_name)
        @test HSL.(oimg)[1].h ≈ img[1].h rtol=0.04 atol=0.003
        @test HSL.(oimg)[1].s ≈ img[1].s rtol=0.02 atol=0.005
        @test HSL.(oimg)[1].l ≈ img[1].l rtol=0.02 atol=0.003
    end

    @testset "Lab" begin
        Random.seed!(42)
        img = rand(Lab{Float32}, 8, 10)
        out_name = joinpath(mydir, "Lab.png")
        save(out_name, img)
        oimg = Lab.(load(out_name))
        for I in eachindex(img)
            # Comparing oimg[I] against img[I] may fail because
            # information was lost when saving the Lab values as
            # RGB. Instead, we just verify that oimg[I] = Lab(RGB(img[I]))
            expected = Lab(RGB(img[I]))
            @test oimg[I].l ≈ expected.l rtol=0.07
            @test oimg[I].a ≈ expected.a rtol=0.07 atol=0.35
            @test oimg[I].b ≈ expected.b rtol=0.07 atol=0.35
        end
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

@testset "OffsetArrays" begin
    img = OffsetArray(Gray{N0f8}[1 0; 0 1], 0:1, 3:4)
    fn = joinpath(mydir, "indices.png")
    save(fn, img)
    imgr = load(fn)
    @test imgr == parent(img)
end

rm(mydir, recursive=true)

@test !@isdefined ImageMagick
