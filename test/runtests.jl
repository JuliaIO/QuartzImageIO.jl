using FactCheck, FileIO, Images

facts("OS X reader") do
	imagedir = Pkg.dir("OSXNativeIO", "test", "images")
    images = readdir(imagedir)
    for image in images
    	context(image) do
	    	img = load(joinpath(imagedir, image))
	    	@fact isa(img, Image) --> true
    	end
    end
end

FactCheck.exitstatus()
