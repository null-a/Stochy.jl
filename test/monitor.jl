function watch_files(dir)
    for entry in readdir(dir)
        path = joinpath(dir, entry)
        if isfile(path) && endswith(entry, ".jl")
            println("Watching $path")
            watch_file(callback, path)
        elseif isdir(path)
            watch_files(path)
        else
            #println("Ignoring $path")
        end
    end
end

function callback(fn, args...)
    println("$fn changed, running...\n")
    flush(STDOUT)
    try
        run(`julia test/runtests.jl`)
    catch
    end
end

watch_files(pwd())
wait()
