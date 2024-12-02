{{- if .Table.IsView -}}
{{- else -}}

{{- $alias := .Aliases.Table .Table.Name -}}
{{- $schemaTable := .Table.Name | .SchemaTable}}

// UpsertAll inserts or updates all rows
// Currently it doesn't support "NoContext" and "NoRowsAffected"
// IMPORTANT: this will calculate the widest columns from all items in the slice, be careful if you want to use default column values
// IMPORTANT: if the table has `id` column of auto-increment type, this may not work as expected
func (o {{$alias.UpSingular}}Slice) UpsertAll(ctx context.Context, exec boil.ContextExecutor, updateOnConflict bool, conflictColumns []string, updateColumns, insertColumns boil.Columns) (int64, error) {
    if len(o) == 0 {
        return 0, nil
    }

    // Calculate the widest columns from all rows need to upsert
    insertCols := make(map[string]struct{}, 10)
    for _, row := range o {
        insert, _ := insertColumns.InsertColumnSet(
            {{$alias.DownSingular}}AllColumns,
            {{$alias.DownSingular}}ColumnsWithDefault,
            {{$alias.DownSingular}}ColumnsWithoutDefault,
            queries.NonZeroDefaultSet({{$alias.DownSingular}}ColumnsWithDefault, row),
        )
        for _, col := range insert {
            insertCols[col] = struct{}{}
        }
        if len(insertCols) == len({{$alias.DownSingular}}AllColumns) {
            break
        }
    }
    insert := make([]string, 0, len(insertCols))
    for _, col := range {{$alias.DownSingular}}AllColumns {
        if _, ok := insertCols[col]; ok {
            insert = append(insert, col)
        }
    }

    update := updateColumns.UpdateColumnSet(
        {{$alias.DownSingular}}AllColumns,
        {{$alias.DownSingular}}PrimaryKeyColumns,
    )

    if updateOnConflict && len(update) == 0 {
        return 0, errors.New("{{.PkgName}}: unable to upsert {{.Table.Name}}, could not build update column list")
    }

    conflict := conflictColumns
    if len(conflict) == 0 {
        conflict = make([]string, len({{$alias.DownSingular}}PrimaryKeyColumns))
        copy(conflict, {{$alias.DownSingular}}PrimaryKeyColumns)
    }

    buf := strmangle.GetBuffer()
    defer strmangle.PutBuffer(buf)

    columns := "DEFAULT VALUES"
    if len(insert) != 0 {
        columns = fmt.Sprintf("(%s) VALUES %s",
            strings.Join(insert, ", "),
            strmangle.Placeholders(dialect.UseIndexPlaceholders, len(insert)*len(o), 1, len(insert)),
        )
    }

    fmt.Fprintf(
        buf,
        "INSERT INTO %s %s ON CONFLICT ",
        "{{$schemaTable}}",
        columns,
    )

    if !updateOnConflict || len(update) == 0 {
        buf.WriteString("DO NOTHING")
    } else {
        buf.WriteByte('(')
        buf.WriteString(strings.Join(conflict, ", "))
        buf.WriteString(") DO UPDATE SET ")

        for i, v := range update {
            if i != 0 {
                buf.WriteByte(',')
            }
            quoted := strmangle.IdentQuote(dialect.LQ, dialect.RQ, v)
            buf.WriteString(quoted)
            buf.WriteString(" = EXCLUDED.")
            buf.WriteString(quoted)
        }
    }

    query := buf.String()
    valueMapping, err := queries.BindMapping({{$alias.DownSingular}}Type, {{$alias.DownSingular}}Mapping, insert)
    if err != nil {
        return 0, err
    }

    var vals []interface{}
    for _, row := range o {
        {{- if not .NoAutoTimestamps}}
        {{- $colNames := .Table.Columns | columnNames}}
        {{- if containsAny $colNames "created_at" "updated_at"}}
        if !boil.TimestampsAreSkipped(ctx) {
            currTime := time.Now().In(boil.GetLocation())
            {{- range $ind, $col := .Table.Columns -}}
                {{- if eq $col.Name "created_at"}}
                    {{- if eq $col.Type "time.Time"}}
            if row.CreatedAt.IsZero() {
                row.CreatedAt = currTime
            }
                    {{else}}
            if queries.MustTime(row.CreatedAt).IsZero() {
                queries.SetScanner(&row.CreatedAt, currTime)
            }
                    {{end}}
                {{end}}
                {{- if eq $col.Name "updated_at" -}}
                    {{if eq $col.Type "time.Time"}}
            row.UpdatedAt = currTime
                    {{else}}
            queries.SetScanner(&row.UpdatedAt, currTime)
                    {{end}}
                {{- end -}}
            {{end -}}
        }
        {{end}}
        {{end}}

        {{if not .NoHooks}}
        if err := row.doBeforeUpsertHooks(ctx, exec); err != nil {
            return 0, err
        }
        {{end}}

        value := reflect.Indirect(reflect.ValueOf(row))
        vals = append(vals, queries.ValuesFromMapping(value, valueMapping)...)
    }

    if boil.IsDebug(ctx) {
        writer := boil.DebugWriterFrom(ctx)
        fmt.Fprintln(writer, query)
        fmt.Fprintln(writer, vals)
    }

    result, err := exec.ExecContext(ctx, query, vals...)
    if err != nil {
        return 0, errors.Wrap(err, "{{.PkgName}}: unable to upsert for {{.Table.Name}}")
    }

    rowsAff, err := result.RowsAffected()
    if err != nil {
        return 0, errors.Wrap(err, "{{.PkgName}}: failed to get rows affected by upsert for {{.Table.Name}}")
    }

    {{if not .NoHooks}}
    if len({{$alias.DownSingular}}AfterUpsertHooks) != 0 {
        for _, obj := range o {
            if err := obj.doAfterUpsertHooks(ctx, exec); err != nil {
                return 0, err
            }
        }
    }
    {{end}}

    return rowsAff, nil
}

{{- end -}}
