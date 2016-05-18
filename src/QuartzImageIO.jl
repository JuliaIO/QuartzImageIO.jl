__precompile__(true)
module QuartzImageIO
#import Base: error, size
using Images, Colors, ColorVectorSpace, FixedPointNumbers
import FileIO: @format_str, File, Stream, filename, stream

# We need to export writemime_, since that's how ImageMagick does it.
export writemime_

typealias CFURLRef Ptr{Void}
typealias CFStringRef Ptr{UInt8}
typealias CFDictionaryRef Ptr{Void}
typealias CGImageDestinationRef Ptr{Void}
typealias CGImageRef Ptr{Void}
typealias CGColorSpaceRef Ptr{Void}
typealias CGContextRef Ptr{Void}

image_formats = [
    format"BMP",
    format"GIF",
    format"JPEG",
    format"PNG",
    format"TIFF",
    format"TGA",
]

# There's a way to get the mapping through
# UTTypeCreatePreferredIdentifierForTag, but a dict is less trouble for now
const apple_format_names = Dict(format"BMP" => "com.microsoft.bmp",
                                format"GIF" => "com.compuserve.gif",
                                format"JPEG" => "public.jpeg",
                                format"PNG" => "public.png",
                                format"TIFF" => "public.tiff",
                                format"TGA" => "com.truevision.tga-image")

# The rehash! is necessary because of a precompilation issue
function __init__() Base.rehash!(apple_format_names) end

get_apple_format_name(format) = apple_format_names[format]

for format in image_formats
    eval(quote
        load(image::File{$format}, args...; key_args...) = load_(filename(image), args...; key_args...)
        load(io::Stream{$format}, args...; key_args...) = load_(readbytes(io), args...; key_args...)
        save(fname::File{$format}, img::Image, args...; key_args...) =
            save_(filename(fname), img, get_apple_format_name($format), args...;
                  key_args...)
        save(io::Stream{$format}, img::Image, args...; key_args...) =
            save_(stream(io), img, get_apple_format_name($format), args...;
                  key_args...)
    end)
end



function load_(b::Array{UInt8, 1})
    data = CFDataCreate(b)
    imgsrc = CGImageSourceCreateWithData(data)
    CFRelease(data)
    read_and_release_imgsrc(imgsrc)
end

function load_(filename)
    myURL = CFURLCreateWithFileSystemPath(abspath(filename))
    imgsrc = CGImageSourceCreateWithURL(myURL)
    CFRelease(myURL)
    read_and_release_imgsrc(imgsrc)
end

## core, internal function
function read_and_release_imgsrc(imgsrc)
    if imgsrc == C_NULL
        warn("OSX reader created no image source")
        return nothing
    end
    # Get image information
    imframes = convert(Int, CGImageSourceGetCount(imgsrc))
    if imframes == 0
        # Bail out to ImageMagick
        warn("OSX reader found no frames")
        CFRelease(imgsrc)
        return nothing
    end
    dict = CGImageSourceCopyPropertiesAtIndex(imgsrc, 0)
    imheight = CFNumberGetValue(CFDictionaryGetValue(dict, "PixelHeight"), Int16)
    imwidth = CFNumberGetValue(CFDictionaryGetValue(dict, "PixelWidth"), Int16)
    isindexed = CFBooleanGetValue(CFDictionaryGetValue(dict, "IsIndexed"))
    if isindexed
        # Bail out to ImageMagick
        warn("OSX reader: indexed color images not implemented")
        CFRelease(imgsrc)
        return nothing
    end
    hasalpha = CFBooleanGetValue(CFDictionaryGetValue(dict, "HasAlpha"))

    pixeldepth = CFNumberGetValue(CFDictionaryGetValue(dict, "Depth"), Int16)
    # Colormodel is one of: "RGB", "Gray", "CMYK", "Lab"
    colormodel = CFStringGetCString(CFDictionaryGetValue(dict, "ColorModel"))
    if colormodel == ""
        # Bail out to ImageMagick
        warn("OSX reader found empty colormodel string")
        CFRelease(imgsrc)
        return nothing
    end
    imtype = CFStringGetCString(CGImageSourceGetType(imgsrc))
    alphacode, storagedepth = alpha_and_depth(imgsrc)

    # Get image description string
    imagedescription = ""
    if imtype == "public.tiff"
        tiffdict = CFDictionaryGetValue(dict, "{TIFF}")
        imagedescription = tiffdict != C_NULL ?
            CFStringGetCString(CFDictionaryGetValue(tiffdict, "ImageDescription")) : nothing
    end
    CFRelease(dict)

    # Allocate the buffer and get the pixel data
    sz = imframes > 1 ? (convert(Int, imwidth), convert(Int, imheight), convert(Int, imframes)) : (convert(Int, imwidth), convert(Int, imheight))
    const ufixedtype = Dict(10=>UFixed10, 12=>UFixed12, 14=>UFixed14, 16=>UFixed16)
    T = pixeldepth <= 8 ? UFixed8 : ufixedtype[pixeldepth]
    if colormodel == "Gray" && alphacode == 0 && storagedepth == 1
        buf = Array(Gray{T}, sz)
        fillgray!(reinterpret(T, buf, tuple(sz...)), imgsrc)
    elseif colormodel == "Gray" && in(alphacode, [1, 3])
        buf = Array(GrayA{T}, sz)
        fillgrayalpha!(reinterpret(T, buf, tuple(2, sz...)), imgsrc)
    elseif colormodel == "Gray" && in(alphacode, [2, 4])
        buf = Array(AGray{T}, sz)
        fillgrayalpha!(reinterpret(T, buf, tuple(2, sz...)), imgsrc)
    elseif colormodel == "RGB" && in(alphacode, [1, 3])
        buf = Array(RGBA{T}, sz)
        fillcolor!(reinterpret(T, buf, tuple(4, sz...)), imgsrc, storagedepth)
    elseif colormodel == "RGB" && in(alphacode, [2, 4])
        buf = Array(ARGB{T}, sz)
        fillcolor!(reinterpret(T, buf, tuple(4, sz...)), imgsrc, storagedepth)
    elseif colormodel == "RGB" && alphacode == 0
        buf = Array(RGB{T}, sz)
        fillcolor!(reinterpret(T, buf, tuple(3, sz...)), imgsrc, storagedepth)
    elseif colormodel == "RGB" && in(alphacode, [5, 6])
        buf = alphacode == 5 ? Array(RGB4{T}, sz) : Array(RGB1{T}, sz)
        fillcolor!(reinterpret(T, buf, tuple(4, sz...)), imgsrc, storagedepth)
    else
        warn("Unknown colormodel ($colormodel) and alphacode ($alphacode) found by OSX reader")
        CFRelease(imgsrc)
        return nothing
    end
    CFRelease(imgsrc)

    # Set the image properties
    prop = Dict(
        "spatialorder" => ["x", "y"],
        "pixelspacing" => [1, 1],
        "colorspace" => colormodel,
        "imagedescription" => imagedescription,
        "suppress" => Set(Any["imagedescription"])
    )
    if imframes > 1
        prop["timedim"] = ndims(buf)
    end
    Image(buf, prop)
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
    # color + alpha slices we have in the file.
    alphacode, convert(Int, div(bitsperpixel, bitspercomponent))
end

function fillgray!{T}(buffer::AbstractArray{T, 2}, imgsrc)
    imwidth, imheight = size(buffer, 1), size(buffer, 2)
    CGimg = CGImageSourceCreateImageAtIndex(imgsrc, 0)
    imagepixels = CopyImagePixels(CGimg)
    pixelptr = CFDataGetBytePtr(imagepixels, eltype(buffer))
    imbuffer = pointer_to_array(pixelptr, (imwidth, imheight), false)
    buffer[:, :] = imbuffer
    CFRelease(imagepixels)
    CGImageRelease(CGimg)
end

# Image stack
function fillgray!{T}(buffer::AbstractArray{T, 3}, imgsrc)
    imwidth, imheight, nimages = size(buffer, 1), size(buffer, 2), size(buffer, 3)
    for i in 1:nimages
        CGimg = CGImageSourceCreateImageAtIndex(imgsrc, i - 1)
        imagepixels = CopyImagePixels(CGimg)
        pixelptr = CFDataGetBytePtr(imagepixels, T)
        imbuffer = pointer_to_array(pixelptr, (imwidth, imheight), false)
        buffer[:, :, i] = imbuffer
        CFRelease(imagepixels)
        CGImageRelease(CGimg)
    end
end

function fillgrayalpha!(buffer::AbstractArray{UInt8, 3}, imgsrc)
    imwidth, imheight = size(buffer, 2), size(buffer, 3)
    CGimg = CGImageSourceCreateImageAtIndex(imgsrc, 0)
    imagepixels = CopyImagePixels(CGimg)
    pixelptr = CFDataGetBytePtr(imagepixels, UInt16)
    imbuffer = pointer_to_array(pixelptr, (imwidth, imheight), false)
    buffer[1, :, :] = imbuffer & 0xff
    buffer[2, :, :] = div(imbuffer & 0xff00, 256)
    CFRelease(imagepixels)
    CGImageRelease(CGimg)
end
fillgrayalpha!(buffer::AbstractArray{UFixed8, 3}, imgsrc) = fillgrayalpha!(reinterpret(UInt8, buffer), imgsrc)

function fillcolor!{T}(buffer::AbstractArray{T, 3}, imgsrc, nc)
    imwidth, imheight = size(buffer, 2), size(buffer, 3)
    CGimg = CGImageSourceCreateImageAtIndex(imgsrc, 0)
    imagepixels = CopyImagePixels(CGimg)
    pixelptr = CFDataGetBytePtr(imagepixels, T)
    imbuffer = pointer_to_array(pixelptr, (nc, imwidth, imheight), false)
    buffer[:, :, :] = imbuffer
    CFRelease(imagepixels)
    CGImageRelease(CGimg)
end

function fillcolor!{T}(buffer::AbstractArray{T, 4}, imgsrc, nc)
    imwidth, imheight, nimages = size(buffer, 2), size(buffer, 3), size(buffer, 4)
    for i in 1:nimages
        CGimg = CGImageSourceCreateImageAtIndex(imgsrc, i - 1)
        imagepixels = CopyImagePixels(CGimg)
        pixelptr = CFDataGetBytePtr(imagepixels, T)
        imbuffer = pointer_to_array(pixelptr, (nc, imwidth, imheight), false)
        buffer[:, :, :, i] = imbuffer
        CFRelease(imagepixels)
        CGImageRelease(CGimg)
    end
end

## Saving Images ###############################################################

function save_and_release(cg_img::Ptr{Void}, # CGImageRef
                          fname, image_type::AbstractString)
    out_url = CFURLCreateWithFileSystemPath(fname)
    out_dest = CGImageDestinationCreateWithURL(out_url, image_type, 1)
    CGImageDestinationAddImage(out_dest, cg_img)
    CGImageDestinationFinalize(out_dest)
    CFRelease(out_dest)
    CFRelease(out_url)
    CGImageRelease(cg_img)
    nothing
end

""" `save_(fname, img::Image, image_type)`

- fname is the name of the file to save to
- image_type should be one of Apple's image types (eg. "public.jpeg")
"""
function save_(fname, img::AbstractImage, image_type)
    # TODO:
    # - avoid this convert call where possible
    # - support writing greyscale images
    # - spatialorder? It seems to work already, maybe because of convert.
    img2 = convert(Image{RGBA{UFixed8}}, img)
    buf = reinterpret(FixedPointNumbers.UInt8, Images.data(img2))
    nx, ny = size(img2)
    colspace = CGColorSpaceCreateDeviceRGB()
    bmp_context = CGBitmapContextCreate(buf, nx, ny, 8, nx*4, colspace,
                                        kCGImageAlphaPremultipliedLast)
    CFRelease(colspace)
    cgImage = CGBitmapContextCreateImage(bmp_context)
    CFRelease(bmp_context)

    save_and_release(cgImage, fname, image_type)
end

function save_(io::IO, img::AbstractImage, image_type)
    write(io, getblob(img, image_type))
end

function getblob(img::AbstractImage, format)
    # In theory we could save the image directly to a buffer via
    # CGImageDestinationCreateWithData - TODO. But I couldn't figure out how
    # to get the length of the CFMutableData object. So I take the inefficient
    # route of saving the image to a temporary file for now.
    @assert format == "png" || format == "public.png" # others not supported for now
    temp_file = "/tmp/QuartzImageIO_temp.png"
    save_(temp_file, img, "public.png")
    readbytes(open(temp_file))
end

@deprecate writemime_(io::IO, ::MIME"image/png", img::AbstractImage) save(Stream(format"PNG", io), img)

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
const kCGImageAlphaNone = 0
const kCGImageAlphaPremultipliedLast = 1
const kCGImageAlphaPremultipliedFirst = 2
const kCGImageAlphaLast = 3
const kCGImageAlphaFirst = 4
const kCGImageAlphaNoneSkipLast = 5
const kCGImageAlphaNoneSkipFirst = 6
const kCGImageAlphaOnly = 7

# Objective-C and NS wrappers
oms{T}(id, uid, ::Type{T}=Ptr{Void}) =
    ccall(:objc_msgSend, T, (Ptr{Void}, Ptr{Void}), id, selector(uid))

ogc{T}(id, ::Type{T}=Ptr{Void}) =
    ccall((:objc_getClass, "Cocoa.framework/Cocoa"), Ptr{Void}, (Ptr{UInt8}, ), id)

selector(sel::AbstractString) = ccall(:sel_getUid, Ptr{Void}, (Ptr{UInt8}, ), sel)

NSString(init::AbstractString) = ccall(:objc_msgSend, Ptr{Void},
                               (Ptr{Void}, Ptr{Void}, Ptr{UInt8}, UInt64),
                               oms(ogc("NSString"), "alloc"),
                               selector("initWithCString:encoding:"), init, 4)

# NSLog(str::AbstractString, obj) = ccall((:NSLog, foundation), Ptr{Void},
#                                 (Ptr{Void}, Ptr{Void}), NSString(str), obj)

# NSLog(str::AbstractString) = ccall((:NSLog, foundation), Ptr{Void},
#                            (Ptr{Void}, ), NSString(str))

# NSLog(obj::Ptr) = ccall((:NSLog, foundation), Ptr{Void}, (Ptr{Void}, ), obj)

# Core Foundation
# General

# CFRetain(CFTypeRef::Ptr{Void}) = CFTypeRef != C_NULL &&
#     ccall(:CFRetain, Void, (Ptr{Void}, ), CFTypeRef)

CFRelease(CFTypeRef::Ptr{Void}) = CFTypeRef != C_NULL &&
    ccall(:CFRelease, Void, (Ptr{Void}, ), CFTypeRef)

# function CFGetRetainCount(CFTypeRef::Ptr{Void})
#     CFTypeRef == C_NULL && return 0
#     ccall(:CFGetRetainCount, Clonglong, (Ptr{Void}, ), CFTypeRef)
# end

CFShow(CFTypeRef::Ptr{Void}) = CFTypeRef != C_NULL &&
    ccall(:CFShow, Void, (Ptr{Void}, ), CFTypeRef)

# function CFCopyDescription(CFTypeRef::Ptr{Void})
#     CFTypeRef == C_NULL && return C_NULL
#     ccall(:CFCopyDescription, Ptr{Void}, (Ptr{Void}, ), CFTypeRef)
# end

# CFCopyTypeIDDescription(CFTypeID::Cint) = CFTypeRef != C_NULL &&
#     ccall(:CFCopyTypeIDDescription, Ptr{Void}, (Cint, ), CFTypeID)

# function CFGetTypeID(CFTypeRef::Ptr{Void})
#     CFTypeRef == C_NULL && return nothing
#     ccall(:CFGetTypeID, Culonglong, (Ptr{Void}, ), CFTypeRef)
# end

# CFURLCreateWithString(filename) =
#     ccall(:CFURLCreateWithString, Ptr{Void},
#           (Ptr{Void}, Ptr{Void}, Ptr{Void}), C_NULL, NSString(filename), C_NULL)

CFURLCreateWithFileSystemPath(filename::AbstractString) =
    ccall(:CFURLCreateWithFileSystemPath, Ptr{Void},
          (Ptr{Void}, Ptr{Void}, Cint, Bool), C_NULL, NSString(filename), 0, false)

# CFDictionary

# CFDictionaryGetKeysAndValues(CFDictionaryRef::Ptr{Void}, keys, values) =
#     CFDictionaryRef != C_NULL &&
#     ccall(:CFDictionaryGetKeysAndValues, Void,
#           (Ptr{Void}, Ptr{Ptr{Void}}, Ptr{Ptr{Void}}), CFDictionaryRef, keys, values)

function CFDictionaryGetValue(CFDictionaryRef::Ptr{Void}, key)
    CFDictionaryRef == C_NULL && return C_NULL
    ccall(:CFDictionaryGetValue, Ptr{Void},
          (Ptr{Void}, Ptr{Void}), CFDictionaryRef, key)
end

CFDictionaryGetValue(CFDictionaryRef::Ptr{Void}, key::AbstractString) =
    CFDictionaryGetValue(CFDictionaryRef::Ptr{Void}, NSString(key))

# CFNumber
function CFNumberGetValue(CFNum::Ptr{Void}, numtype)
    CFNum == C_NULL && return nothing
    out = Cint[0]
    ccall(:CFNumberGetValue, Bool, (Ptr{Void}, Cint, Ptr{Cint}), CFNum, numtype, out)
    out[1]
end

CFNumberGetValue(CFNum::Ptr{Void}, ::Type{Int8}) =
    CFNumberGetValue(CFNum, kCFNumberSInt8Type)

CFNumberGetValue(CFNum::Ptr{Void}, ::Type{Int16}) =
    CFNumberGetValue(CFNum, kCFNumberSInt16Type)

CFNumberGetValue(CFNum::Ptr{Void}, ::Type{Int32}) =
    CFNumberGetValue(CFNum, kCFNumberSInt32Type)

CFNumberGetValue(CFNum::Ptr{Void}, ::Type{Int64}) =
    CFNumberGetValue(CFNum, kCFNumberSInt64Type)

CFNumberGetValue(CFNum::Ptr{Void}, ::Type{Float32}) =
    CFNumberGetValue(CFNum, kCFNumberFloat32Type)

CFNumberGetValue(CFNum::Ptr{Void}, ::Type{Float64}) =
    CFNumberGetValue(CFNum, kCFNumberFloat64Type)

CFNumberGetValue(CFNum::Ptr{Void}, ::Type{UInt8}) =
    CFNumberGetValue(CFNum, kCFNumberCharType)

#CFBoolean
CFBooleanGetValue(CFBoolean::Ptr{Void}) =
    CFBoolean != C_NULL &&
    ccall(:CFBooleanGetValue, Bool, (Ptr{Void}, ), CFBoolean)

# CFString
function CFStringGetCString(CFStringRef::Ptr{Void})
    CFStringRef == C_NULL && return ""
    buffer = Array(UInt8, 1024)  # does this need to be bigger for Open Microscopy TIFFs?
    res = ccall(:CFStringGetCString, Bool, (Ptr{Void}, Ptr{UInt8}, UInt, UInt16),
                CFStringRef, buffer, length(buffer), 0x0600)
    res == C_NULL && return ""
    return bytestring(pointer(buffer))
end

# These were unsafe, can return null pointers at random times.
# See Apple Developer Docs
# CFStringGetCStringPtr(CFStringRef::Ptr{Void}) =
#     ccall(:CFStringGetCStringPtr, Ptr{UInt8}, (Ptr{Void}, UInt16), CFStringRef, 0x0600)
#
# getCFString(CFStr::Ptr{Void}) = CFStringGetCStringPtr(CFStr) != C_NULL ?
#     bytestring(CFStringGetCStringPtr(CFStr)) : ""

# Core Graphics
# CGImageSource

CGImageSourceCreateWithURL(myURL::Ptr{Void}) =
    ccall((:CGImageSourceCreateWithURL, imageio), Ptr{Void}, (Ptr{Void}, Ptr{Void}), myURL, C_NULL)

CGImageSourceCreateWithData(data::Ptr{Void}) =
    ccall((:CGImageSourceCreateWithData, imageio), Ptr{Void}, (Ptr{Void}, Ptr{Void}), data, C_NULL)

CGImageSourceGetType(CGImageSourceRef::Ptr{Void}) =
    ccall(:CGImageSourceGetType, Ptr{Void}, (Ptr{Void}, ), CGImageSourceRef)

CGImageSourceGetStatus(CGImageSourceRef::Ptr{Void}) =
    ccall(:CGImageSourceGetStatus, UInt32, (Ptr{Void}, ), CGImageSourceRef)

CGImageSourceGetStatusAtIndex(CGImageSourceRef::Ptr{Void}, n) =
    ccall(:CGImageSourceGetStatusAtIndex, Int32,
          (Ptr{Void}, Csize_t), CGImageSourceRef, n) #Int32?

# CGImageSourceCopyProperties(CGImageSourceRef::Ptr{Void}) =
#     ccall(:CGImageSourceCopyProperties, Ptr{Void},
#           (Ptr{Void}, Ptr{Void}), CGImageSourceRef, C_NULL)

CGImageSourceCopyPropertiesAtIndex(CGImageSourceRef::Ptr{Void}, n) =
    ccall(:CGImageSourceCopyPropertiesAtIndex, Ptr{Void},
          (Ptr{Void}, Csize_t, Ptr{Void}), CGImageSourceRef, n, C_NULL)

CGImageSourceGetCount(CGImageSourceRef::Ptr{Void}) =
    ccall(:CGImageSourceGetCount, Csize_t, (Ptr{Void}, ), CGImageSourceRef)

CGImageSourceCreateImageAtIndex(CGImageSourceRef::Ptr{Void}, i) =
    ccall(:CGImageSourceCreateImageAtIndex, Ptr{Void},
          (Ptr{Void}, UInt64, Ptr{Void}), CGImageSourceRef, i, C_NULL)


# CGImageGet

CGImageGetAlphaInfo(CGImageRef::Ptr{Void}) =
    ccall(:CGImageGetAlphaInfo, UInt32, (Ptr{Void}, ), CGImageRef)

# Use this to detect if image contains floating point values
# CGImageGetBitmapInfo(CGImageRef::Ptr{Void}) =
#     ccall(:CGImageGetBitmapInfo, UInt32, (Ptr{Void}, ), CGImageRef)

CGImageGetBitsPerComponent(CGImageRef::Ptr{Void}) =
    ccall(:CGImageGetBitsPerComponent, Csize_t, (Ptr{Void}, ), CGImageRef)

CGImageGetBitsPerPixel(CGImageRef::Ptr{Void}) =
    ccall(:CGImageGetBitsPerPixel, Csize_t, (Ptr{Void}, ), CGImageRef)

# CGImageGetBytesPerRow(CGImageRef::Ptr{Void}) =
#     ccall(:CGImageGetBytesPerRow, Csize_t, (Ptr{Void}, ), CGImageRef)

CGImageGetColorSpace(CGImageRef::Ptr{Void}) =
    ccall(:CGImageGetColorSpace, UInt32, (Ptr{Void}, ), CGImageRef)

# CGImageGetDecode(CGImageRef::Ptr{Void}) =
#     ccall(:CGImageGetDecode, Ptr{Float64}, (Ptr{Void}, ), CGImageRef)

# CGImageGetHeight(CGImageRef::Ptr{Void}) =
#     ccall(:CGImageGetHeight, Csize_t, (Ptr{Void}, ), CGImageRef)

# CGImageGetRenderingIntent(CGImageRef::Ptr{Void}) =
#     ccall(:CGImageGetRenderingIntent, UInt32, (Ptr{Void}, ), CGImageRef)

# CGImageGetShouldInterpolate(CGImageRef::Ptr{Void}) =
#     ccall(:CGImageGetShouldInterpolate, Bool, (Ptr{Void}, ), CGImageRef)

# CGImageGetTypeID() =
#     ccall(:CGImageGetTypeID, Culonglong, (),)

# CGImageGetWidth(CGImageRef::Ptr{Void}) =
#     ccall(:CGImageGetWidth, Csize_t, (Ptr{Void}, ), CGImageRef)

CGImageRelease(CGImageRef::Ptr{Void}) =
    ccall(:CGImageRelease, Void, (Ptr{Void}, ), CGImageRef)

# Get pixel data
# See: https://developer.apple.com/library/mac/qa/qa1509/_index.html
CGImageGetDataProvider(CGImageRef::Ptr{Void}) =
    ccall(:CGImageGetDataProvider, Ptr{Void}, (Ptr{Void}, ), CGImageRef)

CGDataProviderCopyData(CGDataProviderRef::Ptr{Void}) =
    ccall(:CGDataProviderCopyData, Ptr{Void}, (Ptr{Void}, ), CGDataProviderRef)

CopyImagePixels(inImage::Ptr{Void}) =
    CGDataProviderCopyData(CGImageGetDataProvider(inImage))

CFDataGetBytePtr{T}(CFDataRef::Ptr{Void}, ::Type{T}) =
    ccall(:CFDataGetBytePtr, Ptr{T}, (Ptr{Void}, ), CFDataRef)

# CFDataGetLength(CFDataRef::Ptr{Void}) =
#     ccall(:CFDataGetLength, Ptr{Int64}, (Ptr{Void}, ), CFDataRef)

CFDataCreate(bytes::Array{UInt8,1}) =
    ccall(:CFDataCreate,Ptr{Void},(Ptr{Void},Ptr{UInt8},Csize_t),C_NULL,bytes,length(bytes))

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
                                         filetype::AbstractString,
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
          Ptr{Void},
          (CGImageDestinationRef, CGImageRef, CFDictionaryRef),
          dest, image, properties)
end


type WritingImageFailed <: Exception end
function CGImageDestinationFinalize(dest::CGImageDestinationRef)
    rval = ccall((:CGImageDestinationFinalize, imageio),
                 Bool, (CGImageDestinationRef,), dest)
    # See https://developer.apple.com/library/mac/documentation/GraphicsImaging/Reference/CGImageDestination/index.html#//apple_ref/c/func/CGImageDestinationFinalize
    if !rval throw(WritingImageFailed()) end
end

CGColorSpaceCreateDeviceRGB() =
    check_null(ccall((:CGColorSpaceCreateDeviceRGB, imageio),
                     CGColorSpaceRef, ()))

function CGBitmapContextCreate(data, # void*
                               width, height, # size_t
                               bitsPerComponent, bytesPerRow, # size_t
                               space::CGColorSpaceRef,
                               bitmapInfo) # uint32_t
    check_null(ccall((:CGBitmapContextCreate, imageio),
                     CGContextRef,
                     (Ptr{Void}, Csize_t, Csize_t, Csize_t, Csize_t,
                      CGColorSpaceRef, UInt32),
                     data, width, height, bitsPerComponent, bytesPerRow, space,
                     bitmapInfo))
end

function CGBitmapContextCreateImage(context_ref::CGContextRef)
    check_null(ccall((:CGBitmapContextCreateImage, imageio),
                     CGImageRef,
                     (CGContextRef,), context_ref))
end


end # Module
