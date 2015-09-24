using OSXNativeIO, FactCheck, Images

facts("OS X reader") do
	imagedir = Pkg.dir("OSXNativeIO", "test", "images")
    images = filter(x-> splitext(x)[2] != ".psd", readdir(imagedir))
    for image in images
    	context(image) do
	    	img = imread(joinpath(imagedir, image))
	    	@fact isa(img, Image) --> true
    	end
    end
end

FactCheck.exitstatus()
