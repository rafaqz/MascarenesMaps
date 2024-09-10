_prepare(A::Raster) = parent(replace_missing(A))
_prepare(A::Raster{<:Color}) = parent(A)
_prepare(A::AbstractDimArray) = parent(A)
_prepare(A) = A

# Timeline
function plot_compilation!(fig, timeline, striped, npixels;
    states=keys(first(timeline)),
    showkeys=keys(timeline),
    labelsize=50.0,
)
    batlow = map(1:6) do i
        ColorSchemes.batlow[(i - 1) / 5]
    end
    l = lookup(first(timeline), Ti)

    # Generate all axes for heatmaps
    heatmap_axes = map(enumerate(showkeys)) do (j, statistic)
        map(eachindex(l)) do i
            A = striped[statistic][Ti=i]
            if i == 1
                ax = Axis(fig[i, j];
                    autolimitaspect=1,
                    aspect=AxisAspect(1),
                    xlabel=titlecase(replace(string(statistic), '_' => ' ')),
                    xlabelsize=labelsize,
                    xaxisposition=:top,
                )
            else
                ax = Axis(fig[i, j];
                    autolimitaspect=1,
                    aspect=AxisAspect(1),
                )
            end
            Makie.image!(ax, _prepare(A); colormap=:batlow, colorrange=(1, 6), interpolate=false)
            hidedecorations!(ax; label=false)
            hidespines!(ax)
            ax
        end
    end
    # And link them all for zoom and pan
    Makie.linkaxes!(Iterators.flatten(heatmap_axes)...)

    # # Generate
    rev_l = reverse(l)
    line_axis = Axis(fig[1:length(l), length(showkeys)+1];
        backgroundcolor=:white,
        xlabel="Landcover fraction",
        xticklabelsize=labelsize/1.3,
        xlabelsize=labelsize,
        xaxisposition=:top,
        limits=(nothing, (first(eachindex(l)) - 0.5, last(eachindex(l)) + 0.5)),
        yticks=eachindex(l),
        ytickformat=i -> string.(getindex.(Ref(rev_l), Int.(i))),
        ylabel="Year",
        yticklabelsize=labelsize/1.3,
        ylabelsize=labelsize,
        yaxisposition=:right,
    )
    line_axis.xzoomlock = true
    hidespines!(line_axis)

    for (i, k) in enumerate(keys(timeline[:final]))
        ys = eachindex(l)
        low = reverse(timeline[:final][k] ./ npixels)
        high = reverse((timeline[:final][k] .- timeline[:final_uncertainty][k]) ./ npixels)
        Makie.band!(line_axis, Point2f.(low, ys), Point2f.(high, ys); color=batlow[i], alpha=0.4)
        # Makie.lines!(line_axis, Point2f.(low, ys); color=batlow[i], linewidth=2)
    end

    colgap!(fig.layout, Relative(0.001))
    rowgap!(fig.layout, Relative(0.001))

    fig
end

function plot_process!(fig, originals, categorized, standardized, compiled, application=nothing;
    years,
    titlesize=30,
    ylabelsize=titlesize,
    arrowsize=30,
    kw...
)
    row = 1
    original_rows = Symbol[]

    row_years = Int[]
    for year in lookup(compiled, Ti)
        ks = findall(ys -> year in ys, years)
        if length(ks) > 0
            foundfirst = false
            for k in ks
                if first(years[k]) == year
                    foundfirst = true
                    push!(original_rows, k)
                    push!(row_years, year)
                    row += 1
                end
            end
            if !foundfirst
                push!(row_years, year)
                push!(original_rows, first(ks))
                row += 1
            end
        else
            error()
            row += 1
            push!(row_years, year)
        end
    end
    # Replace duplicates with ""
    for i in eachindex(original_rows)
        k = original_rows[i]
        if k in original_rows[1:i-1]
            original_rows[i] = Symbol("")
        end
    end

    axs = Axis[]

    # Original and Categorized
    for (i, k) in enumerate(original_rows)
        k == Symbol("") && continue # Dont plot the same map twice
        ylabel = titlecase(replace(string(k), '_' => '\n'))
        o = originals[k]
        c = categorized[k]
        ax_o = Axis(fig[i, 1];
            autolimitaspect=1,
            title=i == 1 ? "Original" : "",
            ylabel,
            titlesize,
            ylabelsize,
        )
        ax_c = Axis(fig[i, 2];
            autolimitaspect=1,
            title=i == 1 ? "Categorized" : "",
            titlesize,
            ylabelsize,
        )

        hidespines!.((ax_o, ax_c))
        hidedecorations!.((ax_o, ax_c); label=false)

        if !isnothing(o)
            image!(ax_o, _prepare(o))
            push!(axs, ax_o)
        end
        if !isnothing(c)
            image!(ax_c, _prepare(c); interpolate=false, colormap=:inferno)
            push!(axs, ax_c)
        end
    end

    # Links
    nrows = length(row_years)
    line_ax = Axis(fig[:, 3];
        title="Links",
        titlesize,
    )
    hidespines!(line_ax)
    hidedecorations!(line_ax)
    xlims!(line_ax, (0, 1))
    ylims!(line_ax, (0, nrows))

    for (i, k) in enumerate(original_rows)
        k == Symbol("") && continue
        spacer = 0.0
        for y in years[k]
            j = findlast(==(y), row_years)
            x = 0.2
            u = 0.8 - x
            y = nrows - i + 0.5
            v = i == j ? 0.0 : (i - j) + 0.1
            arrows!(line_ax, [x], [y], [u], [v];
                linewidth=5,
                color=:black,
                arrowsize,
            )
            spacer += 0.05
        end
    end

    # Standardized, final and applications
    last_y = typemin(Int)
    for (p, y) in Iterators.reverse(enumerate(row_years))
        last_y == y && continue # Dont plot the same map twice
        last_y = y
        a = standardized[Ti=At(y)]
        b = compiled[Ti=At(y)]
        ax1 = Axis(fig[p, 4];
            autolimitaspect=1,
            title=p == 1 ? "Standardized" : "",
            titlesize,
        )
        y_kw = (; yaxisposition=:right, ylabel=string(y), ylabelsize, titlesize,)
        final_kw = (;
            autolimitaspect=1,
            title=p == 1 ? "Final" : "",
            titlesize,
        )
        final_kw = isnothing(application) ? final_kw : (; final_kw..., y_kw...)
        ax2 = Axis(fig[p, 5]; final_kw...)
        push!(axs, ax1, ax2)
        ab_kw = (interpolate=false, colormap=:batlow, colorrange=(1, 6))

        isnothing(a) || image!(ax1, _prepare(a); ab_kw...)
        isnothing(b) || image!(ax2, _prepare(b); ab_kw...)
        if !isnothing(application)
            ax = Axis(fig[p, 6];
                autolimitaspect=1,
                title=p == 1 ? "Application" : "",
                titlesize,
                y_kw...
            )
            push!(axs, ax)
            i = Rasters.selectindices(dims(application.certain, Ti), At(y))
            plot_habitat!(ax, application, i; colormap=:tableau_20, kw...)
        end
    end

    linkaxes!(axs...)
    hidespines!.(axs)
    hidedecorations!.(axs; label=false)

    colgap!(fig.layout, Relative(0.001))
    rowgap!(fig.layout, Relative(0.001))

    return fig
end

# Habitat
function plot_habitats!(fig, data;
    titlesize=20, nrows, ncols, kw...
)
    axs = map(axes(data.certain, Ti)) do i
        ax = Axis(fig[fldmod1(i, ncols)...];
            autolimitaspect=1,
            title=string(lookup(data.certain, Ti)[i]),
            titlesize,
        )
        plot_habitat!(ax, data, i; kw...)
    end
    linkaxes!(axs...)

    return axs
end

# i = 9
# data = habitat.mus
# show_uncertain = true
function plot_habitat!(ax, data, i; colormap, show_uncertain=true)
    hidedecorations!(ax; label=false)
    hidespines!(ax)
    whites = [RGB(1), RGB(1)]
    stripe = Makie.LinePattern(;
        direction=Vec2f(1),
        width=3,
        tilesize=(8, 8),
        linecolor=(:darkgrey, 0.8),
        background_color=(:black, 0.1),
    )
    n = length(Base.axes(data.certain, Ti))
    r = rem(n, i)

    if show_uncertain
        uncertain = data.uncertain[Ti=i]
        Makie.heatmap!(ax, _prepare(uncertain); alpha=0.9, colormap, transparency=true)
        stripemask = map(uncertain) do x
            x > 0 ? NaN : 1.0
        end
        bs = map(s -> (0, s), size(stripemask))
        rect = Polygon([
            Point2f(bs[1][1], bs[2][1]),
            Point2f(bs[1][1], bs[2][2]),
            Point2f(bs[1][2], bs[2][2]),
            Point2f(bs[1][2], bs[2][1]),
            Point2f(bs[1][1], bs[2][1]),
        ])
        poly!(ax, rect; color=stripe, strokewidth=0, transparency=true)
        Makie.heatmap!(ax, _prepare(stripemask); colormap=whites, colorrange=(0, 1), transparency=true)
    end

    Makie.heatmap!(ax, _prepare(data.certain[Ti=i]); colormap, transparency=true)

    return ax
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
