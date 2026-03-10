function triangle_area(ax::Real, ay::Real, bx::Real, by::Real, cx::Real, cy::Real)
    return 0.5 * abs(ax * (by - cy) + bx * (cy - ay) + cx * (ay - by))
end

function lttb(x::Union{LinRange{Float64, Int64},AbstractVector{<:Real}}, y::AbstractVector{<:Real}, threshold::Integer)
    n = length(x)
    if length(y) != n
        throw(ArgumentError("x and y must have the same length"))
    end
    if threshold <= 2 || threshold >= n
        return copy(x), copy(y)
    end

    num_buckets = threshold - 2

    out_x = similar(x, threshold)
    out_y = similar(y, threshold)

    out_x[1] = x[1]
    out_y[1] = y[1]
    out_x[threshold] = x[n]
    out_y[threshold] = y[n]

    for k = 2:(threshold - 1)
        # Calculate current bucket range
        bucket_start = floor(Int, (k - 2) * (n - 2) / num_buckets) + 2
        bucket_end = floor(Int, (k - 1) * (n - 2) / num_buckets) + 1

        # Previous point (from previous bucket)
        prev_x = out_x[k - 1]
        prev_y = out_y[k - 1]

        # Next bucket's average point
        if k == threshold - 1
            # Last middle bucket, next is the final point
            next_x = out_x[threshold]
            next_y = out_y[threshold]
        else
            next_start = floor(Int, (k - 1) * (n - 2) / num_buckets) + 2
            next_end = floor(Int, k * (n - 2) / num_buckets) + 1
            next_x = mean(view(x, next_start:next_end))
            next_y = mean(view(y, next_start:next_end))
        end

        # Find the point in current bucket that maximizes the triangle area
        max_area = -1.0
        selected_idx = bucket_start  # Default to first in bucket

        for j = bucket_start:bucket_end
            curr_x = x[j]
            curr_y = y[j]
            area = triangle_area(prev_x, prev_y, curr_x, curr_y, next_x, next_y)
            if area > max_area
                max_area = area
                selected_idx = j
            end
        end

        out_x[k] = x[selected_idx]
        out_y[k] = y[selected_idx]
    end
    out_x_lr::LinRange{Float64, Int64} = LinRange(out_x[1],out_x[end],length(out_x))
    return out_x_lr, out_y
end


function render_table(ax, tbl)
    # RENDER_TABLE Displays a table in the specified axes using text and lines.
    #   render_table(AX, TBL) renders the table TBL in the axes AX.
    #   This function draws the table content using text objects and adds grid lines.
    #   Column widths are proportional to the maximum content length in each column.
    #   Assumes a fixed-width font for alignment.

    colNames = names(tbl)
    numCols = length(colNames)
    numRows = size(tbl, 1)
    totalRows = numRows + 1  # Including header

    # Convert all table data to strings
    dataStr = [string(tbl[r, c]) for r in 1:numRows, c in 1:numCols]

    # Calculate maximum lengths for each column (for proportional widths)
    maxLens = [maximum(length.([colNames[c]; dataStr[:, c]])) for c in 1:numCols]
    totalLen = sum(maxLens)
    colWidths = maxLens / totalLen
    cumWidths = [0; cumsum(colWidths)]

    # Row height
    rowHeight = 1 / totalRows

    # Font properties
    fontName = "DejaVu Sans"
    fontSize = 11  # Adjust if needed based on figure size

    # Draw header
    for col in 1:numCols
        xPos = cumWidths[col] + colWidths[col] / 2
        yPos = 1 - rowHeight / 2
        text!(ax, xPos, yPos, text = colNames[col],
            align = (:center, :center),
            font = "DejaVu Sans Bold",
            fontsize = fontSize)
    end

    # Draw data rows
    for row in 1:numRows
        for col in 1:numCols
            xPos = cumWidths[col] + colWidths[col] / 2
            yPos = 1 - (row + 1) * rowHeight + rowHeight / 2
            text!(ax, xPos, yPos, text = dataStr[row, col],
                align = (:center, :center),
                font = fontName,
                fontsize = fontSize)
        end
    end

    # Draw horizontal lines
    for r in 0:totalRows
        y = 1 - r * rowHeight
        lines!(ax, [0, 1], [y, y], color = RGBf(0,0,0), linewidth = 0.5)
    end

    # Draw vertical lines
    for c in 0:numCols
        x = cumWidths[c + 1]
        lines!(ax, [x, x], [0, 1], color = RGBf(0,0,0), linewidth = 0.5)
    end

    limits!(ax, 0, 1, 0, 1)
end