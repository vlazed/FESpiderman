local Rostruct = loadstring(game:HttpGetAsync(
    "https://github.com/richie0866/Rostruct/releases/download/"
    .. "v1.1.11"
    .. "/Rostruct.lua"
))()

print("Fetching package")
    -- Download the latest release to local files
return Rostruct.fetchLatest("vlazed", "FEDancePlayer")
    -- Then, build and start all scripts
    :andThen(function(package)
        print("Building package")
        package:build("src/")
        print("Starting package")
        package:start()
    end):expect()