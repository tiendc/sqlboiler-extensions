{{- if .Table.IsView -}}
{{- else -}}
{{- $alias := .Aliases.Table .Table.Name -}}
{{- $canSoftDelete := .Table.CanSoftDelete $.AutoColumns.Deleted -}}
{{- $soft := and .AddSoftDeletes $canSoftDelete }}

// DeleteAllByPage delete all {{$alias.UpSingular}} records from the slice.
// This function deletes data by pages to avoid exceeding Mysql limitation (max placeholders: 65535)
// Mysql Error 1390: Prepared statement contains too many placeholders.
func (s {{$alias.UpSingular}}Slice) DeleteAllByPage(ctx context.Context, exec boil.ContextExecutor{{if $soft}}, hardDelete bool{{end}}, limits ...int) (int64, error) {
    length := len(s)
    if length == 0 {
        return 0, nil
    }

    // MySQL max placeholders = 65535
    chunkSize := DefaultPageSize
    if len(limits) > 0 && limits[0] > 0 && limits[0] <= MaxPageSize {
        chunkSize = limits[0]
    }
    if length <= chunkSize {
        return s.DeleteAll(ctx, exec{{if $soft}}, hardDelete{{end}})
    }

    rowsAffected := int64(0)
    start := 0
    for {
        end := start + chunkSize
        if end > length {
            end = length
        }
        rows, err := s[start:end].DeleteAll(ctx, exec{{if $soft}}, hardDelete{{end}})
        if err != nil {
            return rowsAffected, err
        }

        rowsAffected += rows
        start = end
        if start >= length {
            break
        }
    }
    return rowsAffected, nil
}

// UpdateAllByPage update all {{$alias.UpSingular}} records from the slice.
// This function updates data by pages to avoid exceeding Mysql limitation (max placeholders: 65535)
// Mysql Error 1390: Prepared statement contains too many placeholders.
func (s {{$alias.UpSingular}}Slice) UpdateAllByPage(ctx context.Context, exec boil.ContextExecutor, cols M, limits ...int) (int64, error) {
    length := len(s)
    if length == 0 {
        return 0, nil
    }

    // MySQL max placeholders = 65535
    // NOTE (eric): len(cols) should not be too big
    chunkSize := DefaultPageSize
    if len(limits) > 0 && limits[0] > 0 && limits[0] <= MaxPageSize {
        chunkSize = limits[0]
    }
    if length <= chunkSize {
        return s.UpdateAll(ctx, exec, cols)
    }

    rowsAffected := int64(0)
    start := 0
    for {
        end := start + chunkSize
        if end > length {
            end = length
        }
        rows, err := s[start:end].UpdateAll(ctx, exec, cols)
        if err != nil {
            return rowsAffected, err
        }

        rowsAffected += rows
        start = end
        if start >= length {
            break
        }
    }
    return rowsAffected, nil
}

// InsertAllByPage insert all {{$alias.UpSingular}} records from the slice.
// This function inserts data by pages to avoid exceeding Mysql limitation (max placeholders: 65535)
// Mysql Error 1390: Prepared statement contains too many placeholders.
func (s {{$alias.UpSingular}}Slice) InsertAllByPage(ctx context.Context, exec boil.ContextExecutor, columns boil.Columns, limits ...int) (int64, error) {
    length := len(s)
    if length == 0 {
        return 0, nil
    }

    // MySQL max placeholders = 65535
    chunkSize := MaxPageSize / reflect.ValueOf(&{{$alias.UpSingular}}Columns).Elem().NumField()
    if len(limits) > 0 && limits[0] > 0 && limits[0] < chunkSize {
        chunkSize = limits[0]
    }
    if length <= chunkSize {
        return s.InsertAll(ctx, exec, columns)
    }

    rowsAffected := int64(0)
    start := 0
    for {
        end := start + chunkSize
        if end > length {
            end = length
        }
        rows, err := s[start:end].InsertAll(ctx, exec, columns)
        if err != nil {
            return rowsAffected, err
        }

        rowsAffected += rows
        start = end
        if start >= length {
            break
        }
    }
    return rowsAffected, nil
}

// UpsertAllByPage upsert all {{$alias.UpSingular}} records from the slice.
// This function upserts data by pages to avoid exceeding Mysql limitation (max placeholders: 65535)
// Mysql Error 1390: Prepared statement contains too many placeholders.
func (s {{$alias.UpSingular}}Slice) UpsertAllByPage(ctx context.Context, exec boil.ContextExecutor, updateColumns, insertColumns boil.Columns, limits ...int) (int64, error) {
    length := len(s)
    if length == 0 {
        return 0, nil
    }

    // MySQL max placeholders = 65535
    chunkSize := MaxPageSize / reflect.ValueOf(&{{$alias.UpSingular}}Columns).Elem().NumField()
    if len(limits) > 0 && limits[0] > 0 && limits[0] < chunkSize {
        chunkSize = limits[0]
    }
    if length <= chunkSize {
        return s.UpsertAll(ctx, exec, updateColumns, insertColumns)
    }

    rowsAffected := int64(0)
    start := 0
    for {
        end := start + chunkSize
        if end > length {
            end = length
        }
        rows, err := s[start:end].UpsertAll(ctx, exec, updateColumns, insertColumns)
        if err != nil {
            return rowsAffected, err
        }

        rowsAffected += rows
        start = end
        if start >= length {
            break
        }
    }
    return rowsAffected, nil
}

{{end -}}
