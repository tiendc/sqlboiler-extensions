{{- if or (not .Table.IsView) .Table.ViewCapabilities.CanUpsert -}}
{{- $alias := .Aliases.Table .Table.Name}}
{{- $schemaTable := .Table.Name | .SchemaTable}}

// Upsert attempts an insert using an executor, and does an update or ignore on conflict with the specified columns.
// This is copied from the built-in Upsert() function with accepting an extra param for conflict columns.
// See bug https://github.com/volatiletech/sqlboiler/issues/328.
// SQLBoiler only checks column conflict on single column only which is not correct as MySQL PK or UNIQUE index
// can include multiple columns.
// This function allows passing multiple conflict columns, but it cannot check whether they are correct or not.
// So use it at your own risk.
// IMPORTANT: any AUTO_INCREMENT column should be excluded from `updateColumns` and `insertColumns` including PK.
func (o *{{$alias.UpSingular}}) UpsertOnConflictColumns({{if .NoContext}}exec boil.Executor{{else}}ctx context.Context, exec boil.ContextExecutor{{end}}, conflictColumns []string, updateColumns, insertColumns boil.Columns) error {
    if o == nil {
        return errors.New("{{.PkgName}}: no {{.Table.Name}} provided for upsert")
    }

    {{- template "timestamp_upsert_helper" . }}

    {{if not .NoHooks -}}
    if err := o.doBeforeUpsertHooks({{if not .NoContext}}ctx, {{end -}} exec); err != nil {
        return err
    }
    {{- end}}

    nzDefaults := queries.NonZeroDefaultSet({{$alias.DownSingular}}ColumnsWithDefault, o)

    nzUniques := make([]string, 0, len(conflictColumns))
    for _, col := range conflictColumns {
        for _, existCol := range {{$alias.DownSingular}}AllColumns {
            if col == existCol {
                nzUniques = append(nzUniques, col)
                break
            }
        }
    }
    if len(nzUniques) <= 1 {
        return errors.New("custom conflict columns must be 2 columns or more")
    }

    // Build cache key in-line uglily - mysql vs psql problems
    buf := strmangle.GetBuffer()
    buf.WriteString(strconv.Itoa(updateColumns.Kind))
    for _, c := range updateColumns.Cols {
        buf.WriteString(c)
    }
    buf.WriteByte('.')
    buf.WriteString(strconv.Itoa(insertColumns.Kind))
    for _, c := range insertColumns.Cols {
        buf.WriteString(c)
    }
    buf.WriteByte('.')
    for _, c := range nzDefaults {
        buf.WriteString(c)
    }
    buf.WriteByte('.')
    for _, c := range nzUniques {
        buf.WriteString(c)
    }
    key := buf.String()
    strmangle.PutBuffer(buf)

    {{$alias.DownSingular}}UpsertCacheMut.RLock()
    cache, cached := {{$alias.DownSingular}}UpsertCache[key]
    {{$alias.DownSingular}}UpsertCacheMut.RUnlock()

    var err error

    if !cached {
        insert, _ := insertColumns.InsertColumnSet(
            {{$alias.DownSingular}}AllColumns,
            {{$alias.DownSingular}}ColumnsWithDefault,
            {{$alias.DownSingular}}ColumnsWithoutDefault,
            nzDefaults,
        )

        update := updateColumns.UpdateColumnSet(
            {{$alias.DownSingular}}AllColumns,
            {{$alias.DownSingular}}PrimaryKeyColumns,
        )
        {{if filterColumnsByAuto true .Table.Columns }}
        insert = strmangle.SetComplement(insert, {{$alias.DownSingular}}GeneratedColumns)
        update = strmangle.SetComplement(update, {{$alias.DownSingular}}GeneratedColumns)
        {{- end }}

        if !updateColumns.IsNone() && len(update) == 0 {
            return errors.New("{{.PkgName}}: unable to upsert {{.Table.Name}}, could not build update column list")
        }

        ret := strmangle.SetComplement({{$alias.DownSingular}}AllColumns, strmangle.SetIntersect(insert, update))

        cache.query = buildUpsertQueryMySQL(dialect, "{{$schemaTable}}", update, insert)
        cache.retQuery = fmt.Sprintf(
            "SELECT %s FROM {{.LQ}}{{.Table.Name}}{{.RQ}} WHERE %s",
            strings.Join(strmangle.IdentQuoteSlice(dialect.LQ, dialect.RQ, ret), ","),
            strmangle.WhereClause("{{.LQ}}", "{{.RQ}}", 0, nzUniques),
        )

        cache.valueMapping, err = queries.BindMapping({{$alias.DownSingular}}Type, {{$alias.DownSingular}}Mapping, insert)
        if err != nil {
            return err
        }
        if len(ret) != 0 {
            cache.retMapping, err = queries.BindMapping({{$alias.DownSingular}}Type, {{$alias.DownSingular}}Mapping, ret)
            if err != nil {
                return err
            }
        }
    }

    value := reflect.Indirect(reflect.ValueOf(o))
    vals := queries.ValuesFromMapping(value, cache.valueMapping)
    var returns []interface{}
    if len(cache.retMapping) != 0 {
        returns = queries.PtrsFromMapping(value, cache.retMapping)
    }

    {{if .NoContext -}}
    if boil.DebugMode {
        fmt.Fprintln(boil.DebugWriter, cache.query)
        fmt.Fprintln(boil.DebugWriter, vals)
    }
    {{else -}}
    if boil.IsDebug(ctx) {
        writer := boil.DebugWriterFrom(ctx)
        fmt.Fprintln(writer, cache.query)
        fmt.Fprintln(writer, vals)
    }
    {{end -}}

    {{$canLastInsertID := .Table.CanLastInsertID -}}
    {{if $canLastInsertID -}}
        {{if .NoContext -}}
    result, err := exec.Exec(cache.query, vals...)
        {{else -}}
    result, err := exec.ExecContext(ctx, cache.query, vals...)
        {{end -}}
    {{else -}}
        {{if .NoContext -}}
    _, err = exec.Exec(cache.query, vals...)
        {{else -}}
    _, err = exec.ExecContext(ctx, cache.query, vals...)
        {{end -}}
    {{- end}}
    if err != nil {
        return errors.Wrap(err, "{{.PkgName}}: unable to upsert for {{.Table.Name}}")
    }

    {{if $canLastInsertID -}}
    var lastID int64
    {{- end}}
    var uniqueMap []uint64
    var nzUniqueCols []interface{}

    if len(cache.retMapping) == 0 {
        goto CacheNoHooks
    }

    {{if $canLastInsertID -}}
    lastID, err = result.LastInsertId()
    if err != nil {
        return ErrSyncFail
    }

    {{$colName := index .Table.PKey.Columns 0 -}}
    {{- $col := .Table.GetColumn $colName -}}
    {{- $colTitled := $alias.Column $colName}}
    o.{{$colTitled}} = {{$col.Type}}(lastID)
    if lastID != 0 && len(cache.retMapping) == 1 && cache.retMapping[0] == {{$alias.DownSingular}}Mapping["{{$colName}}"] {
        goto CacheNoHooks
    }
    {{- end}}

    uniqueMap, err = queries.BindMapping({{$alias.DownSingular}}Type, {{$alias.DownSingular}}Mapping, nzUniques)
    if err != nil {
        return errors.Wrap(err, "{{.PkgName}}: unable to retrieve unique values for {{.Table.Name}}")
     }
    nzUniqueCols = queries.ValuesFromMapping(reflect.Indirect(reflect.ValueOf(o)), uniqueMap)

    {{if .NoContext -}}
    if boil.DebugMode {
        fmt.Fprintln(boil.DebugWriter, cache.retQuery)
        fmt.Fprintln(boil.DebugWriter, nzUniqueCols...)
    }
    {{else -}}
    if boil.IsDebug(ctx) {
        writer := boil.DebugWriterFrom(ctx)
        fmt.Fprintln(writer, cache.retQuery)
        fmt.Fprintln(writer, nzUniqueCols...)
    }
    {{end -}}

    {{if .NoContext -}}
    err = exec.QueryRow(cache.retQuery, nzUniqueCols...).Scan(returns...)
    {{else -}}
    err = exec.QueryRowContext(ctx, cache.retQuery, nzUniqueCols...).Scan(returns...)
    {{end -}}
    if err != nil {
        return errors.Wrap(err, "{{.PkgName}}: unable to populate default values for {{.Table.Name}}")
    }

CacheNoHooks:
    if !cached {
        {{$alias.DownSingular}}UpsertCacheMut.Lock()
        {{$alias.DownSingular}}UpsertCache[key] = cache
        {{$alias.DownSingular}}UpsertCacheMut.Unlock()
    }

    {{if not .NoHooks -}}
    return o.doAfterUpsertHooks({{if not .NoContext}}ctx, {{end -}} exec)
    {{- else -}}
    return nil
    {{- end}}
}

{{end}}
