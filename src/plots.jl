
# Timeline
function plot_compilation(timeline, striped, npixels; 
    states=keys(first(timeline)), 
    showkeys=keys(timeline)
)
    batlow = map(1:6) do i
        ColorSchemes.batlow[(i - 1) / 5]
    end
    l = lookup(first(timeline), Ti)
    xticks = x = eachindex(l)
    xtickformat = i -> string.(getindex.(Ref(l), Int.(i)))
    fig = Figure(size=(2000, 2000))

    # Generate all axes for heatmaps
    heatmap_axes = map(enumerate(showkeys)) do (j, statistic)
        map(eachindex(l)) do i 
            A = striped[statistic][Ti=i]
            if i == 1
                ax = Axis(fig[j, i]; autolimitaspect=1, ylabel=string(statistic))
            else
                ax = Axis(fig[j, i]; autolimitaspect=1)
            end
            tight_ticklabel_spacing!(ax)
            Makie.image!(ax, A; colormap=:batlow, colorrange=(1, 6), interpolate=false)
            hidedecorations!(ax)
            hidespines!(ax)
            ax
        end
    end
    # And link them all for zoom and pan
    Makie.linkaxes!(Iterators.flatten(heatmap_axes)...)

    # Generate 
    line_axis = Axis(fig[length(showkeys)+1, 1:length(l)];
        backgroundcolor=:white, 
        limits=((first(xticks) - 0.5, last(xticks) + 0.5), nothing),
        xticks, 
        xtickformat,
    )
    line_axis.xzoomlock = true
    hidespines!(line_axis)

    for (i, k) in enumerate(keys(timeline[:merged]))
        y = timeline[:merged][k] ./ npixels
        z = (timeline[:merged][k] .- timeline[:uncertain][k]) ./ npixels
        Makie.band!(line_axis, x, y, parent(z); color=batlow[i], alpha=0.4)
        Makie.lines!(line_axis, x, parent(z); color=batlow[i], linewidth=2)
    end

    colgap!(fig.layout, Relative(0.001))
    rowgap!(fig.layout, Relative(0.001))

    fig
end

# Habitat
function plot_habitats!(fig, data; 
    colormap, nrows, ncols, show_uncertain=true
) 
    whites = [RGB(1), RGB(1)] 
    axs = map(axes(data.certain, Ti)) do i
        stripe = Makie.LinePattern(; 
            direction=Vec2f(1), 
            width=3, 
            tilesize=(8, 8),
            linecolor=(:darkgrey, 0.8), 
            background_color=(:black, 0.1),
        )
        n = length(Base.axes(data.certain, Ti))
        r = rem(n, i)
        ax = Axis(fig[fldmod1(i, ncols)...]; 
            autolimitaspect=1,
            title=string(lookup(data.certain, Ti)[i]),
            titlesize=30,
        )
        tight_ticklabel_spacing!(ax)
        if show_uncertain
            uncertain = data.uncertain[Ti=i]
            Makie.heatmap!(ax, uncertain; alpha=0.9, colormap, transparency=true)
            stripemask = map(uncertain) do x
                x > 0 ? NaN : 1.0
            end
            bs = Rasters.bounds(stripemask)
            rect = Polygon([
                Point2f(bs[1][1], bs[2][1]), 
                Point2f(bs[1][1], bs[2][2]), 
                Point2f(bs[1][2], bs[2][2]), 
                Point2f(bs[1][2], bs[2][1]), 
                Point2f(bs[1][1], bs[2][1]), 
            ])
            poly!(ax, rect; color=stripe, strokewidth=0, transparency=true)
            Makie.heatmap!(ax, stripemask; colormap=whites, colorrange=(0, 1), transparency=true)
        end
        Makie.heatmap!(ax, data.certain[Ti=i]; colormap, transparency=true)
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
            direction=Vec2f(1), 
            width=3, 
            tilesize=(8, 8),
            linecolor=(:darkgrey, 0.8), 
            background_color=(:black, 0.1),
        )
        a = certain_agg[i] ./ npixels .+ base
        b = (certain_agg[i] .+ uncertain_agg[i]) ./ npixels .+ base
        l = parent(lookup(a, Ti))
        lines!(ax, collect(l), collect(a); color)
        band!(ax, l, base, b; color)
        pa = Point2f.(l, a)
        pb = Point2f.(l, b)
        polygon = [pa..., pb[end:-1:1]..., pa[1]]
        poly!(ax, polygon; color=stripe, strokewidth=0, transparency=true)
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
        titlesize=30,
        framevisible=false,
        labelsize=20,
        patchsize=(30.0f0, 30.0f0)
    )
end
