using Libdl

function find_lib_ker()
    if haskey(ENV,"JULIA_MATHLINK") && haskey(ENV,"JULIA_MATHKERNEL")
        return ENV["JULIA_MATHLINK"], ENV["JULIA_MATHKERNEL"]
    elseif Sys.isapple()
        # we query OS X metadata for possible non-default installations
        # TODO: can use `mdls -raw -name kMDItemVersion $path` to get the version
                
        # Mathematica
        for path in readlines(`mdfind "kMDItemCFBundleIdentifier == 'com.wolfram.Mathematica'"`)
            lib = joinpath(path,"Contents/Frameworks/mathlink.framework/mathlink")
            ker = joinpath(path,"Contents/MacOS/MathKernel")
            if isfile(lib) && isfile(ker)
                return lib, ker
            end
        end

        # Wolfram Engine
        for path in readlines(`mdfind "kMDItemCFBundleIdentifier == 'com.wolfram.engine'"`)
            # kernels are located in sub-application
            subpath = joinpath(path, "Contents/Resources/Wolfram Player.app")
            lib = joinpath(subpath,"Contents/Frameworks/mathlink.framework/mathlink")
            ker = joinpath(subpath,"Contents/MacOS/MathKernel")
            if isfile(lib) && isfile(ker)
                return lib, ker
            end
        end

    elseif Sys.isunix()
        archdir = Sys.ARCH == :arm ?    "Linux-ARM" :
                  Sys.ARCH == :x86_64 ? "Linux-x86-64" :
                                        "Linux"

        # alternatively, "math" or "wolfram" is often in PATH, so could use
        # echo \$InstallationDirectory | math | sed -n -e 's/Out\[1\]= //p'

        for mpath in ["/usr/local/Wolfram/Mathematica","/opt/Wolfram/WolframEngine"]
            if isdir(mpath)
                vers = readdir(mpath)
                ver = vers[argmax(map(VersionNumber,vers))]

                lib = Libdl.find_library(
                    ["libML$(Sys.WORD_SIZE)i4","libML$(Sys.WORD_SIZE)i3"],
                    [joinpath(mpath,ver,"SystemFiles/Links/MathLink/DeveloperKit",archdir,"CompilerAdditions")])
                ker = joinpath(mpath,ver,"Executables/MathKernel")
                return lib, ker
            end
        end

    elseif Sys.iswindows()
        archdir = Sys.ARCH == :x86_64 ? "Windows-x86-64" :
            "Windows"

        #TODO: query Windows Registry, see RCall.jl
        mpath = "C:\\Program Files\\Wolfram Research\\Mathematica"
        if isdir(mpath)
            vers = readdir(mpath)
            ver = vers[argmax(map(VersionNumber,vers))]
            lib = Libdl.find_library(
                ["libML$(Sys.WORD_SIZE)i4","libML$(Sys.WORD_SIZE)i3"],
                [joinpath(mpath,ver,"SystemFiles\\Links\\MathLink\\DeveloperKit",archdir,"SystemAdditions")])
            ker = joinpath(mpath,ver,"math.exe")
            return lib, ker
        end
    end

    error("Could not find Mathematica or Wolfram Engine installation.\nPlease set the `JULIA_MATHLINK` and `JULIA_MATHKERNEL` variables.")
end

mlib,mker = find_lib_ker()

open("deps.jl","w") do f
    println(f, "# this file is automatically generated")
    println(f, :(const mlib = $mlib))
    println(f, :(const mker = $mker))
end
