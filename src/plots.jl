
# Timeline
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


# Habitat
function plot_habitats!(fig, data; 
    colormap, nrows, ncols, show_uncertain=true
) 
    whites = [RGB(1), RGB(1)] 
    axs = map(axes(data.certain, Ti)) do i
        stripe = Makie.LinePattern(; 
            direction=Vec2f(1), width=3, tilesize=(10, 10),
            linecolor=(:grey, 0.7), background_color=(:white, 0.0)
        )
        n = length(axes(data.certain, Ti))
        r = rem(n, i)
        ax = Axis(fig[fldmod1(i, ncols)...]; 
            # aspect=DataAspect(),
            autolimitaspect=1,
            title=string(lookup(data.certain, Ti)[i]),
            titlesize=20,
        )
        tight_ticklabel_spacing!(ax)
        if show_uncertain
            uncertain = data.uncertain[Ti=i]
            Makie.heatmap!(ax, uncertain; alpha=0.5, colormap)
            stripemask = map(uncertain) do x
                x > 0 ? missing : 1
            end
            bs = Rasters.bounds(stripemask)
            rect = Polygon([
                Point2f(bs[1][1], bs[2][1]), 
                Point2f(bs[1][1], bs[2][2]), 
                Point2f(bs[1][2], bs[2][2]), 
                Point2f(bs[1][2], bs[2][1]), 
                Point2f(bs[1][1], bs[2][1]), 
            ])
            poly!(ax, rect; color=stripe, strokewidth=0)
            Makie.heatmap!(ax, stripemask; colormap=whites, colorrange=(0, 1))
        end
        Makie.heatmap!(ax, data.certain[Ti=i]; colormap)
        hidedecorations!(ax)
        hidespines!(ax)
        ax
    end
    linkaxes!(axs...)
    axs
end

function plot_aggregate!(ax, data, habitat_colors)
    npixels = count(>(0), view(data.certain, Ti=1))
    certain_agg = map(eachindex(habitat_colors)) do i 
        dropdims(count(data.certain; dims=(X, Y)) do x
            x == i
        end; dims=(X, Y))
    end
    uncertain_agg = map(eachindex(habitat_colors)) do i 
        dropdims(count(data.uncertain; dims=(X, Y)) do x
            x == i
        end; dims=(X, Y))
    end
    # hidedecorations!(line_ax)
    hidespines!(ax)
    base = map(_ -> 0.0, certain_agg[1])

    for i in reverse(eachindex(habitat_colors))
        color = habitat_colors[i]
        stripe = Makie.LinePattern(; 
            direction=Vec2f(1), width=5, tilesize=(20, 20),
            linecolor=(:grey, 0.7), background_color=(color, 0.7),
        )
        a = certain_agg[i] ./ npixels .+ base
        b = (certain_agg[i] .+ uncertain_agg[i]) ./ npixels .+ base
        l = parent(lookup(a, Ti))
        lines!(ax, l, a; color, ticksize=14)
        band!(ax, l, base, a; color)
        pa = Point2f.(l, a)
        pb = Point2f.(l, b)
        polygon = [pa..., pb[end:-1:1]..., pa[1]]
        poly!(ax, polygon; color=stripe, strokewidth=0)#, alpha=0.5)
        base = b
    end
end

function add_legend!(position, habitat_colors, habitat_names)
    fig = position.layout.parent 
    # Legend
    habitat_elements = map(habitat_colors) do color
        PolyElement(; color, strokewidth=0)
    end
    names = replace.(habitat_names, Ref('_' => ' '))
    Legend(position, habitat_elements, names, "Habitat class"; 
        titlesize=22,
        framevisible=false,
        labelsize=18,
        patchsize=(30.0f0, 30.0f0)
    )
end
