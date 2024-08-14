using ColorSchemes
using CairoMakie

include("map_file_list.jl")
include("landcover_compilation.jl")

function plot_timeline(timeline, striped, npixels; 
    states=keys(first(timeline)), 
    showkeys=keys(timeline)
)
    batlow = map(1:6) do i
        ColorSchemes.batlow[(i - 1) / 5]
    end
    l = lookup(first(timeline), Ti)
    xticks = eachindex(l)
    xtickformat = i -> string.(getindex.(Ref(l), Int.(i)))
    x = eachindex(l)
    fig = Figure(size=(2000, 2000));#, backgroundcolor="#a5b4b5")
    j = 1
    statistic = first(showkeys)
    map_axes = map(enumerate(showkeys)) do (j, statistic)
        heatmap_axes = map(1:length(x)) do i 
            A = striped[statistic][Ti=i]
            ax = Axis(fig[j, i]; autolimitaspect=1)
            tight_ticklabel_spacing!(ax)
            Makie.image!(ax, A; colormap=:batlow, colorrange=(1, 6), interpolate=false)
            hidedecorations!(ax)
            hidespines!(ax)
            ax
        end
        heatmap_axes
    end
    line_axis = Axis(fig[length(showkeys)+1, 1:length(x)];
        backgroundcolor=:white, 
        ylabel=titlecase(string(statistic)), 
        limits=((first(xticks) - 0.5, last(xticks) + 0.5), nothing),
        xticks, xtickformat,
    )
    line_axis.xzoomlock = true
    if statistic != :merged 
        hidexdecorations!(line_axis)
    end
    hidespines!(line_axis)
    i = 1
    k = :native
    y = timeline[:merged][k] ./ npixels
    z = (timeline[:merged][k] .- timeline[:uncertain][k]) ./ npixels
    Makie.band!(line_axis, x, y, z; color=batlow[i], alpha=0.4)
    Makie.lines!(line_axis, x, z; color=batlow[i], linewidth=2)
    Makie.linkaxes!(Iterators.flatten(map_axes)...)
    colgap!(fig.layout, Relative(0.001))
    rowgap!(fig.layout, Relative(0.001))
    return fig
end

filelists = define_map_files()
masks = load_srtm_masks() 
landcover_statistics = map(filelists, masks) do f, m
    compile_all(f, m, transitions)
end
timeline_counts = map(summarise_timeline, landcover_statistics)
striped_statistics = stripe_raster(landcover_statistics, states)

name = :mus
map(island_names) do name
    fig = plot_timeline(timeline_counts[name], striped_statistics[name], count(masks[name]))
    save("../images/$(name)_map_timeline.png", fig)
end
