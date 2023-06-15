{{- if .Table.IsView -}}
{{- else -}}

{{- $alias := .Aliases.Table .Table.Name -}}
{{- $schemaTable := .Table.Name | .SchemaTable}}

// InsertAll inserts all rows with the specified column values, using an executor.
func (o {{$alias.UpSingular}}Slice) InsertAll({{if .NoContext}}exec boil.Executor{{else}}ctx context.Context, exec boil.ContextExecutor{{end}}, columns boil.Columns) {{if .NoRowsAffected}}error{{else}}(int64, error){{end -}} {
	if len(o) == 0 {
		return 0, nil
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

		wl, _ := columns.InsertColumnSet(
			{{$alias.DownSingular}}AllColumns,
			{{$alias.DownSingular}}ColumnsWithDefault,
			{{$alias.DownSingular}}ColumnsWithoutDefault,
			queries.NonZeroDefaultSet({{$alias.DownSingular}}ColumnsWithDefault, row),
		)
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

{{- end -}}
