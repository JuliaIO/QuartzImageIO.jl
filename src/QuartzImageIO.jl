module QuartzImageIO

using ImageCore, ColorTypes, ColorVectorSpace, FixedPointNumbers, Libdl
import FileIO: DataFormat, @format_str, File, Stream, filename, stream

const CFURLRef = Ptr{Cvoid}
const CFStringRef = Ptr{UInt8}
const CFDictionaryRef = Ptr{Cvoid}
const CGImageDestinationRef = Ptr{Cvoid}
const CGImageRef = Ptr{Cvoid}
const CGColorSpaceRef = Ptr{Cvoid}
const CGContextRef = Ptr{Cvoid}

load(imagefile::File{T}, args...; key_args...) where T <: DataFormat =
    load_(filename(imagefile), args...; key_args...)
load(filename::AbstractString, args...; key_args...) =
    load_(filename, args...; key_args...)
load(imgstream::Stream{T}, args...; key_args...) where T <: DataFormat =
    load_(read(stream(imgstream)), args...; key_args...)
load(imgstream::IO, args...; key_args...) =
    load_(read(imgstream), args...; key_args...)

save(imagefile::File{T}, args...; key_args...) where T <: DataFormat =
    save_(imagefile, args...; key_args...)
save(filename::AbstractString, args...; key_args...) =
    save_(filename, args...; key_args...)
save(imgstream::Stream{T}, args...; key_args...) where T <: DataFormat =
    save_(imgstream, args...; key_args...)

function load_(b::Array{UInt8, 1})
    data = CFDataCreate(b)
    imgsrc = CGImageSourceCreateWithData(data)
    CFRelease(data)
    read_and_release_imgsrc(imgsrc)
end

function load_(filename::String)
    myURL = CFURLCreateWithFileSystemPath(abspath(filename))
    imgsrc = CGImageSourceCreateWithURL(myURL)
    CFRelease(myURL)
    read_and_release_imgsrc(imgsrc)
end

## core, internal function
function read_and_release_imgsrc(imgsrc)
    if imgsrc == C_NULL
        @warn "QuartzImageIO created no image source"
        return nothing
    end
    # Get image information
    imframes = convert(Int, CGImageSourceGetCount(imgsrc))
    if imframes == 0
        # Bail out to ImageMagick
        @warn "QuartzImageIO found no frames"
        CFRelease(imgsrc)
        return nothing
    end
    dict = CGImageSourceCopyPropertiesAtIndex(imgsrc, 0)
    imheight = CFNumberGetValue(CFDictionaryGetValue(dict, "PixelHeight"), Int16)
    imwidth = CFNumberGetValue(CFDictionaryGetValue(dict, "PixelWidth"), Int16)
    isindexed = CFBooleanGetValue(CFDictionaryGetValue(dict, "IsIndexed"))
    if isindexed
        # Bail out to ImageMagick
        @warn "QuartzImageIO: indexed color images not implemented"
        CFRelease(imgsrc)
        return nothing
    end
    hasalpha = CFBooleanGetValue(CFDictionaryGetValue(dict, "HasAlpha"))

    pixeldepth = CFNumberGetValue(CFDictionaryGetValue(dict, "Depth"), Int16)
    # Colormodel is one of: "RGB", "Gray", "CMYK", "Lab"
    colormodel = CFStringGetCString(CFDictionaryGetValue(dict, "ColorModel"))
    if colormodel == ""
        # Bail out to ImageMagick
        @warn "QuartzImageIO found empty colormodel string"
        CFRelease(imgsrc)
        return nothing
    end
    imtype = CFStringGetCString(CGImageSourceGetType(imgsrc))
    alphacode, storagedepth = alpha_and_depth(imgsrc)

    # Get image description string
    # This is unused after the update to Images 0.6, but it would be nice to have again.
    imagedescription = ""
    if imtype == "public.tiff"
        tiffdict = CFDictionaryGetValue(dict, "{TIFF}")
        imagedescription = tiffdict != C_NULL ?
            CFStringGetCString(CFDictionaryGetValue(tiffdict,"ImageDescription")) :
            nothing
    end
    CFRelease(dict)

    # Allocate the buffer and get the pixel data
    sz = imframes > 1 ?
        (convert(Int, imwidth), convert(Int, imheight), convert(Int, imframes)) :
        (convert(Int, imwidth), convert(Int, imheight))
    ufixedtype = Dict(10 => N6f10, 12 => N4f12, 14 => N2f14, 16 => N0f16)
    T = pixeldepth <= 8 ? N0f8 : ufixedtype[pixeldepth]
    if colormodel == "Gray" && alphacode == 0 && storagedepth == 1
        buf = Array{Gray{T}}(undef, sz)
        fillgray!(reshape(reinterpret(T, buf), sz), imgsrc)
    elseif colormodel == "Gray" && alphacode ∈ [1, 3]
        buf = Array{GrayA{T}}(undef, sz)
        fillgrayalpha!(reshape(reinterpret(T, buf), (2, sz...)), imgsrc)
    elseif colormodel == "Gray" && alphacode ∈ [2, 4]
        buf = Array{AGray{T}}(undef, sz)
        fillgrayalpha!(reshape(reinterpret(T, buf), (2, sz...)), imgsrc)
    elseif colormodel == "RGB" && alphacode ∈ [1, 3]
        buf = Array{RGBA{T}}(undef, sz)
        fillcolor!(reshape(reinterpret(T, buf), (4, sz...)), imgsrc, storagedepth)
    elseif colormodel == "RGB" && alphacode ∈ [2, 4]
        buf = Array{ARGB{T}}(undef, sz)
        fillcolor!(reshape(reinterpret(T, buf), (4, sz...)), imgsrc, storagedepth)
    elseif colormodel == "RGB" && alphacode == 0
        buf = Array{RGB{T}}(undef, sz)
        fillcolor!(reshape(reinterpret(T, buf), (3, sz...)), imgsrc, storagedepth)
    elseif colormodel == "RGB" && alphacode ∈ [5, 6]
        buf = alphacode == 5 ? Array{RGB4{T}}(undef, sz) : Array{RGB1{T}}(undef, sz)
        fillcolor!(reshape(reinterpret(T, buf), (4, sz...)), imgsrc, storagedepth)
    else
        @warn "Unknown colormodel ($colormodel) and alphacode ($alphacode) found by QuartzImageIO"
        CFRelease(imgsrc)
        return nothing
    end
    CFRelease(imgsrc)
    # TODO: Override this flip with the Exif information, if available.  See:
    # https://github.com/JuliaIO/ImageMagick.jl/blob/f5fd22dbe5564e57e710de54254425e34fd6571c/src/ImageMagick.jl#L125
    permutedims(buf, [2; 1; 3:ndims(buf)])
end

function alpha_and_depth(imgsrc)
    CGimg = CGImageSourceCreateImageAtIndex(imgsrc, 0)  # Check only first frame
    alphacode = CGImageGetAlphaInfo(CGimg)
    bitspercomponent = CGImageGetBitsPerComponent(CGimg)
    bitsperpixel = CGImageGetBitsPerPixel(CGimg)
    CGImageRelease(CGimg)
    # Alpha codes documented here:
    # https://developer.apple.com/library/mac/documentation/graphicsimaging/reference/CGImage/Reference/reference.html#//apple_ref/doc/uid/TP30000956-CH3g-459700
    # Dividing bits per pixel by bits per component tells us how many
    # color + alpha components we have in each pixel
    alphacode, convert(Int, div(bitsperpixel, bitspercomponent))
end

function fillgray!(buffer::AbstractArray{T, 2}, imgsrc) where T
    imwidth, imheight = size(buffer, 1), size(buffer, 2)
    CGimg = CGImageSourceCreateImageAtIndex(imgsrc, 0)
    imagepixels = CopyImagePixels(CGimg)
    pixelptr = CFDataGetBytePtr(imagepixels, eltype(buffer))
    imbuffer = unsafe_wrap(Array, pixelptr, (imwidth, imheight), own=false)
    buffer[:, :] .= imbuffer
    CFRelease(imagepixels)
    CGImageRelease(CGimg)
end

# Image stack
function fillgray!(buffer::AbstractArray{T, 3}, imgsrc) where T
    imwidth, imheight, nimages = size(buffer, 1), size(buffer, 2), size(buffer, 3)
    for i in 1:nimages
        CGimg = CGImageSourceCreateImageAtIndex(imgsrc, i - 1)
        imagepixels = CopyImagePixels(CGimg)
        pixelptr = CFDataGetBytePtr(imagepixels, T)
        imbuffer = unsafe_wrap(Array, pixelptr, (imwidth, imheight), own=false)
        buffer[:, :, i] .= imbuffer
        CFRelease(imagepixels)
        CGImageRelease(CGimg)
    end
end

function fillgrayalpha!(buffer::AbstractArray{UInt8, 3}, imgsrc)
    imwidth, imheight = size(buffer, 2), size(buffer, 3)
    CGimg = CGImageSourceCreateImageAtIndex(imgsrc, 0)
    imagepixels = CopyImagePixels(CGimg)
    pixelptr = CFDataGetBytePtr(imagepixels, UInt16)
    imbuffer = unsafe_wrap(Array, pixelptr, (imwidth, imheight), own=false)
    buffer[1, :, :] .= imbuffer .& 0xff
    buffer[2, :, :] .= div.(imbuffer .& 0xff00, 256)
    CFRelease(imagepixels)
    CGImageRelease(CGimg)
end
fillgrayalpha!(buffer::AbstractArray{N0f8, 3}, imgsrc) =
    fillgrayalpha!(reinterpret(UInt8, buffer), imgsrc)

function fillcolor!(buffer::AbstractArray{T, 3}, imgsrc, nc) where T
    imwidth, imheight = size(buffer, 2), size(buffer, 3)
    CGimg = CGImageSourceCreateImageAtIndex(imgsrc, 0)
    imagepixels = CopyImagePixels(CGimg)
    pixelptr = CFDataGetBytePtr(imagepixels, T)
    imbuffer = unsafe_wrap(Array, pixelptr, (nc, imwidth, imheight), own=false)
    buffer[:, :, :] .= imbuffer
    CFRelease(imagepixels)
    CGImageRelease(CGimg)
end

function fillcolor!(buffer::AbstractArray{T, 4}, imgsrc, nc) where T
    imwidth, imheight, nimages = size(buffer, 2), size(buffer, 3), size(buffer, 4)
    for i in 1:nimages
        CGimg = CGImageSourceCreateImageAtIndex(imgsrc, i - 1)
        imagepixels = CopyImagePixels(CGimg)
        pixelptr = CFDataGetBytePtr(imagepixels, T)
        imbuffer = unsafe_wrap(Array, pixelptr, (nc, imwidth, imheight), own=false)
        buffer[:, :, :, i] .= imbuffer
        CFRelease(imagepixels)
        CGImageRelease(CGimg)
    end
end

## Saving Images ###############################################################

# For supported pixel formats, see Table 2-1 in:
# https://developer.apple.com/library/content/documentation/GraphicsImaging/Conceptual/drawingwithquartz2d/dq_context/dq_context.html#//apple_ref/doc/uid/TP30001066-CH203-BCIBHHBB

""" `save_(f, img, image_type)`

- f is the file to save to, of type `FileIO.File{DataFormat}`
- image_type should be one of Apple's image types (eg. "public.jpeg")
- permute_horizontal, if true, will transpose the image (flip x and y)
- mapi is the mapping to apply to the data before saving. Defaults to `identity`.
  A useful alternative value is `clamp01nan`.
"""
function save_(f::File{R}, img::AbstractArray;
               permute_horizontal=true, mapi=identity) where R <: DataFormat
    # Setup buffer
    local imgm
    try
        imgm = map(x -> mapCG(mapi(x)), img)
    catch
        @warn """QuartzImageIO: Mapping to the storage type failed.
                Perhaps your data had out-of-range values?
                Try `map(clamp01nan, img)` to clamp values to a valid range."""
        rethrow()
    end
    permute_horizontal && (imgm = permutedims_horizontal(imgm))
    ndims(imgm) > 3 && error("QuartzImageIO: At most 3 dimensions are supported for saving.")
    contig = to_contiguous(imgm)
    buf = to_explicit(contig)
    # Color type and order
    T = eltype(img)
    bitmap_info = zero(UInt32)
    if T <: Union{Gray, GrayA}
        # Note: GrayA is not an Apple supported combination, so we map to Gray
        bitmap_info |= kCGImageAlphaNone
        colorspace = CGColorSpaceCreateWithName("kCGColorSpaceGenericGray")
        components = 1
    elseif T <: Union{RGB, RGB4, HSV, HSL, Lab}
        bitmap_info |= kCGImageAlphaNoneSkipLast
        colorspace = CGColorSpaceCreateWithName("kCGColorSpaceSRGB")
        components = 4
    elseif T <: RGBA
        bitmap_info |= kCGImageAlphaPremultipliedLast
        colorspace = CGColorSpaceCreateWithName("kCGColorSpaceSRGB")
        components = 4
    elseif T <: ARGB
        bitmap_info |= kCGImageAlphaPremultipliedFirst
        colorspace = CGColorSpaceCreateWithName("kCGColorSpaceSRGB")
        components = 4
    elseif T <: Union{BGRA, ABGR}
        error("QuartzImageIO can only handle RGB byte orders")
    else
        error("QuartzImageIO: tried to save unknown buffer type $T")
    end
    # Image bit depth
    S = eltype(buf)
    if S <: Union{Int8, UInt8}
        bits_per_component = 8
        bitmap_info |= kCGBitmapByteOrderDefault
    elseif S <: Union{Int16, UInt16}
        bits_per_component = 16
        bitmap_info |= kCGBitmapByteOrder16Little
    elseif S <: Union{Int32, UInt32}
        # does this even exist?
        bits_per_component = 32
        bitmap_info |= kCGBitmapByteOrder32Little
    elseif S <: Float32
        bits_per_component = 32
        bitmap_info |= kCGBitmapFloatComponents
        bitmap_info |= kCGBitmapByteOrder32Little
    end
    # Image size
    width, height = size(contig)
    nframes = size(contig, 3)
    bytes_per_row = width*components*bits_per_component ÷ 8
    # Output type
    apple_format_names = Dict(format"BMP" => "com.microsoft.bmp",
                              format"GIF" => "com.compuserve.gif",
                              format"JPEG" => "public.jpeg",
                              format"PNG" => "public.png",
                              format"TIFF" => "public.tiff",
                              format"TGA" => "com.truevision.tga-image")
    image_type = apple_format_names[R]
    # Ready to save
    out_url = CFURLCreateWithFileSystemPath(filename(f))
    out_dest = CGImageDestinationCreateWithURL(out_url, image_type, nframes)
    if ndims(imgm) == 2
        bmp_context = CGBitmapContextCreate(buf, width, height, bits_per_component,
                                            bytes_per_row, colorspace, bitmap_info)
        out_image = CGBitmapContextCreateImage(bmp_context)
        CFRelease(bmp_context)
        CGImageDestinationAddImage(out_dest, out_image)
        CGImageRelease(out_image)
    else
        for i in 1:nframes
            bmp_context = CGBitmapContextCreate(buf[:,:,i], width, height,
                                                bits_per_component, bytes_per_row,
                                                colorspace, bitmap_info)
            out_image = CGBitmapContextCreateImage(bmp_context)
            CFRelease(bmp_context)
            CGImageDestinationAddImage(out_dest, out_image)
            CGImageRelease(out_image)
        end
    end
    CGImageDestinationFinalize(out_dest)
    CFRelease(out_dest)
    CFRelease(colorspace)
    CFRelease(out_url)
    nothing
end

function save_(io::Stream, img::AbstractArray; permute_horizontal=true, mapi = clamp01nan)
    write(io, getblob(img, permute_horizontal, mapi))
end

function getblob(img::AbstractArray, permute_horizontal, mapi)
    # In theory we could save the image directly to a buffer via
    # CGImageDestinationCreateWithData - TODO. But I couldn't figure out how
    # to get the length of the CFMutableData object. So I take the inefficient
    # route of saving the image to a temporary file for now.
    temp_file = joinpath(tempdir(), "QuartzImageIO_temp.png")
    save(File(format"PNG", temp_file), img,
         permute_horizontal=permute_horizontal, mapi=mapi)
    read(open(temp_file))
end

# Element-mapping function. Converts to RGB/RGBA and uses
# N0f8 "inner" element type.
const Color1{T} = Color{T, 1}
const Color2{T, C<:Color1} = TransparentColor{C, T, 2}
const Color3{T} = Color{T, 3}
const Color4{T, C<:Color3} = TransparentColor{C, T, 4}

mapCG(c::Color1) = mapCG(convert(Gray, c))
mapCG(c::Gray{T}) where T = convert(Gray{N0f8}, c)
mapCG(c::Gray{T}) where T <: Normed = c

mapCG(c::Color2) = mapCG(convert(Gray, c))
mapCG(c::GrayA{T}) where T = convert(Gray{N0f8}, c)
mapCG(c::GrayA{T}) where T <: Normed = convert(Gray, c)

# Note: macOS does not handle 3 channel buffers, only 4,
# but we can tell it to use or skip that 4th (alpha) channel
mapCG(c::Color3) = mapCG(convert(RGBA, c))
mapCG(c::RGB{T}) where T = convert(RGBA{N0f8}, c)
mapCG(c::RGB{T}) where T <: Normed = convert(RGBA{T}, c)
mapCG(c::RGB4{T}) where T <: Real = convert(RGBA{T}, c)

mapCG(c::Color4) = mapCG(convert(RGBA, c))
mapCG(c::RGBA{T}) where T = convert(RGBA{N0f8}, c)
mapCG(c::RGBA{T}) where T <: Normed = c

mapCG(x::UInt8) = reinterpret(N0f8, x)
mapCG(x::Bool) = convert(N0f8, x)
mapCG(x::AbstractFloat) = convert(N0f8, x)
mapCG(x::Normed) = x

# Make the data contiguous in memory, because writers don't handle stride.
to_contiguous(A::Array) = A
to_contiguous(A::AbstractArray) = collect(A)
to_contiguous(A::BitArray) = convert(Array{N0f8}, A)
to_contiguous(A::ColorView) = to_contiguous(channelview(A))

to_explicit(A::Array{C}) where C <: Colorant = to_explicit(channelview(A))
to_explicit(A::Base.ReinterpretArray{T}) where T = to_explicit(copyto!(Array{T}(undef, size(A)), A))
to_explicit(A::Array{T}) where T <: Normed = rawview(A)
to_explicit(A::Array{Float32}) = A
to_explicit(A::Array{T}) where T <: AbstractFloat = to_explicit(convert(Array{N0f8}, A))

permutedims_horizontal(img::AbstractVector) = img
function permutedims_horizontal(img)
    # Vertical-major is hard-coded here
    p = [2; 1; 3:ndims(img)]
    permutedims(img, p)
end

## OSX Framework Wrappers ######################################################

# Commented out functions remain here because they might be useful for future
# debugging.

const foundation = Libdl.find_library(["/System/Library/Frameworks/Foundation.framework/Resources/BridgeSupport/Foundation"])
const imageio = Libdl.find_library(["/System/Library/Frameworks/ImageIO.framework/ImageIO"])

const kCFNumberSInt8Type = 1
const kCFNumberSInt16Type = 2
const kCFNumberSInt32Type = 3
const kCFNumberSInt64Type = 4
const kCFNumberFloat32Type = 5
const kCFNumberFloat64Type = 6
const kCFNumberCharType = 7
const kCFNumberShortType = 8
const kCFNumberIntType = 9
const kCFNumberLongType = 10
const kCFNumberLongLongType = 11
const kCFNumberFloatType = 12
const kCFNumberDoubleType = 13
const kCFNumberCFIndexType = 14
const kCFNumberNSIntegerType = 15
const kCFNumberCGFloatType = 16
const kCFNumberMaxType = 16

# enum defined at https://developer.apple.com/library/mac/documentation/GraphicsImaging/Reference/CGImage/index.html#//apple_ref/c/tdef/CGImageAlphaInfo
include("CG_const.jl")

# Objective-C and NS wrappers
oms(id, uid) = ccall(:objc_msgSend, Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}), id, selector(uid))

ogc(id) = ccall((:objc_getClass, "Cocoa.framework/Cocoa"), Ptr{Cvoid}, (Ptr{UInt8}, ), id)

selector(sel::String) = ccall(:sel_getUid, Ptr{Cvoid}, (Ptr{UInt8}, ), sel)

NSString(init::String) = ccall(:objc_msgSend, Ptr{Cvoid},
                               (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{UInt8}, UInt64),
                               oms(ogc("NSString"), "alloc"),
                               selector("initWithCString:encoding:"), init, 4)

# NSLog(str::String, obj) = ccall((:NSLog, foundation), Ptr{Cvoid},
#                                 (Ptr{Cvoid}, Ptr{Cvoid}), NSString(str), obj)

# NSLog(str::String) = ccall((:NSLog, foundation), Ptr{Cvoid},
#                            (Ptr{Cvoid}, ), NSString(str))

# NSLog(obj::Ptr) = ccall((:NSLog, foundation), Ptr{Cvoid}, (Ptr{Cvoid}, ), obj)

# Core Foundation
# General

# CFRetain(CFTypeRef::Ptr{Cvoid}) = CFTypeRef != C_NULL &&
#     ccall(:CFRetain, Void, (Ptr{Cvoid}, ), CFTypeRef)

CFRelease(CFTypeRef::Ptr{Cvoid}) = CFTypeRef != C_NULL &&
    ccall(:CFRelease, Nothing, (Ptr{Cvoid}, ), CFTypeRef)

# function CFGetRetainCount(CFTypeRef::Ptr{Cvoid})
#     CFTypeRef == C_NULL && return 0
#     ccall(:CFGetRetainCount, Clonglong, (Ptr{Cvoid}, ), CFTypeRef)
# end

CFShow(CFTypeRef::Ptr{Cvoid}) = CFTypeRef != C_NULL &&
    ccall(:CFShow, Nothing, (Ptr{Cvoid}, ), CFTypeRef)

# function CFCopyDescription(CFTypeRef::Ptr{Cvoid})
#     CFTypeRef == C_NULL && return C_NULL
#     ccall(:CFCopyDescription, Ptr{Cvoid}, (Ptr{Cvoid}, ), CFTypeRef)
# end

# CFCopyTypeIDDescription(CFTypeID::Cint) = CFTypeRef != C_NULL &&
#     ccall(:CFCopyTypeIDDescription, Ptr{Cvoid}, (Cint, ), CFTypeID)

# function CFGetTypeID(CFTypeRef::Ptr{Cvoid})
#     CFTypeRef == C_NULL && return nothing
#     ccall(:CFGetTypeID, Culonglong, (Ptr{Cvoid}, ), CFTypeRef)
# end

# CFURLCreateWithString(filename) =
#     ccall(:CFURLCreateWithString, Ptr{Cvoid},
#           (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}), C_NULL, NSString(filename), C_NULL)

CFURLCreateWithFileSystemPath(filename::String) =
    ccall(:CFURLCreateWithFileSystemPath, Ptr{Cvoid},
          (Ptr{Cvoid}, Ptr{Cvoid}, Cint, Bool), C_NULL, NSString(filename), 0, false)

# CFDictionary

# CFDictionaryGetKeysAndValues(CFDictionaryRef::Ptr{Cvoid}, keys, values) =
#     CFDictionaryRef != C_NULL &&
#     ccall(:CFDictionaryGetKeysAndValues, Void,
#           (Ptr{Cvoid}, Ptr{Ptr{Cvoid}}, Ptr{Ptr{Cvoid}}), CFDictionaryRef, keys, values)

function CFDictionaryGetValue(CFDictionaryRef::Ptr{Cvoid}, key)
    CFDictionaryRef == C_NULL && return C_NULL
    ccall(:CFDictionaryGetValue, Ptr{Cvoid},
          (Ptr{Cvoid}, Ptr{Cvoid}), CFDictionaryRef, key)
end

CFDictionaryGetValue(CFDictionaryRef::Ptr{Cvoid}, key::String) =
    CFDictionaryGetValue(CFDictionaryRef::Ptr{Cvoid}, NSString(key))

# CFNumber
function CFNumberGetValue(CFNum::Ptr{Cvoid}, numtype)
    CFNum == C_NULL && return nothing
    out = Cint[0]
    ccall(:CFNumberGetValue, Bool, (Ptr{Cvoid}, Cint, Ptr{Cint}), CFNum, numtype, out)
    out[1]
end

CFNumberGetValue(CFNum::Ptr{Cvoid}, ::Type{Int8}) =
    CFNumberGetValue(CFNum, kCFNumberSInt8Type)

CFNumberGetValue(CFNum::Ptr{Cvoid}, ::Type{Int16}) =
    CFNumberGetValue(CFNum, kCFNumberSInt16Type)

CFNumberGetValue(CFNum::Ptr{Cvoid}, ::Type{Int32}) =
    CFNumberGetValue(CFNum, kCFNumberSInt32Type)

CFNumberGetValue(CFNum::Ptr{Cvoid}, ::Type{Int64}) =
    CFNumberGetValue(CFNum, kCFNumberSInt64Type)

CFNumberGetValue(CFNum::Ptr{Cvoid}, ::Type{Float32}) =
    CFNumberGetValue(CFNum, kCFNumberFloat32Type)

CFNumberGetValue(CFNum::Ptr{Cvoid}, ::Type{Float64}) =
    CFNumberGetValue(CFNum, kCFNumberFloat64Type)

CFNumberGetValue(CFNum::Ptr{Cvoid}, ::Type{UInt8}) =
    CFNumberGetValue(CFNum, kCFNumberCharType)

#CFBoolean
CFBooleanGetValue(CFBoolean::Ptr{Cvoid}) =
    CFBoolean != C_NULL &&
    ccall(:CFBooleanGetValue, Bool, (Ptr{Cvoid}, ), CFBoolean)

# CFString
function CFStringGetCString(CFStringRef::Ptr{Cvoid})
    CFStringRef == C_NULL && return ""
    buffer = Array{UInt8}(undef, 1024)  # does this need to be bigger for Open Microscopy TIFFs?
    res = ccall(:CFStringGetCString, Bool, (Ptr{Cvoid}, Ptr{UInt8}, UInt, UInt16),
                CFStringRef, buffer, length(buffer), 0x0600)
    res == C_NULL && return ""
    return unsafe_string(pointer(buffer))
end

# These were unsafe, can return null pointers at random times.
# See Apple Developer Docs
# CFStringGetCStringPtr(CFStringRef::Ptr{Cvoid}) =
#     ccall(:CFStringGetCStringPtr, Ptr{UInt8}, (Ptr{Cvoid}, UInt16), CFStringRef, 0x0600)
#
# getCFString(CFStr::Ptr{Cvoid}) = CFStringGetCStringPtr(CFStr) != C_NULL ?
#     bytestring(CFStringGetCStringPtr(CFStr)) : ""

# Core Graphics
# CGImageSource

CGImageSourceCreateWithURL(myURL::Ptr{Cvoid}) =
    ccall((:CGImageSourceCreateWithURL, imageio), Ptr{Cvoid},
          (Ptr{Cvoid}, Ptr{Cvoid}), myURL, C_NULL)

CGImageSourceCreateWithData(data::Ptr{Cvoid}) =
    ccall((:CGImageSourceCreateWithData, imageio), Ptr{Cvoid},
          (Ptr{Cvoid}, Ptr{Cvoid}), data, C_NULL)

CGImageSourceGetType(CGImageSourceRef::Ptr{Cvoid}) =
    ccall(:CGImageSourceGetType, Ptr{Cvoid}, (Ptr{Cvoid}, ), CGImageSourceRef)

CGImageSourceGetStatus(CGImageSourceRef::Ptr{Cvoid}) =
    ccall(:CGImageSourceGetStatus, UInt32, (Ptr{Cvoid}, ), CGImageSourceRef)

CGImageSourceGetStatusAtIndex(CGImageSourceRef::Ptr{Cvoid}, n) =
    ccall(:CGImageSourceGetStatusAtIndex, Int32,
          (Ptr{Cvoid}, Csize_t), CGImageSourceRef, n) #Int32?

# CGImageSourceCopyProperties(CGImageSourceRef::Ptr{Cvoid}) =
#     ccall(:CGImageSourceCopyProperties, Ptr{Cvoid},
#           (Ptr{Cvoid}, Ptr{Cvoid}), CGImageSourceRef, C_NULL)

CGImageSourceCopyPropertiesAtIndex(CGImageSourceRef::Ptr{Cvoid}, n) =
    ccall(:CGImageSourceCopyPropertiesAtIndex, Ptr{Cvoid},
          (Ptr{Cvoid}, Csize_t, Ptr{Cvoid}), CGImageSourceRef, n, C_NULL)

CGImageSourceGetCount(CGImageSourceRef::Ptr{Cvoid}) =
    ccall(:CGImageSourceGetCount, Csize_t, (Ptr{Cvoid}, ), CGImageSourceRef)

CGImageSourceCreateImageAtIndex(CGImageSourceRef::Ptr{Cvoid}, i) =
    ccall(:CGImageSourceCreateImageAtIndex, Ptr{Cvoid},
          (Ptr{Cvoid}, UInt64, Ptr{Cvoid}), CGImageSourceRef, i, C_NULL)


# CGImageGet

CGImageGetAlphaInfo(CGImageRef::Ptr{Cvoid}) =
    ccall(:CGImageGetAlphaInfo, UInt32, (Ptr{Cvoid}, ), CGImageRef)

# Use this to detect if image contains floating point values
# CGImageGetBitmapInfo(CGImageRef::Ptr{Cvoid}) =
#     ccall(:CGImageGetBitmapInfo, UInt32, (Ptr{Cvoid}, ), CGImageRef)

CGImageGetBitsPerComponent(CGImageRef::Ptr{Cvoid}) =
    ccall(:CGImageGetBitsPerComponent, Csize_t, (Ptr{Cvoid}, ), CGImageRef)

CGImageGetBitsPerPixel(CGImageRef::Ptr{Cvoid}) =
    ccall(:CGImageGetBitsPerPixel, Csize_t, (Ptr{Cvoid}, ), CGImageRef)

# CGImageGetBytesPerRow(CGImageRef::Ptr{Cvoid}) =
#     ccall(:CGImageGetBytesPerRow, Csize_t, (Ptr{Cvoid}, ), CGImageRef)

CGImageGetColorSpace(CGImageRef::Ptr{Cvoid}) =
    ccall(:CGImageGetColorSpace, UInt32, (Ptr{Cvoid}, ), CGImageRef)

# CGImageGetDecode(CGImageRef::Ptr{Cvoid}) =
#     ccall(:CGImageGetDecode, Ptr{Float64}, (Ptr{Cvoid}, ), CGImageRef)

# CGImageGetHeight(CGImageRef::Ptr{Cvoid}) =
#     ccall(:CGImageGetHeight, Csize_t, (Ptr{Cvoid}, ), CGImageRef)

# CGImageGetRenderingIntent(CGImageRef::Ptr{Cvoid}) =
#     ccall(:CGImageGetRenderingIntent, UInt32, (Ptr{Cvoid}, ), CGImageRef)

# CGImageGetShouldInterpolate(CGImageRef::Ptr{Cvoid}) =
#     ccall(:CGImageGetShouldInterpolate, Bool, (Ptr{Cvoid}, ), CGImageRef)

# CGImageGetTypeID() =
#     ccall(:CGImageGetTypeID, Culonglong, (),)

# CGImageGetWidth(CGImageRef::Ptr{Cvoid}) =
#     ccall(:CGImageGetWidth, Csize_t, (Ptr{Cvoid}, ), CGImageRef)

CGImageRelease(CGImageRef::Ptr{Cvoid}) =
    ccall(:CGImageRelease, Nothing, (Ptr{Cvoid}, ), CGImageRef)

# Get pixel data
# See: https://developer.apple.com/library/mac/qa/qa1509/_index.html
CGImageGetDataProvider(CGImageRef::Ptr{Cvoid}) =
    ccall(:CGImageGetDataProvider, Ptr{Cvoid}, (Ptr{Cvoid}, ), CGImageRef)

CGDataProviderCopyData(CGDataProviderRef::Ptr{Cvoid}) =
    ccall(:CGDataProviderCopyData, Ptr{Cvoid}, (Ptr{Cvoid}, ), CGDataProviderRef)

CopyImagePixels(inImage::Ptr{Cvoid}) =
    CGDataProviderCopyData(CGImageGetDataProvider(inImage))

CFDataGetBytePtr(CFDataRef::Ptr{Cvoid}, ::Type{T}) where T =
    ccall(:CFDataGetBytePtr, Ptr{T}, (Ptr{Cvoid}, ), CFDataRef)

# CFDataGetLength(CFDataRef::Ptr{Cvoid}) =
#     ccall(:CFDataGetLength, Ptr{Int64}, (Ptr{Cvoid}, ), CFDataRef)

CFDataCreate(bytes::Array{UInt8,1}) =
    ccall(:CFDataCreate, Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{UInt8}, Csize_t),
          C_NULL, bytes, length(bytes))

### For output #################################################################

""" `check_null(x)`

Triggers an error if `x` is `NULL`, else returns `x` """
function check_null(x)
    # Poor-man's error handling. TODO: raise more specific exceptions.
    if x == C_NULL
        error("C call returned NULL")
    else
        x
    end
end

function CGImageDestinationCreateWithURL(url::CFURLRef,
                                         filetype::String,
                                         count::Integer,
                                         options::CFDictionaryRef=C_NULL)
    check_null(ccall((:CGImageDestinationCreateWithURL, imageio),
                     CGImageDestinationRef,
                     (CFURLRef, CFStringRef, Csize_t, CFDictionaryRef),
                     url, NSString(filetype), count, options))
end


function CGImageDestinationAddImage(dest::CGImageDestinationRef,
                                    image::CGImageRef,
                                    properties::CFDictionaryRef=C_NULL)
    # Returns NULL.
    # From the Apple docs: "The function logs an error if you add more images
    # than what you specified when you created the image destination. "
    # Maybe we should catch that somehow?
    ccall((:CGImageDestinationAddImage, imageio),
          Ptr{Cvoid},
          (CGImageDestinationRef, CGImageRef, CFDictionaryRef),
          dest, image, properties)
end

mutable struct WritingImageFailed <: Exception end

function CGImageDestinationFinalize(dest::CGImageDestinationRef)
    rval = ccall((:CGImageDestinationFinalize, imageio),
                 Bool, (CGImageDestinationRef,), dest)
    # See https://developer.apple.com/library/mac/documentation/GraphicsImaging/Reference/CGImageDestination/index.html#//apple_ref/c/func/CGImageDestinationFinalize
    if !rval throw(WritingImageFailed()) end
end

CGColorSpaceCreateDeviceRGB() =
    check_null(ccall((:CGColorSpaceCreateDeviceRGB, imageio), CGColorSpaceRef, ()))

# Valid colorspace names are (excluding deprecated values):
# kCGColorSpaceGenericRGBLinear, kCGColorSpaceGenericCMYK, kCGColorSpaceGenericXYZ,
# kCGColorSpaceGenericGrayGamma2_2, kCGColorSpaceExtendedGray, kCGColorSpaceLinearGray,
# kCGColorSpaceExtendedLinearGray, kCGColorSpaceSRGB, kCGColorSpaceLinearSRGB,
# kCGColorSpaceExtendedLinearSRGB, kCGColorSpaceDCIP3, kCGColorSpaceDisplayP3,
# kCGColorSpaceAdobeRGB1998, kCGColorSpaceACESCGLinear, kCGColorSpaceITUR_709,
# kCGColorSpaceITUR_2020, kCGColorSpaceROMMRGB
CGColorSpaceCreateWithName(name::String) =
    check_null(ccall((:CGColorSpaceCreateWithName, imageio), CGColorSpaceRef,
                     (CFStringRef,), NSString(name)))


function CGBitmapContextCreate(data, # void*
                               width, height, # size_t
                               bitsPerComponent, bytesPerRow, # size_t
                               space::CGColorSpaceRef,
                               bitmapInfo) # uint32_t
    check_null(ccall((:CGBitmapContextCreate, imageio),
                     CGContextRef,
                     (Ptr{Cvoid}, Csize_t, Csize_t, Csize_t, Csize_t,
                      CGColorSpaceRef, UInt32),
                     data, width, height, bitsPerComponent, bytesPerRow,
                     space, bitmapInfo))
end

function CGBitmapContextCreateImage(context_ref::CGContextRef)
    check_null(ccall((:CGBitmapContextCreateImage, imageio),
                     CGImageRef,
                     (CGContextRef,), context_ref))
end


function __init__()
    if !Sys.isapple()
        # change this to an error in future
        @warn("""
              QuartzImageIO.jl can only be used on Apple macOS. Suggested usage is
                  @static if Sys.isapple()
                      using QuartzImageIO
                      # QuartzImageIO specific code goes here
                  end
              """)
    end
end

end # Module
