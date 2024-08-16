# deleteat!(Base.LOAD_PATH, 2:3)

using Revise
using MascarenesMaps
using LandscapeChange

basepath = realpath(joinpath(dirname(pathof(MascarenesMaps)), ".."))

filelists = define_map_files()
masks = load_srtm_masks() 

compiled = LandscapeChange.compile_timeline(filelists.mus, masks.mus, states)
landcover_statistics = map(filelists, masks) do f, m
    compile_all(f, m, MascarenesMaps.transitions)
end
timeline_counts = map(summarise_timeline, landcover_statistics)
striped_statistics = stripe_raster(landcover_statistics, MascarenesMaps.states)

name = :mus
map(MascarenesMaps.island_names) do name
    timeline, striped, npixels = timeline_counts[name], striped_statistics[name], count(masks[name])
    fig = plot_timeline(timeline, striped, npixels)
    save("$basepath/images/$(name)_map_timeline.png", fig)
end
