return function (modules, m, dir)
    local lib, err = loadfile(('%s/%s.lua'):format((dir or '.'), m))

    if not lib then
        return ('failed to load %s: %s'):format(m, err)
    end

    package.loaded[m] = lib()
    modules[m] = package.loaded[m]

    return ('successfully loaded %s. Tada!'):format(m)
end
