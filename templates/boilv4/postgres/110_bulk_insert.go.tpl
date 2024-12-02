{{- if .Table.IsView -}}
{{- else -}}

{{- $alias := .Aliases.Table .Table.Name -}}
{{- $schemaTable := .Table.Name | .SchemaTable}}

// InsertAll inserts all rows with the specified column values, using an executor.
// IMPORTANT: this will calculate the widest columns from all items in the slice, be careful if you want to use default column values
func (o {{$alias.UpSingular}}Slice) InsertAll({{if .NoContext}}exec boil.Executor{{else}}ctx context.Context, exec boil.ContextExecutor{{end}}, columns boil.Columns) {{if .NoRowsAffected}}error{{else}}(int64, error){{end -}} {
	if len(o) == 0 {
		return 0, nil
	}

    // Calculate the widest columns from all rows need to insert
    wlCols := make(map[string]struct{}, 10)
    for _, row := range o {
        wl, _ := columns.InsertColumnSet(
            {{$alias.DownSingular}}AllColumns,
            {{$alias.DownSingular}}ColumnsWithDefault,
            {{$alias.DownSingular}}ColumnsWithoutDefault,
            queries.NonZeroDefaultSet({{$alias.DownSingular}}ColumnsWithDefault, row),
        )
        for _, col := range wl {
            wlCols[col] = struct{}{}
        }
        if len(wlCols) == len({{$alias.DownSingular}}AllColumns) {
            break
        }
    }
    wl := make([]string, 0, len(wlCols))
    for _, col := range {{$alias.DownSingular}}AllColumns {
        if _, ok := wlCols[col]; ok {
            wl = append(wl, col)
        }
    }

	var sql string
	vals := []interface{}{}
	for i, row := range o {
		{{- if not .NoAutoTimestamps -}}
		{{- $colNames := .Table.Columns | columnNames -}}
		{{if containsAny $colNames "created_at" "updated_at"}}
			{{if not .NoContext -}}
		if !boil.TimestampsAreSkipped(ctx) {
			{{- end -}}{{/* not .NoContext */}}
			currTime := time.Now().In(boil.GetLocation())
			{{- range $ind, $col := .Table.Columns}}
				{{- if eq $col.Name "created_at" -}}
					{{- if eq $col.Type "time.Time" }}
				if row.CreatedAt.IsZero() {
				row.CreatedAt = currTime
			}
					{{- else}}
			if queries.MustTime(row.CreatedAt).IsZero() {
				queries.SetScanner(&row.CreatedAt, currTime)
			}
					{{- end -}}
				{{- end -}}
				{{- if eq $col.Name "updated_at" -}}
					{{- if eq $col.Type "time.Time"}}
				if row.UpdatedAt.IsZero() {
				row.UpdatedAt = currTime
			}
					{{- else}}
			if queries.MustTime(row.UpdatedAt).IsZero() {
				queries.SetScanner(&row.UpdatedAt, currTime)
			}
					{{- end -}}
				{{- end -}}
			{{end}}
			{{if not .NoContext -}}
		}
			{{end -}}{{/* not .NoContext */}}
		{{end}}{{/* containsAny $colNames */}}
		{{- end}}{{/* not .NoAutoTimestamps */}}

		{{if not .NoHooks -}}
		if err := row.doBeforeInsertHooks(ctx, exec); err != nil {
			return {{if not .NoRowsAffected}}0, {{end -}} err
		}
		{{- end}}

		if i == 0 {
			sql = "INSERT INTO {{$schemaTable}} " + "({{.LQ}}" + strings.Join(wl, "{{.RQ}},{{.LQ}}") + "{{.RQ}})" + " VALUES "
		}
		sql += strmangle.Placeholders(dialect.UseIndexPlaceholders, len(wl), len(vals)+1, len(wl))
		if i != len(o)-1 {
			sql += ","
		}
		valMapping, err := queries.BindMapping({{$alias.DownSingular}}Type, {{$alias.DownSingular}}Mapping, wl)
		if err != nil {
			return {{if not .NoRowsAffected}}0, {{end -}} err
		}

		value := reflect.Indirect(reflect.ValueOf(row))
		vals = append(vals, queries.ValuesFromMapping(value, valMapping)...)
	}

	{{if .NoContext -}}
	if boil.DebugMode {
		fmt.Fprintln(boil.DebugWriter, sql)
		fmt.Fprintln(boil.DebugWriter, vals)
	}
	{{else -}}
	if boil.IsDebug(ctx) {
		writer := boil.DebugWriterFrom(ctx)
		fmt.Fprintln(writer, sql)
		fmt.Fprintln(writer, vals)
	}
	{{end}}

	{{if .NoContext -}}
	result, err := exec.Exec(sql, vals...)
	{{else -}}
	result, err := exec.ExecContext(ctx, sql, vals...)
	{{end -}}
	if err != nil {
		return {{if not .NoRowsAffected}}0, {{end -}} errors.Wrap(err, "{{.PkgName}}: unable to insert all from {{$alias.DownSingular}} slice")
	}

	{{if not .NoRowsAffected -}}
	rowsAff, err := result.RowsAffected()
	if err != nil {
		return 0, errors.Wrap(err, "{{.PkgName}}: failed to get rows affected by insertall for {{.Table.Name}}")
	}
	{{end}}

	{{if not .NoHooks -}}
	if len({{$alias.DownSingular}}AfterInsertHooks) != 0 {
		for _, obj := range o {
			if err := obj.doAfterInsertHooks({{if not .NoContext}}ctx, {{end -}} exec); err != nil {
				return {{if not .NoRowsAffected}}0, {{end -}} err
			}
		}
	}
	{{- end}}

	return {{if not .NoRowsAffected}}rowsAff, {{end -}} nil
}

// InsertIgnoreAll inserts all rows with ignoring the existing ones having the same primary key values.
// NOTE: This function calls UpsertAll() with updateOnConflict=false and conflictColumns=<primary key columns>
// IMPORTANT: this will calculate the widest columns from all items in the slice, be careful if you want to use default column values
// IMPORTANT: if the table has `id` column of auto-increment type, this may not work as expected
func (o {{$alias.UpSingular}}Slice) InsertIgnoreAll({{if .NoContext}}exec boil.Executor{{else}}ctx context.Context, exec boil.ContextExecutor{{end}}, columns boil.Columns) {{if .NoRowsAffected}}error{{else}}(int64, error){{end -}} {
	return o.UpsertAll({{if .NoContext}}exec{{else}}ctx, exec{{end}}, false, {{$alias.DownSingular}}PrimaryKeyColumns, boil.None(), columns)
}

{{- end -}}
